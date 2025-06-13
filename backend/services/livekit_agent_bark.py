"""
Agent LiveKit avec Bark TTS - Voix françaises haute qualité
Version optimisée pour coaching vocal avec expressivité naturelle
"""

import asyncio
import logging
import os
import tempfile
import httpx
import numpy as np
import jwt
import time
from typing import Optional
from dotenv import load_dotenv

# Imports compatibles avec livekit-agents 0.7.2
from livekit import rtc
import webrtcvad

# Charger les variables d'environnement
load_dotenv()

# Configuration du logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("LIVEKIT_AGENT_BARK")

def generate_agent_token(room_name: str, participant_identity: str = "voice_coach_agent_bark") -> str:
    """Génère un token JWT pour l'agent avec les bonnes permissions"""
    api_key = os.getenv("LIVEKIT_API_KEY", "devkey")
    api_secret = os.getenv("LIVEKIT_API_SECRET", "devsecret123456789abcdef0123456789abcdef0123456789abcdef")
    
    now = int(time.time())
    exp = now + (24 * 60 * 60)  # 24 heures
    
    payload = {
        "iss": api_key,
        "sub": participant_identity,
        "iat": now,
        "exp": exp,
        "video": {
            "room": room_name,
            "roomJoin": True,
            "roomList": True,
            "roomRecord": False,
            "roomAdmin": True,  # Permissions d'admin pour l'agent
            "roomCreate": False,
            "canPublish": True,
            "canSubscribe": True,
            "canPublishData": True,
            "canUpdateOwnMetadata": True,
            "agent": True  # Marquer comme agent
        }
    }
    
    token = jwt.encode(payload, api_secret, algorithm="HS256")
    logger.info(f"🔑 Token agent Bark généré pour room: {room_name}")
    return token

