#!/usr/bin/env python3
"""
Agent LiveKit Eloquence 2.0 - Version Docker avec monitoring
Utilise: Whisper STT, Piper TTS, Mistral API (Scaleway)
"""
import asyncio
import logging
import os
import time
import numpy as np
import wave
from livekit import rtc, api
import aiohttp
from io import BytesIO
from dotenv import load_dotenv
from aiohttp import web

# Charger les variables d'environnement
load_dotenv()

# Configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ELOQUENCE_AGENT")

# URLs des services
LIVEKIT_URL = os.getenv("LIVEKIT_URL", "ws://192.168.1.44:7888")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY", "devkey")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET", "secret")
WHISPER_URL = os.getenv("WHISPER_STT_URL", "http://192.168.1.44:8001")
PIPER_URL = "http://192.168.1.44:8020"  # Force la bonne URL
MISTRAL_API_KEY = os.getenv("MISTRAL_API_KEY")
MISTRAL_BASE_URL = os.getenv("MISTRAL_BASE_URL")
MISTRAL_MODEL = os.getenv("MISTRAL_MODEL", "mistral-nemo-instruct-2407")

# Variables globales pour le monitoring
agent_status = {"connected": False, "room": None, "participants": 0}

class EloquenceCoachAgent:
    def __init__(self, room: rtc.Room):
        self.room = room
        self.audio_source = rtc.AudioSource(48000, 1)
        self.audio_track = None
        self.is_processing = False
        self.audio_buffer = BytesIO()
        self.conversation_history = []
        self.has_greeted = False  # Pour éviter de répéter le message de bienvenue
        self.processing_participants = set()  # Pour éviter le traitement en double
        self.active_participant = None  # Un seul participant actif à la fois
        
    async def start(self):
        logger.info(f"🎤 Agent Eloquence démarré dans {self.room.name}")
        
        # Publier la piste audio
        self.audio_track = rtc.LocalAudioTrack.create_audio_track("agent-voice", self.audio_source)
        await self.room.local_participant.publish_track(self.audio_track)
        logger.info("🔊 Piste audio publiée")
        
        # Événements
        self.room.on("participant_connected", lambda participant: asyncio.create_task(self.on_participant_connected(participant)))
        self.room.on("track_subscribed", lambda track, publication, participant: asyncio.create_task(self.on_track_subscribed(track, publication, participant)))
        
        # Mettre à jour le statut
        agent_status["connected"] = True
        agent_status["room"] = self.room.name
        
    async def on_participant_connected(self, participant: rtc.RemoteParticipant):
        if not participant.identity.startswith("agent-"):
            logger.info(f"👋 Nouveau participant: {participant.identity}")
            agent_status["participants"] = len(self.room.remote_participants)
            
            # Ne pas envoyer de message de bienvenue automatique
            # Attendre que l'utilisateur parle en premier
    
    async def on_track_subscribed(self, track: rtc.Track, publication, participant):
        if track.kind == rtc.TrackKind.KIND_AUDIO and not participant.identity.startswith("agent-"):
            logger.info(f"🎧 Audio reçu de {participant.identity}")
            
            # N'accepter qu'un seul participant actif à la fois
            if hasattr(self, 'active_participant') and self.active_participant:
                if self.active_participant != participant.identity:
                    logger.warning(f"⚠️ Participant {participant.identity} ignoré - déjà en conversation avec {self.active_participant}")
                    return
                else:
                    logger.info(f"📍 Continuation avec le participant actif: {participant.identity}")
            else:
                self.active_participant = participant.identity
                logger.info(f"✅ Premier participant accepté: {participant.identity}")
            
            audio_stream = rtc.AudioStream(track)
            asyncio.create_task(self.process_audio_stream(audio_stream, participant))
            
    async def process_audio_stream(self, audio_stream, participant):
        """Traite l'audio entrant avec VAD simple"""
        # Éviter le traitement en double du même participant
        if participant.identity in self.processing_participants:
            logger.info(f"⚠️ Participant {participant.identity} déjà en cours de traitement")
            return
            
        self.processing_participants.add(participant.identity)
        
        silence_duration = 0
        speaking = False
        
        try:
            async for event in audio_stream:
                frame = event.frame
                audio_data = np.frombuffer(frame.data, dtype=np.int16)
                
                # Détection de parole simple
                volume = np.abs(audio_data).mean()
                if volume > 500:  # Seuil de détection
                    if not speaking:
                        logger.info(f"🗣️ {participant.identity} parle")
                        speaking = True
                        self.audio_buffer = BytesIO()
                    self.audio_buffer.write(frame.data)
                    silence_duration = 0
                else:
                    if speaking:
                        silence_duration += len(audio_data) / frame.sample_rate
                        if silence_duration > 1.0:  # 1 seconde de silence
                            logger.info(f"🤫 Fin de parole détectée")
                            speaking = False
                            await self.process_speech()
        finally:
            # Retirer le participant de la liste de traitement
            self.processing_participants.discard(participant.identity)
                        
    async def process_speech(self):
        """Traite la parole capturée"""
        if self.is_processing:
            return
            
        self.is_processing = True
        try:
            # Récupérer l'audio
            self.audio_buffer.seek(0)
            audio_data = self.audio_buffer.read()
            
            if not audio_data:
                return
            
            # Transcrire avec Whisper
            text = await self.transcribe_audio(audio_data)
            
            if text and len(text.strip()) > 0:
                logger.info(f"💬 Utilisateur dit: '{text}'")
                
                # Nettoyer le texte des répétitions
                words = text.split()
                
                # Détecter les répétitions excessives
                if len(words) > 3:
                    # Compter les occurrences de chaque phrase
                    phrase_counts = {}
                    for i in range(len(words) - 2):
                        phrase = " ".join(words[i:i+3])
                        phrase_counts[phrase] = phrase_counts.get(phrase, 0) + 1
                    
                    # Si une phrase est répétée plus de 3 fois, nettoyer
                    max_repetitions = max(phrase_counts.values()) if phrase_counts else 0
                    if max_repetitions > 3:
                        # Garder seulement les mots uniques dans l'ordre
                        seen = set()
                        cleaned_words = []
                        for word in words:
                            if word not in seen or len(seen) < 5:
                                seen.add(word)
                                cleaned_words.append(word)
                        text = " ".join(cleaned_words[:20])  # Limiter à 20 mots
                        logger.info(f"🧹 Texte nettoyé: '{text}'")
                
                # Vérifier si c'est juste des points ou du bruit
                if text.strip() in ['...', '..', '.', '', ' ', 'Ah ah ah']:
                    logger.info("🔇 Ignoré: bruit ou silence détecté")
                    return
                
                # Ajouter à l'historique
                self.conversation_history.append({"role": "user", "content": text})
                
                # Générer une réponse avec Mistral
                response = await self.generate_mistral_response(text)
                
                # Ajouter la réponse à l'historique
                self.conversation_history.append({"role": "assistant", "content": response})
                
                # Synthétiser et envoyer
                await self.send_audio_message(response)
                
        except Exception as e:
            logger.error(f"Erreur traitement: {e}")
        finally:
            self.is_processing = False
            self.audio_buffer = BytesIO()
            
    def convert_raw_audio_to_wav(self, raw_audio_data: bytes, sample_rate: int = 48000) -> bytes:
        """Convertit l'audio brut en WAV valide pour Whisper"""
        try:
            if len(raw_audio_data) % 2 != 0:
                raw_audio_data += b'\x00'
            
            audio_array = np.frombuffer(raw_audio_data, dtype=np.int16)
            wav_buffer = BytesIO()
            
            with wave.open(wav_buffer, 'wb') as wav_file:
                wav_file.setnchannels(1)  # Mono
                wav_file.setsampwidth(2)  # 16-bit
                wav_file.setframerate(sample_rate)
                wav_file.writeframes(audio_array.tobytes())
            
            wav_buffer.seek(0)
            return wav_buffer.read()
        except Exception as e:
            logger.error(f"Erreur conversion WAV: {e}")
            return b""
            
    async def transcribe_audio(self, audio_data: bytes) -> str:
        """Transcrit l'audio avec Whisper"""
        try:
            # CORRECTION: Convertir en WAV valide
            wav_data = self.convert_raw_audio_to_wav(audio_data)
            if not wav_data:
                return ""
            
            async with aiohttp.ClientSession() as session:
                form_data = aiohttp.FormData()
                form_data.add_field('audio', wav_data,
                                  filename='audio.wav',
                                  content_type='audio/wav')
                
                async with session.post(f"{WHISPER_URL}/transcribe", data=form_data) as resp:
                    if resp.status == 200:
                        result = await resp.json()
                        text = result.get("text", "")
                        logger.info(f"📝 Transcrit: '{text}'")
                        return text
                    else:
                        logger.error(f"Erreur Whisper: {resp.status}")
        except Exception as e:
            logger.error(f"Erreur transcription: {e}")
        return ""
    
    async def generate_mistral_response(self, user_text: str) -> str:
        """Génère une réponse avec Mistral API"""
        try:
            # Si c'est la première interaction et qu'on n'a pas encore salué
            if not self.has_greeted and len(self.conversation_history) <= 2:
                self.has_greeted = True
                return "Bonjour ! Je suis votre coach IA pour l'entretien d'embauche. Commençons par une présentation rapide de vous-même."
            
            # Préparer le contexte système
            system_message = {
                "role": "system",
                "content": """Tu es un coach IA spécialisé dans la préparation aux entretiens d'embauche en français.
                
                Ton rôle :
                - Aider les candidats à se préparer aux entretiens
                - Poser des questions d'entretien typiques
                - Donner des conseils personnalisés et pratiques
                - Fournir des retours constructifs
                - Simuler des situations d'entretien réalistes
                
                IMPORTANT: Ne répète pas le message de bienvenue. Si l'utilisateur a déjà été accueilli, passe directement aux questions d'entretien ou réponds à ses questions.
                
                Sois bienveillant, encourageant et professionnel. Adapte tes questions au niveau et au domaine du candidat.
                Garde tes réponses concises et naturelles pour la conversation vocale."""
            }
            
            # Construire les messages avec l'historique complet
            messages = [system_message]
            
            # Ajouter tout l'historique de conversation SAUF le dernier message utilisateur
            # car il vient d'être ajouté et on ne veut pas le dupliquer
            for msg in self.conversation_history[:-1]:
                messages.append(msg)
            
            # Ajouter le message utilisateur actuel
            messages.append({"role": "user", "content": user_text})
            
            async with aiohttp.ClientSession() as session:
                headers = {
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {MISTRAL_API_KEY}"
                }
                
                payload = {
                    "model": MISTRAL_MODEL,
                    "messages": messages,
                    "temperature": 0.7,
                    "max_tokens": 200  # Réponses courtes pour l'audio
                }
                
                async with session.post(MISTRAL_BASE_URL, headers=headers, json=payload) as resp:
                    if resp.status == 200:
                        result = await resp.json()
                        response = result["choices"][0]["message"]["content"]
                        logger.info(f"🤖 Mistral: {response[:100]}...")
                        return response
                    else:
                        error_text = await resp.text()
                        logger.error(f"Erreur Mistral: {resp.status} - {error_text}")
                        return "Je n'ai pas pu générer une réponse. Pouvez-vous répéter votre question ?"
                        
        except Exception as e:
            logger.error(f"Erreur Mistral API: {e}")
            return "Désolé, j'ai rencontré un problème technique. Pouvez-vous répéter ?"
    
    async def send_audio_message(self, text: str):
        """Synthétise et envoie l'audio avec Piper"""
        try:
            # Synthétiser avec Piper
            audio_data = await self.synthesize_speech(text)
            
            if audio_data:
                # Convertir en numpy
                audio_int16 = np.frombuffer(audio_data, dtype=np.int16)
                
                # Envoyer par chunks
                sample_rate = 48000
                chunk_size = 960  # 20ms à 48kHz
                
                for i in range(0, len(audio_int16), chunk_size):
                    chunk = audio_int16[i:i + chunk_size]
                    if len(chunk) < chunk_size:
                        chunk = np.pad(chunk, (0, chunk_size - len(chunk)), 'constant')
                    
                    frame = rtc.AudioFrame(chunk.tobytes(), sample_rate, 1, len(chunk))
                    await self.audio_source.capture_frame(frame)
                    await asyncio.sleep(0.018)  # ~20ms
                    
                logger.info(f"🔊 Audio envoyé: {text[:50]}...")
                
        except Exception as e:
            logger.error(f"Erreur envoi audio: {e}")
            
    async def synthesize_speech(self, text: str) -> bytes:
        """Synthétise le texte avec OpenedAI Speech (compatible OpenAI)"""
        try:
            async with aiohttp.ClientSession() as session:
                # Utiliser l'API OpenAI-compatible
                payload = {
                    "model": "tts-1",
                    "input": text,
                    "voice": "nova",  # Voix féminine douce
                    "response_format": "pcm",  # PCM pour LiveKit
                    "speed": 1.0
                }
                
                headers = {
                    "Content-Type": "application/json"
                }
                
                async with session.post(
                    f"{PIPER_URL}/v1/audio/speech",
                    json=payload,
                    headers=headers
                ) as resp:
                    if resp.status == 200:
                        audio_data = await resp.read()
                        logger.info(f"🎵 TTS généré: {len(audio_data)} bytes")
                        
                        # Convertir en PCM 48kHz si nécessaire
                        # OpenedAI Speech retourne du PCM 24kHz par défaut
                        # On doit resampler à 48kHz pour LiveKit
                        import numpy as np
                        
                        # Supposer PCM 16-bit mono 24kHz
                        audio_array = np.frombuffer(audio_data, dtype=np.int16)
                        
                        # Resample simple 24kHz -> 48kHz (doubler les échantillons)
                        resampled = np.repeat(audio_array, 2)
                        
                        return resampled.tobytes()
                    else:
                        error_text = await resp.text()
                        logger.error(f"Erreur OpenedAI Speech: {resp.status} - {error_text}")
        except Exception as e:
            logger.error(f"Erreur synthèse: {e}")
        return b""

