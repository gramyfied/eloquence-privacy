"""
Orchestrateur pour le système de coaching vocal Eloquence.
Ce module coordonne les différents services (VAD, ASR, LLM, TTS) et gère l'état de la session.
"""

import asyncio
import json
import logging
import uuid
import time
from typing import Dict, List, Optional, Tuple, Any, Set
import wave
import io
import os
from datetime import datetime

import numpy as np
from fastapi import WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import settings
from core.models import CoachingSession as Session, SessionTurn as SessionSegment
from services.vad_service import VadService
from services.asr_service import AsrService
from services.llm_service import LlmService
from services.tts_service import TtsService
from services.kaldi_service import kaldi_service

logger = logging.getLogger(__name__)

# Types de messages WebSocket
WS_MSG_AUDIO = "audio"  # Binaire
WS_MSG_CONTROL = "control"  # JSON
WS_MSG_TRANSCRIPT = "transcript_ia"  # JSON
WS_MSG_AUDIO_CONTROL = "audio_control"  # JSON
WS_MSG_ERROR = "error"  # JSON

# Événements de contrôle
CONTROL_USER_INTERRUPT = "user_interrupt_start"
CONTROL_USER_SPEECH_END = "user_speech_end"

# Événements audio
AUDIO_IA_SPEECH_START = "ia_speech_start"
AUDIO_IA_SPEECH_END = "ia_speech_end"

# États de la session
SESSION_STATE_IDLE = "idle"  # En attente d'entrée utilisateur
SESSION_STATE_USER_SPEAKING = "user_speaking"  # L'utilisateur parle
SESSION_STATE_PROCESSING = "processing"  # Traitement de l'entrée utilisateur
SESSION_STATE_IA_SPEAKING = "ia_speaking"  # L'IA parle
SESSION_STATE_ENDED = "ended"  # Session terminée
SESSION_STATE_PAUSED = "paused"  # Session en pause (déconnexion temporaire)
SESSION_STATE_ENDED = "ended"  # Session terminée