class BarkVoiceCoachingAgent:
    """Agent de coaching vocal avec Bark TTS haute qualité"""
    
    def __init__(self):
        self.room = None
        self.participant = None
        self.audio_frames_processed = 0
        self.transcriptions_made = 0
        self.responses_generated = 0
        
        # Buffer audio pour le VAD
        self.audio_buffer = b''
        self.audio_buffer_sample_rate = 0
        
        # Services
        self.asr_url = "http://asr-service:8001/transcribe"
        # Utilisation de Piper TTS au lieu de Bark/XTTS
        self.tts_url = "http://piper-tts:8000/synthesize"
        
        # Configuration Piper TTS
        self.voice = os.getenv("TTS_VOICE", "default")
        
        # VAD pour détection de voix
        self.vad = webrtcvad.Vad(3) # Mode 3: le plus agressif (moins de faux positifs, mais peut manquer de la voix faible)
        
        # Réponses de coaching personnalisées
        self.coaching_responses = {
            "encouragement": [
                "Excellent travail ! Votre diction est remarquable.",
                "Bravo ! Votre prononciation s'améliore considérablement.",
                "Parfait ! Continuez sur cette lancée, c'est formidable.",
                "Magnifique ! Votre expressivité est très naturelle."
            ],
            "correction": [
                "Très bien ! Essayons de travailler un peu plus l'articulation.",
                "C'est bien ! Pouvons-nous répéter en articulant davantage ?",
                "Bonne tentative ! Concentrons-nous sur la fluidité.",
                "Intéressant ! Travaillons ensemble l'intonation."
            ],
            "exercices": [
                "Essayons maintenant un exercice de respiration. Inspirez profondément.",
                "Parfait ! Maintenant, répétez après moi : 'Les chaussettes de l'archiduchesse'.",
                "Excellent ! Travaillons la projection vocale. Parlez plus fort.",
                "Formidable ! Concentrons-nous sur le rythme de votre élocution."
            ]
        }
        
        logger.info(f"🎯 Agent Piper TTS initialisé avec voix: {self.voice}")
    
    async def transcribe_audio(self, audio_data: bytes) -> Optional[str]:
        """Transcription audio via notre service Whisper"""
        try:
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
                tmp_file.write(audio_data)
                tmp_file_path = tmp_file.name
            
            async with httpx.AsyncClient() as client:
                with open(tmp_file_path, 'rb') as audio_file:
                    files = {'file': ('audio.wav', audio_file, 'audio/wav')}
                    response = await client.post(
                        self.asr_url,
                        files=files,
                        timeout=30.0
                    )
                
                if response.status_code == 200:
                    result = response.json()
                    transcription = result.get('text', '').strip()
                    logger.info(f"📝 Transcription: '{transcription}'")
                    return transcription
                else:
                    logger.warning(f"⚠️ ASR erreur {response.status_code}")
                    return None
                    
        except Exception as e:
            logger.error(f"❌ Erreur STT: {e}")
            return None
        finally:
            try:
                os.unlink(tmp_file_path)
            except:
                pass
    
    def analyze_speech_quality(self, transcription: str) -> str:
        """Analyse la qualité de la parole et choisit le type de réponse"""
        if not transcription:
            return "encouragement"
        
        # Analyse simple basée sur la longueur et la complexité
        words = transcription.split()
        
        if len(words) >= 5 and len(transcription) > 20:
            return "encouragement"  # Bonne performance
        elif len(words) >= 2:
            return "correction"     # Performance moyenne
        else:
            return "exercices"      # Besoin d'exercices
    
    async def generate_response_audio(self, transcription: str) -> Optional[bytes]:
        """Génère une réponse audio avec Bark TTS haute qualité"""
        try:
            # Analyser la qualité de la parole
            response_type = self.analyze_speech_quality(transcription)
            
            # Choisir une réponse appropriée
            import random
            responses = self.coaching_responses[response_type]
            response_text = random.choice(responses)
            
            # Si on a une transcription, l'inclure dans la réponse
            if transcription and len(transcription.strip()) > 2:
                if response_type == "encouragement":
                    response_text = f"Parfait ! Vous avez dit '{transcription}'. {response_text}"
                elif response_type == "correction":
                    response_text = f"J'ai entendu '{transcription}'. {response_text}"
            
            # Préparer la requête pour Piper TTS
            piper_payload = {
                'text': response_text,
                'voice': self.voice
            }
            
            logger.info(f"🎤 Requête Piper TTS: {response_text[:50]}...")

            async with httpx.AsyncClient() as client:
                try:
                    response = await client.post(
                        self.tts_url,
                        json=piper_payload,
                        timeout=30.0
                    )
                    response.raise_for_status()
                    
                    audio_data = response.content
                    self.responses_generated += 1
                    logger.info(f"🗣️ Piper TTS généré: {len(audio_data)} octets")
                    return audio_data
                except httpx.HTTPStatusError as exc:
                    logger.warning(f"⚠️ Piper TTS erreur HTTP {exc.response.status_code}: {exc.response.text}")
                    return None
                except httpx.RequestError as exc:
                    logger.error(f"❌ Erreur requête Piper TTS: {exc}")
                    return None
                    
        except Exception as e:
            logger.error(f"❌ Erreur inattendue dans generate_response_audio: {e}")
            return None
    
    async def on_audio_frame(self, frame: rtc.AudioFrame):
        """Traite les frames audio reçues, en utilisant VAD pour détecter la parole.
        Accumule les frames pour former des chunks de 30ms pour le VAD."""
        try:
            self.audio_frames_processed += 1
            logger.debug(f"🔄 Traitement de la frame audio #{self.audio_frames_processed} (sample_rate: {frame.sample_rate}, num_channels: {frame.num_channels}, taille_donnees: {len(frame.data)} octets)")
            
            # Vérifier les propriétés de la frame
            if frame.num_channels != 1 or frame.sample_rate not in [8000, 16000, 32000, 48000]:
                logger.warning(f"⚠️ Frame audio inattendue: {frame.sample_rate} Hz, {frame.num_channels} canaux. Attendu: 1 canal, 8/16/32/48 kHz. Ignoré.")
                return

            # LiveKit fournit déjà du PCM 16-bit, donc frame.data est directement utilisable
            audio_data_bytes = frame.data
            
            # Vérifier la taille des données brutes
            if not audio_data_bytes:
                logger.debug("ℹ️ Frame audio reçue mais vide, ignorée.")
                return
            
            # Mettre à jour le sample_rate du buffer si c'est la première frame ou si le sample_rate change
            if self.audio_buffer_sample_rate == 0:
                self.audio_buffer_sample_rate = frame.sample_rate
            elif self.audio_buffer_sample_rate != frame.sample_rate:
                logger.warning(f"⚠️ Changement de sample_rate détecté ({self.audio_buffer_sample_rate} -> {frame.sample_rate}). Réinitialisation du buffer audio.")
                self.audio_buffer = b''
                self.audio_buffer_sample_rate = frame.sample_rate

            # Ajouter les nouvelles données au buffer
            self.audio_buffer += audio_data_bytes
            
            # Le VAD de webrtcvad fonctionne avec des frames de 10, 20 ou 30 ms.
            # Nous allons utiliser 30ms pour la détection de voix.
            # Calculer la taille d'une frame VAD en octets (sample_rate * durée_ms / 1000 * bytes_per_sample)
            # 16-bit PCM = 2 bytes par échantillon
            frame_duration_ms = 30
            bytes_per_frame_vad = int(self.audio_buffer_sample_rate * (frame_duration_ms / 1000.0) * 2)

            # Traiter les données par blocs compatibles VAD tant que le buffer est assez grand
            while len(self.audio_buffer) >= bytes_per_frame_vad:
                chunk = self.audio_buffer[:bytes_per_frame_vad]
                self.audio_buffer = self.audio_buffer[bytes_per_frame_vad:] # Retirer le chunk traité du buffer

                # Calculer le niveau audio RMS pour le debug
                audio_array = np.frombuffer(chunk, dtype=np.int16)
                rms = np.sqrt(np.mean(audio_array**2))
                max_val = np.max(np.abs(audio_array)) if len(audio_array) > 0 else 0
                
                # Log du niveau audio toutes les 10 frames
                if self.audio_frames_processed % 10 == 0:
                    logger.debug(f"📊 Niveau audio - RMS: {rms:.2f}, Max: {max_val}, Taille chunk: {len(chunk)} octets")

                if self.vad.is_speech(chunk, self.audio_buffer_sample_rate):
                    logger.debug(f"🗣️ Voix détectée dans un chunk de {frame_duration_ms}ms (RMS: {rms:.2f}). Envoi à l'ASR.")
                    
                    # Convertir en WAV pour le STT
                    import wave
                    import io
                    
                    wav_buffer = io.BytesIO()
                    with wave.open(wav_buffer, 'wb') as wav_file:
                        wav_file.setnchannels(frame.num_channels)
                        wav_file.setsampwidth(2)  # 16-bit
                        wav_file.setframerate(self.audio_buffer_sample_rate)
                        wav_file.writeframes(chunk) # Utiliser le chunk détecté comme voix
                    
                    wav_data = wav_buffer.getvalue()
                    logger.debug(f"📊 Données WAV préparées pour ASR (taille: {len(wav_data)} octets).")
                    
                    # Transcription
                    transcription = await self.transcribe_audio(wav_data)
                    
                    if transcription and len(transcription.strip()) > 2:
                        self.transcriptions_made += 1
                        logger.info(f"✅ Transcription non vide: '{transcription}'")
                        
                        # Générer une réponse audio avec Bark
                        response_audio = await self.generate_response_audio(transcription)
                        
                        if response_audio and self.room:
                            logger.info(f"🔊 Envoi de la réponse audio XTTS (taille: {len(response_audio)} octets).")
                            audio_source = rtc.AudioSource(sample_rate=16000, num_channels=1) # XTTS sort souvent en 24kHz, un rééchantillonnage pourrait être nécessaire ici ou côté serveur XTTS
                            track = rtc.LocalAudioTrack.create_audio_track("xtts_coaching_response", audio_source)
                            
                            await self.room.local_participant.publish_track(track, rtc.TrackPublishOptions())
                            
                            # S'assurer que response_audio est bien en PCM 16kHz mono pour LiveKit
                            # Un rééchantillonnage et une conversion de format pourraient être nécessaires ici
                            # si le service XTTS ne le fait pas. Pour l'instant, on suppose qu'il est correct.
                            await audio_source.capture_frame(rtc.AudioFrame(
                                data=response_audio,
                                sample_rate=16000,
                                num_channels=1,
                                samples_per_channel=len(response_audio) // 2
                            ))
                            logger.info("✅ Réponse audio envoyée.")
                        else:
                            logger.warning("⚠️ Aucune réponse audio générée ou room non disponible.")
                    else:
                        logger.info("📝 Transcription vide ou trop courte, pas de réponse générée.")
                else:
                    logger.debug("🔇 Silence détecté dans le chunk audio, ignoré.")
            
        except Exception as e:
            logger.error(f"❌ Erreur traitement audio dans on_audio_frame: {e}")
    
    async def connect_to_room(self, room_url: str, token: str):
        """Se connecte à la room LiveKit"""
        try:
            self.room = rtc.Room()
            
            # Événements de la room
            @self.room.on("participant_connected")
            def on_participant_connected(participant: rtc.RemoteParticipant):
                logger.info(f"👤 Participant connecté: {participant.identity}")

            # Nouvelle fonction pour traiter le flux audio d'une piste distante
            async def _process_remote_audio_stream(track: rtc.RemoteAudioTrack, participant_identity: str): # Ajout de participant_identity
                logger.info(f"🎧 Démarrage du traitement du flux audio pour la piste: {track.sid} de {participant_identity}") # Utilisation de participant_identity
                try:
                    # Utiliser track.stream() pour obtenir un AsyncIterable[AudioFrame]
                    # Créer un AudioStream à partir de la piste audio distante
                    audio_stream = rtc.AudioStream(track) # MODIFICATION ICI
                    # Itérer sur le flux audio pour obtenir les frames
                    async for frame in audio_stream: # MODIFICATION ICI
                        # Accéder à la frame audio via event.frame
                        await self.on_audio_frame(frame.frame)
                except Exception as e:
                    logger.error(f"❌ Erreur pendant le traitement du flux audio pour la piste {track.sid} de {participant_identity}: {e}")
                finally:
                    logger.info(f"🏁 Fin du traitement du flux audio pour la piste: {track.sid} de {participant_identity}")

            @self.room.on("track_subscribed")
            def on_track_subscribed(track: rtc.Track,
                                    publication: rtc.TrackPublication,
                                    participant: rtc.RemoteParticipant):
                logger.info(f"🎵 Track souscrit: {track.kind} (SID: {track.sid}) de {participant.identity}")
                if track.kind == rtc.TrackKind.KIND_AUDIO and isinstance(track, rtc.RemoteAudioTrack):
                    if participant.identity != self.room.local_participant.identity:
                        logger.info(f"🎤 Piste audio distante détectée de {participant.identity}, SID: {track.sid}. Lancement du traitement du flux.")
                        # Lancer une tâche asyncio pour traiter le flux de cette piste
                        asyncio.create_task(_process_remote_audio_stream(track, participant.identity)) # Passer participant.identity
                    else:
                        logger.info(f"🎤 Piste audio locale (de l'agent) détectée de {participant.identity}, SID: {track.sid}, ignorée pour la souscription de frame.")
                else:
                    logger.info(f"ℹ️ Piste non-audio ou non-distante souscrite: {track.kind} (SID: {track.sid}) de {participant.identity}")
            
            # Se connecter
            await self.room.connect(room_url, token)
            logger.info(f"✅ Connecté à la room: {self.room.name}")
            
            # Message d'accueil avec Piper TTS
            welcome_message = "Bonjour ! Je suis votre coach vocal IA. Commencez à parler pour que je puisse vous accompagner."
            welcome_audio = await self.generate_response_audio(welcome_message)
            
            if welcome_audio:
                # Publier le message d'accueil
                audio_source = rtc.AudioSource(sample_rate=16000, num_channels=1) # Idem, vérifier le format de sortie XTTS
                track = rtc.LocalAudioTrack.create_audio_track("xtts_welcome", audio_source)
                await self.room.local_participant.publish_track(track, rtc.TrackPublishOptions())
                
                await audio_source.capture_frame(rtc.AudioFrame(
                    data=welcome_audio,
                    sample_rate=16000,
                    num_channels=1,
                    samples_per_channel=len(welcome_audio) // 2
                ))
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Erreur connexion room: {e}")
            return False