# Serveur de monitoring
async def health_check(request):
    """Endpoint de santé pour Docker"""
    return web.json_response({
        "status": "healthy" if agent_status["connected"] else "starting",
        "agent": agent_status,
        "timestamp": time.time()
    })

async def start_health_server():
    """Démarre le serveur de monitoring"""
    app = web.Application()
    app.router.add_get('/health', health_check)
    
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 8080)
    await site.start()
    logger.info("🏥 Serveur de santé démarré sur le port 8080")

async def main():
    """Point d'entrée principal"""
    logger.info("🚀 Démarrage de l'agent Eloquence 2.0 (Docker)")
    logger.info(f"📍 Services configurés:")
    logger.info(f"   - LiveKit: {LIVEKIT_URL}")
    logger.info(f"   - Whisper STT: {WHISPER_URL}")
    logger.info(f"   - Piper TTS: {PIPER_URL}")
    logger.info(f"   - Mistral LLM: {MISTRAL_MODEL}")
    
    # Démarrer le serveur de santé
    await start_health_server()
    
    # Attendre que tous les participants se connectent
    room_name = "coaching-room-1"
    
    # Créer le token
    token = api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
    token.with_identity(f"agent-eloquence-{os.getpid()}")
    token.with_name("Coach IA Eloquence")
    token.with_grants(api.VideoGrants(
        room_join=True,
        room=room_name,
        can_publish=True,
        can_subscribe=True,
        can_publish_data=True
    ))
    
    # Connexion
    room = rtc.Room()
    try:
        await room.connect(
            LIVEKIT_URL,
            token.to_jwt(),
            options=rtc.RoomOptions(
                auto_subscribe=True,
                dynacast=True
            )
        )
        logger.info(f"✅ Connecté à la room: {room.name}")
        
        # Démarrer l'agent
        agent = EloquenceCoachAgent(room)
        await agent.start()
        
        # Boucle principale
        while True:
            await asyncio.sleep(30)
            participants = [p.identity for p in room.remote_participants.values()]
            agent_status["participants"] = len(participants)
            logger.info(f"[STATUS] Room: {room.name}, Participants: {participants}")
            
    except KeyboardInterrupt:
        logger.info("⏹️ Arrêt demandé")
    except Exception as e:
        logger.error(f"❌ Erreur: {e}")
        agent_status["connected"] = False
    finally:
        await room.disconnect()
        logger.info("👋 Agent déconnecté")

if __name__ == "__main__":
    asyncio.run(main())