class Orchestrator:
    """
    Orchestrateur principal qui coordonne les différents services et gère l'état de la session.
    """
    def __init__(self, db: AsyncSession):
        self.db = db
        self.vad_service = VadService()
        self.asr_service = AsrService()
        self.llm_service = LlmService()
        self.tts_service = TtsService()
        
        # État de la session
        self.active_sessions: Dict[str, Dict[str, Any]] = {}
        self.connected_clients: Dict[str, WebSocket] = {}
        
        # Métriques de latence
        self.latency_metrics = {
            "vad_to_asr": [],
            "asr_to_llm": [],
            "llm_to_tts": [],
            "tts_to_client": [],
            "total": []
        }
    
    async def initialize(self):
        """Initialise les services nécessaires au démarrage."""
        logger.info("Initialisation de l'orchestrateur...")
        await self.vad_service.load_model()
        logger.info("Orchestrateur initialisé avec succès.")
    
    async def connect_client(self, websocket: WebSocket, session_id: str):
        """
        Gère la connexion d'un nouveau client WebSocket.
        """
        await websocket.accept()
        self.connected_clients[session_id] = websocket
        
        if session_id not in self.active_sessions:
            # Initialiser une nouvelle session
            self.active_sessions[session_id] = {
                "state": SESSION_STATE_IDLE,
                "history": [],
                "current_audio_buffer": bytearray(),
                "speech_detected": False,
                "silence_duration": 0,
                "last_speech_time": None,
                "is_interrupted": False,
                "scenario_context": None,
                "segment_id": None,
                "start_time": time.time(),
                "is_paused": False,
                "paused_at": None,
                "reconnect_count": 0,
                "last_activity": time.time()
            }
            logger.info(f"[WS] Nouvelle session initialisée: {session_id}")
        else:
            # Client reconnecté à une session existante
            session = self.active_sessions[session_id]
            
            # Vérifier si la session était en pause
            if session.get("is_paused", False):
                # Calculer la durée de la pause
                pause_duration = time.time() - session.get("paused_at", time.time())
                
                # Réactiver la session
                session["is_paused"] = False
                session["paused_at"] = None
                session["reconnect_count"] = session.get("reconnect_count", 0) + 1
                session["last_activity"] = time.time()
                
                logger.info(f"[WS] Client reconnecté à la session {session_id} après "
                           f"{pause_duration:.1f}s de pause (reconnexion #{session['reconnect_count']})")
                
                # Envoyer un message de bienvenue pour confirmer la reconnexion
                await self._send_message(session_id, {
                    "type": WS_MSG_CONTROL,
                    "event": "session_resumed",
                    "pause_duration": round(pause_duration, 1),
                    "reconnect_count": session["reconnect_count"]
                })
            else:
                # Session active, simple reconnexion
                session["reconnect_count"] = session.get("reconnect_count", 0) + 1
                session["last_activity"] = time.time()
                logger.info(f"[WS] Client reconnecté à la session active {session_id} "
                           f"(reconnexion #{session['reconnect_count']})")
    
    async def disconnect_client(self, session_id: str):
        """
        Gère la déconnexion d'un client WebSocket et nettoie la session.
        """
        logger.info(f"[WS] Déconnexion complète du client pour session {session_id}")
        
        # Supprimer le client de la liste des clients connectés
        if session_id in self.connected_clients:
            del self.connected_clients[session_id]
            logger.info(f"[WS] Client supprimé de la liste des clients connectés")
        else:
            logger.warning(f"[WS] Client non trouvé dans la liste des clients connectés")
        
        # Nettoyer la session active
        if session_id in self.active_sessions:
            # Sauvegarder les données de session avant de la supprimer
            try:
                await self._save_session_data(session_id)
                logger.info(f"[WS] Données de session {session_id} sauvegardées avant suppression")
            except Exception as e:
                logger.error(f"[WS] Erreur lors de la sauvegarde des données de session avant suppression: {e}",
                            exc_info=True)
            
            # Supprimer la session
            del self.active_sessions[session_id]
            logger.info(f"[WS] Session {session_id} supprimée de la liste des sessions actives")
        else:
            logger.warning(f"[WS] Session {session_id} non trouvée dans la liste des sessions actives")
    
    async def client_disconnected(self, session_id: str, keep_session: bool = False):
        """
        Gère la déconnexion d'un client WebSocket.
        
        Args:
            session_id: ID de la session
            keep_session: Si True, conserve l'état de la session pour une reconnexion ultérieure
        """
        logger.info(f"[WS] Déconnexion du client pour session {session_id}, keep_session={keep_session}")
        
        # Supprimer le client de la liste des clients connectés
        if session_id in self.connected_clients:
            del self.connected_clients[session_id]
            logger.info(f"[WS] Client supprimé de la liste des clients connectés")
        else:
            logger.warning(f"[WS] Client non trouvé dans la liste des clients connectés")
        
        # Si on ne garde pas la session, la nettoyer
        if not keep_session:
            await self.disconnect_client(session_id)
            return
        
        # Sinon, conserver la session mais mettre à jour son état
        if session_id in self.active_sessions:
            # Mettre la session en pause
            self.active_sessions[session_id]["state"] = SESSION_STATE_IDLE
            self.active_sessions[session_id]["is_paused"] = True
            self.active_sessions[session_id]["paused_at"] = time.time()
            
            # Sauvegarder les données de session
            try:
                await self._save_session_data(session_id)
                logger.info(f"[WS] Données de session {session_id} sauvegardées et mise en pause")
            except Exception as e:
                logger.error(f"[WS] Erreur lors de la sauvegarde des données de session en pause: {e}",
                            exc_info=True)
        else:
            logger.warning(f"[WS] Session {session_id} non trouvée pour mise en pause")
    
    async def end_session(self, session_id: str):
        """
        Termine une session et nettoie les ressources associées.
        """
        if session_id in self.active_sessions:
            self.active_sessions[session_id]["state"] = SESSION_STATE_ENDED
            # Sauvegarder l'historique et les métriques finales
            await self._save_session_data(session_id)
            logger.info(f"Session terminée: {session_id}")
    
    async def process_websocket_message(self, websocket: WebSocket, session_id: str):
        """
        Traite les messages entrants du WebSocket.
        """
        try:
            message = await websocket.receive()
            
            # Message binaire (audio)
            if "bytes" in message:
                audio_chunk = message["bytes"]
                await self._process_audio_chunk(session_id, audio_chunk)
            
            # Message texte (contrôle)
            elif "text" in message:
                try:
                    data = json.loads(message["text"])
                    msg_type = data.get("type")
                    
                    logger.info(f"Message texte reçu: {data}")
                    logger.info(f"Type de message: {msg_type}")
                    logger.info(f"WS_MSG_CONTROL: {WS_MSG_CONTROL}")
                    
                    if msg_type == WS_MSG_CONTROL:
                        event = data.get("event")
                        logger.info(f"Événement de contrôle: {event}")
                        logger.info(f"CONTROL_USER_INTERRUPT: {CONTROL_USER_INTERRUPT}")
                        await self._process_control_event(session_id, event)
                    else:
                        logger.warning(f"Type de message inconnu: {msg_type}")
                except json.JSONDecodeError:
                    logger.error("Message JSON invalide")
                    await self._send_error(session_id, "Message JSON invalide")
            
            else:
                logger.warning("Format de message WebSocket non pris en charge")
                await self._send_error(session_id, "Format de message non pris en charge")
        
        except WebSocketDisconnect:
            await self.disconnect_client(session_id)
        except Exception as e:
            logger.error(f"Erreur lors du traitement du message WebSocket: {e}", exc_info=True)
            await self._send_error(session_id, f"Erreur interne: {str(e)}")
    
    async def _process_audio_chunk(self, session_id: str, audio_chunk: bytes):
        """
        Traite un chunk audio reçu du client.
        Utilise le VAD pour détecter la parole et déclenche le traitement approprié.
        """
        logger.info(f"[AUDIO] _process_audio_chunk appelé pour session {session_id} avec {len(audio_chunk)} bytes.")
        session = self.active_sessions.get(session_id)
        if not session:
            logger.error(f"[AUDIO] Session {session_id} non trouvée")
            return
        
        # Log détaillé de l'état de la session
        logger.info(f"[AUDIO] État de la session {session_id}: état={session['state']}, "
                   f"speech_detected={session.get('speech_detected', False)}, "
                   f"silence_duration={session.get('silence_duration', 0):.2f}s, "
                   f"is_interrupted={session.get('is_interrupted', False)}")

        # Si l'IA est en train de parler et qu'on reçoit de l'audio, c'est une interruption
        if session["state"] == SESSION_STATE_IA_SPEAKING and not session["is_interrupted"]:
            logger.info(f"Interruption potentielle détectée par audio entrant pendant que l'IA parle.")
            await self._process_control_event(session_id, CONTROL_USER_INTERRUPT)
        
        # Mettre à jour l'état
        if session["state"] == SESSION_STATE_IDLE:
            session["state"] = SESSION_STATE_USER_SPEAKING
            session["current_audio_buffer"] = bytearray()
            session["speech_detected"] = False
            session["silence_duration"] = 0
            session["last_speech_time"] = None
            session["segment_id"] = str(uuid.uuid4())
            logger.debug(f"Début de la parole utilisateur, segment: {session['segment_id']}")
        
        # Ajouter le chunk au buffer
        session["current_audio_buffer"].extend(audio_chunk)
        
        # Traiter avec le VAD - nouvelle interface retournant un dictionnaire
        vad_result = self.vad_service.process_chunk(audio_chunk)
        speech_prob = vad_result["speech_prob"]
        is_speech = vad_result["is_speech"]
        confidence = vad_result["confidence"]
        
        # Log détaillé du résultat VAD
        logger.info(f"[VAD] Résultat: speech_prob={speech_prob:.2f}, is_speech={is_speech}, confidence={confidence:.2f}")

        if speech_prob is not None:
            current_time = time.time()
            
            # Parole détectée - utiliser is_speech pour une détection plus robuste
            if is_speech:
                logger.debug(f"Parole détectée (is_speech=True)")
                session["speech_detected"] = True
                session["last_speech_time"] = current_time
                session["silence_duration"] = 0
                
                # Détecter une interruption basée sur le VAD si l'IA parle
                # et que la confiance dans la détection de parole est élevée
                if (session["state"] == SESSION_STATE_IA_SPEAKING and
                    not session["is_interrupted"] and
                    confidence > 0.8):
                    logger.info(f"Interruption détectée par VAD avec confiance {confidence:.2f}")
                    await self._process_control_event(session_id, CONTROL_USER_INTERRUPT)
            # Silence détecté
            elif session["speech_detected"] and not is_speech:
                logger.debug(f"Silence détecté (is_speech=False) après parole détectée.")
                # Calculer la durée du silence
                if session["last_speech_time"]:
                    session["silence_duration"] = current_time - session["last_speech_time"]
                
                logger.debug(f"Durée du silence: {session['silence_duration']:.2f}s")

                # Gérer les différents seuils de silence
                min_silence_end_turn = settings.VAD_MIN_SILENCE_DURATION_MS / 1000
                min_silence_gentle_prompt = settings.VAD_GENTLE_PROMPT_SILENCE_MS / 1000
                min_silence_wait = settings.VAD_WAIT_SILENCE_MS / 1000 # Nouveau seuil à ajouter dans config

                logger.debug(f"Seuils de silence: end_turn={min_silence_end_turn:.2f}s, gentle_prompt={min_silence_gentle_prompt:.2f}s, wait={min_silence_wait:.2f}s")

                # 1. Silence long -> Fin de tour
                if session["silence_duration"] >= min_silence_end_turn:
                    logger.debug(f"Silence long détecté ({session['silence_duration']:.2f}s), déclenchement fin du tour.")
                    await self._process_user_speech_end(session_id)
                # 2. Silence moyen -> Relance douce (optionnel)
                elif session["silence_duration"] >= min_silence_gentle_prompt:
                    # Vérifier si une relance n'est pas déjà en cours ou si l'IA parle
                    if session["state"] == SESSION_STATE_USER_SPEAKING: # Assurer que c'est bien pendant le tour user
                        logger.debug(f"Silence moyen détecté ({session['silence_duration']:.2f}s), déclenchement relance douce.")
                        # Appeler la méthode pour générer la relance douce
                        # Cette méthode est async mais nous ne l'attendons pas ici
                        # pour ne pas bloquer le traitement des chunks audio suivants.
                        # Elle gère son propre cycle de vie et changement d'état.
                        asyncio.create_task(self._generate_gentle_prompt(session_id))
                        # Ne pas faire 'pass' ici, laisser la boucle continuer
                # 3. Silence court -> Attente silencieuse
                elif session["silence_duration"] >= min_silence_wait:
                    logger.debug(f"Silence court détecté ({session['silence_duration']:.2f}s), attente.")
                    pass # Ne rien faire, continuer d'attendre
                # 4. Silence très court -> Ignorer
                else:
                    logger.debug(f"Silence très court détecté ({session['silence_duration']:.2f}s), ignorer.")
                    pass
            else:
                logger.debug("Silence détecté (is_speech=False) avant parole détectée. Ignorer.")

    
    async def _process_user_speech_end(self, session_id: str):
        """
        Traite la fin de la parole utilisateur.
        Déclenche la transcription ASR, puis la génération LLM et TTS.
        """
        session = self.active_sessions.get(session_id)
        if not session or session["state"] != SESSION_STATE_USER_SPEAKING:
            return
        
        # Marquer le début du traitement
        session["state"] = SESSION_STATE_PROCESSING
        start_time = time.time()
        
        # Convertir le buffer audio en WAV pour l'ASR
        audio_data = session["current_audio_buffer"]
        if len(audio_data) == 0:
            logger.warning("Buffer audio vide, abandon du traitement")
            session["state"] = SESSION_STATE_IDLE
            return
        
        # Sauvegarder l'audio pour analyse ultérieure
        segment_id = session["segment_id"]
        audio_path = os.path.join(settings.AUDIO_STORAGE_PATH, f"{session_id}_{segment_id}.wav")
        os.makedirs(os.path.dirname(audio_path), exist_ok=True)
        
        # Convertir en WAV 16kHz mono
        with wave.open(audio_path, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)  # 16-bit
            wf.setframerate(16000)
            wf.writeframes(audio_data)
        
        logger.debug(f"Audio sauvegardé: {audio_path}")
        
        # Transcription ASR
        vad_to_asr_time = time.time()
        # Utiliser la langue de la session ou "fr" par défaut
        language = "fr"  # Langue par défaut
        
        # Log détaillé avant l'appel à ASR
        logger.info(f"[ASR] Début de la transcription pour session {session_id}, taille audio: {len(audio_data)} bytes")
        transcription = await self.asr_service.transcribe(audio_data, language)
        asr_time = time.time()
        asr_duration = asr_time - vad_to_asr_time
        
        if not transcription:
            logger.warning(f"[ASR] Transcription vide pour session {session_id}, abandon du traitement")
            session["state"] = SESSION_STATE_IDLE
            return
        
        # Log détaillé après l'appel à ASR
        logger.info(f"[ASR] Transcription réussie en {asr_duration:.2f}s: '{transcription}'")
        
        # Sauvegarder la transcription
        transcript_path = os.path.join(settings.AUDIO_STORAGE_PATH, f"{session_id}_{segment_id}.txt")
        with open(transcript_path, 'w') as f:
            f.write(transcription)
        
        # Mettre à jour l'historique
        session["history"].append({"role": "user", "content": transcription})
        
        # Générer la réponse LLM
        is_interrupted = session["is_interrupted"]
        
        # Log détaillé avant l'appel au LLM
        history_length = len(session["history"])
        logger.info(f"[LLM] Début de la génération pour session {session_id}, "
                   f"historique: {history_length} messages, "
                   f"is_interrupted: {is_interrupted}")
        
        llm_start_time = time.time()
        llm_response = await self.llm_service.generate(
            session["history"],
            is_interrupted=is_interrupted,
            scenario_context=session["scenario_context"],
            session_id=session_id
        )
        llm_time = time.time()
        llm_duration = llm_time - llm_start_time
        
        # Log détaillé après l'appel au LLM
        logger.info(f"[LLM] Génération réussie en {llm_duration:.2f}s, "
                   f"longueur réponse: {len(llm_response['text_response'])} caractères, "
                   f"émotion: {llm_response['emotion_label']}")
        
        # Réinitialiser le flag d'interruption
        session["is_interrupted"] = False
        
        # Extraire le texte et l'émotion
        text_response = llm_response["text_response"]
        emotion_label = llm_response["emotion_label"]
        
        # Mettre à jour l'historique avec la réponse de l'IA
        session["history"].append({"role": "assistant", "content": text_response})
        
        # Traiter les mises à jour de scénario si présentes
        if "scenario_updates" in llm_response and session.get("scenario_context"):
            updates = llm_response["scenario_updates"]
            logger.info(f"Traitement des mises à jour de scénario: {updates}")
            if "next_step" in updates:
                session["scenario_context"]["current_step"] = updates["next_step"]
                logger.info(f"  -> Nouvelle étape du scénario: {updates['next_step']}")
            if "variables" in updates and isinstance(updates["variables"], dict):
                 if "variables" not in session["scenario_context"]:
                      session["scenario_context"]["variables"] = {}
                 session["scenario_context"]["variables"].update(updates["variables"])
                 logger.info(f"  -> Variables du scénario mises à jour: {updates['variables']}")
            # Potentiellement ajouter d'autres logiques de mise à jour ici
        
        # Synthèse vocale TTS
        logger.info(f"[TTS] Début de la synthèse pour session {session_id}, "
                   f"émotion: {emotion_label}, "
                   f"longueur texte: {len(text_response)} caractères")
        
        # Notification au client que l'IA commence à parler
        await self._send_message(session_id, {
            "type": WS_MSG_AUDIO_CONTROL,
            "event": AUDIO_IA_SPEECH_START
        })
        
        # Marquer le début de la parole de l'IA
        session["state"] = SESSION_STATE_IA_SPEAKING
        
        # Générer l'audio TTS et l'envoyer en streaming
        audio_stream = await self.tts_service.synthesize_stream(
            text_response,
            session_id=session_id,
            emotion=emotion_label,
            language="fr"  # Langue par défaut
        )
        tts_start_time = time.time()
        
        # Envoyer la transcription de l'IA (optionnel)
        await self._send_message(session_id, {
            "type": WS_MSG_TRANSCRIPT,
            "text": text_response
        })
        
        # Envoyer l'audio en streaming
        chunk_size = 4096  # Taille des chunks audio à envoyer
        chunks_sent = 0
        total_bytes_sent = 0
        
        # Log détaillé avant l'envoi des chunks audio
        logger.info(f"[TTS] Début du streaming audio pour session {session_id}")
        
        async for audio_chunk in audio_stream:
            # Vérifier si l'utilisateur a interrompu
            if session["is_interrupted"]:
                logger.info(f"[TTS] Streaming interrompu par l'utilisateur après {chunks_sent} chunks")
                break
            
            # Envoyer le chunk audio
            await self._send_binary(session_id, audio_chunk)
            chunks_sent += 1
            total_bytes_sent += len(audio_chunk)
            
            # Log périodique pendant le streaming (tous les 10 chunks)
            if chunks_sent % 10 == 0:
                logger.debug(f"[TTS] Progression streaming: {chunks_sent} chunks, {total_bytes_sent} bytes envoyés")
            
            # Petite pause pour simuler le streaming
            await asyncio.sleep(0.05)
        
        # Log détaillé après l'envoi des chunks audio
        logger.info(f"[TTS] Fin du streaming audio: {chunks_sent} chunks, {total_bytes_sent} bytes envoyés")
        
        # Marquer la fin de la parole de l'IA
        if not session["is_interrupted"]:
            session["state"] = SESSION_STATE_IDLE
            await self._send_message(session_id, {
                "type": WS_MSG_AUDIO_CONTROL,
                "event": AUDIO_IA_SPEECH_END
            })
        
        # Calculer et enregistrer les métriques de latence
        tts_end_time = time.time()
        self.latency_metrics["vad_to_asr"].append(vad_to_asr_time - start_time)
        self.latency_metrics["asr_to_llm"].append(llm_time - asr_time)
        self.latency_metrics["llm_to_tts"].append(tts_start_time - llm_time)
        self.latency_metrics["tts_to_client"].append(tts_end_time - tts_start_time)
        self.latency_metrics["total"].append(tts_end_time - start_time)
        
        # Enregistrer le segment pour analyse Kaldi asynchrone
        await self._schedule_kaldi_analysis(session_id, segment_id, audio_path, transcript_path)
        
        # Sauvegarder les données de session
        await self._save_session_data(session_id)
        
        logger.info(f"Traitement complet en {tts_end_time - start_time:.2f}s")
    
    async def _process_control_event(self, session_id: str, event: str):
        """
        Traite les événements de contrôle envoyés par le client.
        """
        logger.info(f"_process_control_event appelé avec session_id={session_id}, event={event}")
        
        session = self.active_sessions.get(session_id)
        if not session:
            logger.error(f"Session {session_id} non trouvée")
            return
        
        logger.info(f"État de la session: {session['state']}")
        logger.info(f"SESSION_STATE_IA_SPEAKING: {SESSION_STATE_IA_SPEAKING}")
        
        if event == CONTROL_USER_INTERRUPT:
            logger.info("Événement CONTROL_USER_INTERRUPT détecté")
            # L'utilisateur interrompt l'IA
            if session["state"] == SESSION_STATE_IA_SPEAKING:
                logger.info("Interruption détectée, arrêt du TTS")
                session["is_interrupted"] = True
                
                # Arrêter le TTS via le service TTS
                logger.info(f"Appel de stop_generation avec session_id={session_id}")
                await self.tts_service.stop_generation(session_id) # Renommé
                
                # Informer le client que l'IA a arrêté de parler
                message = {
                    "type": WS_MSG_AUDIO_CONTROL,
                    "event": AUDIO_IA_SPEECH_END
                }
                logger.info(f"Envoi du message: {message}")
                await self._send_message(session_id, message)
                logger.info("Message envoyé")
                
                # Changer l'état pour traiter immédiatement l'audio de l'utilisateur
                session["state"] = SESSION_STATE_USER_SPEAKING
                logger.info(f"Session {session_id} passe à l'état USER_SPEAKING après interruption.")
        
        elif event == CONTROL_USER_SPEECH_END:
            # L'utilisateur signale explicitement la fin de sa parole
            if session["state"] == SESSION_STATE_USER_SPEAKING:
                await self._process_user_speech_end(session_id)
    
    async def _schedule_kaldi_analysis(self, session_id: str, segment_id: str, audio_path: str, transcript_path: str):
        """
        Planifie l'analyse Kaldi asynchrone pour un segment audio.
        """
        try:
            # Lire le contenu des fichiers audio et texte
            with open(audio_path, 'rb') as audio_file:
                audio_bytes = audio_file.read()
            
            with open(transcript_path, 'r') as text_file:
                transcription = text_file.read()
            
            # Utiliser la méthode schedule_analysis du service Kaldi
            kaldi_service.schedule_analysis(
                session_id=session_id,
                turn_id=uuid.UUID(segment_id),
                audio_bytes=audio_bytes,
                transcription=transcription
            )
            logger.info(f"Analyse Kaldi planifiée pour segment {segment_id}")
        except Exception as e:
            logger.error(f"Erreur lors de la planification de l'analyse Kaldi: {e}", exc_info=True)

    async def _generate_gentle_prompt(self, session_id: str):
        """
        Génère une relance douce si l'utilisateur fait une pause moyenne.
        """
        session = self.active_sessions.get(session_id)
        # Vérifier l'état AVANT de potentiellement le modifier
        if not session or session["state"] != SESSION_STATE_USER_SPEAKING:
            # Ne pas générer si l'état n'est pas correct (ex: IA parle déjà, traitement en cours, ou déjà en relance)
            return

        # Éviter les relances trop fréquentes
        # TODO: Ajouter une logique de temporisation si nécessaire (ex: flag "relance_en_cours")

        logger.info(f"Session {session_id}: Génération d'une relance douce...")

        # Marquer l'état comme traitant la relance pour éviter conflits
        # Utiliser un état dédié serait plus propre, mais PROCESSING peut suffire pour l'instant
        original_state = session["state"]
        session["state"] = SESSION_STATE_PROCESSING

        try:
            # Prompt simple pour le LLM
            # Utiliser une copie de l'historique pour ne pas l'altérer
            prompt_history = session["history"].copy() + [{"role": "system", "content": "Génère une courte phrase de relance neutre ou encourageante pour inviter l'utilisateur à continuer après une pause (ex: 'Continuez...', 'Je vous écoute.', 'Oui ?'). Termine par [EMOTION: curiosite]."}]

            llm_response = await self.llm_service.generate(
                prompt_history,
                is_interrupted=False, # Ce n'est pas une interruption
                scenario_context=None, # Pas besoin du contexte scénario pour une simple relance
                session_id=session_id # Passer l'ID de session pour la mémoire conversationnelle
            )

            text_response = llm_response["text_response"]
            emotion_label = llm_response["emotion_label"] # Devrait être 'curiosite'

            # Vérifier si l'état a changé pendant l'appel LLM (ex: utilisateur a repris parole)
            if session["state"] != SESSION_STATE_PROCESSING:
                 logger.info(f"Session {session_id}: État changé pendant génération LLM de relance. Annulation TTS.")
                 return # Ne pas lancer TTS si l'état a changé

            # Synthèse vocale TTS de la relance
            logger.info(f"Relance douce TTS: '{text_response}' (Émotion: {emotion_label})")
            await self._send_message(session_id, {
                "type": WS_MSG_AUDIO_CONTROL,
                "event": AUDIO_IA_SPEECH_START
            })

            session["state"] = SESSION_STATE_IA_SPEAKING # L'IA (relance) parle

            audio_stream = await self.tts_service.synthesize_stream(
                text_response,
                session_id=session_id,
                emotion=emotion_label,
                language="fr"  # Langue par défaut
            )

            # Envoyer l'audio en streaming
            stream_interrupted = False
            async for audio_chunk in audio_stream:
                 # Vérifier si l'utilisateur a recommencé à parler PENDANT la relance
                 # Ou si une déconnexion/erreur est survenue
                if session["state"] != SESSION_STATE_IA_SPEAKING:
                    logger.info("Relance douce interrompue (état a changé).")
                    await self.tts_service.stop_generation(session_id) # Arrêter TTS
                    stream_interrupted = True
                    break
                await self._send_binary(session_id, audio_chunk)
                await asyncio.sleep(0.05) # Laisser du temps pour la boucle d'événements

            # Si la relance n'a pas été interrompue par un changement d'état externe
            if not stream_interrupted and session["state"] == SESSION_STATE_IA_SPEAKING:
                 session["state"] = SESSION_STATE_USER_SPEAKING # Revenir à l'écoute de l'utilisateur
                 await self._send_message(session_id, {
                     "type": WS_MSG_AUDIO_CONTROL,
                     "event": AUDIO_IA_SPEECH_END
                 })
                 # Réinitialiser le timer de silence pour éviter boucle infinie
                 session["last_speech_time"] = time.time()
                 session["silence_duration"] = 0
                 logger.info(f"Session {session_id}: Fin relance douce, retour à l'écoute.")

        except Exception as e:
            logger.error(f"Erreur lors de la génération de la relance douce: {e}", exc_info=True)
            # Revenir à l'état d'écoute initial en cas d'erreur
            if session["state"] in [SESSION_STATE_PROCESSING, SESSION_STATE_IA_SPEAKING]:
                 session["state"] = original_state # Revenir à l'état avant la tentative de relance
                 # Envoyer un message d'erreur ? Optionnel.

    # Les méthodes suivantes doivent être correctement indentées au niveau de la classe
    async def _save_session_data(self, session_id: str):
        """
        Sauvegarde les données de session dans la base de données.
        """
        session_data = self.active_sessions.get(session_id)
        if not session_data:
            return
        
        try:
            # Créer ou mettre à jour l'entrée de session
            db_session = Session(
                id=session_id,
                user_id="default",  # Utiliser un ID utilisateur par défaut
                language="fr",
                goal="Coaching vocal",
                current_scenario_state=json.dumps(session_data["scenario_context"]) if session_data["scenario_context"] else None,
                created_at=datetime.fromtimestamp(session_data["start_time"]),
                ended_at=datetime.now() if session_data["state"] == SESSION_STATE_ENDED else None,
                status="active" if session_data["state"] != SESSION_STATE_ENDED else "ended"
            )
            
            # Sauvegarder dans la BD
            self.db.add(db_session)
            await self.db.commit()
            
            logger.debug(f"Données de session sauvegardées: {session_id}")
        except Exception as e:
            logger.error(f"Erreur lors de la sauvegarde des données de session: {e}", exc_info=True)
            await self.db.rollback()
    
    async def _send_message(self, session_id: str, message: Dict):
        """
        Envoie un message JSON au client WebSocket.
        """
        logger.info(f"_send_message appelé avec session_id={session_id}, message={message}")
        
        websocket = self.connected_clients.get(session_id)
        logger.info(f"WebSocket trouvé: {websocket is not None}")
        
        if websocket:
            try:
                logger.info(f"Appel de send_json avec message={message}")
                await websocket.send_json(message)
                logger.info("send_json appelé avec succès")
            except Exception as e:
                logger.error(f"Erreur lors de l'envoi du message JSON: {e}", exc_info=True)
        else:
            logger.error(f"WebSocket non trouvé pour session_id={session_id}")
    
    async def _send_binary(self, session_id: str, data: bytes):
        """
        Envoie des données binaires au client WebSocket.
        """
        websocket = self.connected_clients.get(session_id)
        if websocket:
            try:
                await websocket.send_bytes(data)
            except Exception as e:
                logger.error(f"[WS] Erreur lors de l'envoi des données binaires: {e}", exc_info=True)
                # Notifier le client de l'erreur si possible via un autre canal
                try:
                    # Tenter d'envoyer un message d'erreur via le WebSocket
                    # Cela pourrait échouer si le WebSocket est fermé
                    await self._send_error(session_id, f"Erreur d'envoi audio: {str(e)}")
                except:
                    # Si cela échoue, logger l'erreur mais ne pas la propager
                    logger.error(f"[WS] Impossible d'envoyer la notification d'erreur au client")
        else:
            logger.error(f"[WS] WebSocket non trouvé pour session_id={session_id} lors de l'envoi de données binaires")
    
    async def _send_error(self, session_id: str, error_message: str):
        """
        Envoie un message d'erreur au client WebSocket.
        """
        await self._send_message(session_id, {
            "type": WS_MSG_ERROR,
            "message": error_message
        })