async def main():
    """Point d'entrée principal"""
    # Lire les informations de connexion depuis les variables d'environnement
    room_name = os.getenv("ROOM_NAME")
    participant_identity = os.getenv("PARTICIPANT_IDENTITY", "voice_coach_agent_bark")
    livekit_url = os.getenv("LIVEKIT_URL", "ws://livekit-server:7880")

    if not room_name:
        logger.error("❌ Variable d'environnement ROOM_NAME doit être définie.")
        return

    logger.info(f"🚀 Lancement de l'agent Bark pour room: {room_name}")
    logger.info(f"🎤 Voix configurée: {os.getenv('TTS_VOICE', 'v2/fr_speaker_1')}")
    
    # Générer le token pour l'agent
    agent_token = generate_agent_token(room_name, participant_identity)
    logger.info(f"🔑 Token agent: {agent_token[:50]}...")
    
    # Créer et démarrer l'agent
    agent = BarkVoiceCoachingAgent()
    
    success = await agent.connect_to_room(livekit_url, agent_token)
    
    if success:
        logger.info("✅ Agent Bark démarré avec succès")
        
        # Maintenir la connexion
        try:
            while True:
                await asyncio.sleep(5)
                
                # Log des statistiques périodiquement
                if agent.audio_frames_processed % 100 == 0 and agent.audio_frames_processed > 0:
                    logger.info(f"📊 Stats - Frames: {agent.audio_frames_processed}, Transcriptions: {agent.transcriptions_made}, Réponses Bark: {agent.responses_generated}")
                    
        except KeyboardInterrupt:
            logger.info("🛑 Arrêt de l'agent Bark demandé")
        except Exception as e:
            logger.error(f"❌ Erreur dans la boucle principale: {e}")
        finally:
            if agent.room:
                await agent.room.disconnect()
            logger.info("🔌 Agent Bark déconnecté")
    else:
        logger.error("❌ Impossible de démarrer l'agent Bark")

if __name__ == "__main__":
    asyncio.run(main())
