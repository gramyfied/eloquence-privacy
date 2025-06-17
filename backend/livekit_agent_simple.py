"""
Agent LiveKit Simple pour Coaching Vocal IA
Version compatible avec livekit-agents 0.7.2
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
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("LIVEKIT_AGENT_SIMPLE")

def generate_agent_token(room_name: str, participant_identity: str = "voice_coach_agent") -> str:
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
    logger.info(f"🔑 Token agent généré pour room: {room_name}")
    return token

class SimpleVoiceCoachingAgent:
    """Agent de coaching vocal simple"""
    
    def __init__(self):
        self.room = None
        self.participant = None
        self.audio_frames_processed = 0
        self.transcriptions_made = 0
        
        # Services
        self.asr_url = "http://asr-service:8001/transcribe"
        self.tts_url = "http://tts-service:5002/api/tts"
        
        # VAD pour détection de voix
        self.vad = webrtcvad.Vad(3)
        
        logger.info("🎯 Agent de coaching vocal simple initialisé")
    
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
    
    async def generate_response_audio(self, text: str) -> Optional[bytes]:
        """Génère une réponse audio via TTS"""
        try:
            # Réponses de coaching vocal
            coaching_responses = [
                f"Excellent ! Vous avez dit '{text}'. Votre diction est claire.",
                f"Très bien ! J'ai entendu '{text}'. Continuons l'exercice.",
                f"Parfait ! Votre prononciation s'améliore. Bravo !",
                f"Formidable ! Essayons maintenant un autre exercice."
            ]
            
            import random
            response_text = random.choice(coaching_responses)
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.tts_url,
                    json={'text': response_text},
                    timeout=15.0
                )
                
                if response.status_code == 200:
                    audio_data = response.content
                    logger.info(f"🗣️ TTS généré: {len(audio_data)} octets")
                    return audio_data
                else:
                    logger.warning(f"⚠️ TTS erreur {response.status_code}")
                    return None
                    
        except Exception as e:
            logger.error(f"❌ Erreur TTS: {e}")
            return None
    
    async def on_audio_frame(self, frame: rtc.AudioFrame):
        """Traite les frames audio reçues"""
        try:
            self.audio_frames_processed += 1
            
            # Convertir la frame en données audio
            audio_data = np.frombuffer(frame.data, dtype=np.int16)
            
            # Convertir en WAV pour le STT
            import wave
            import io
            
            wav_buffer = io.BytesIO()
            with wave.open(wav_buffer, 'wb') as wav_file:
                wav_file.setnchannels(1)  # Mono
                wav_file.setsampwidth(2)  # 16-bit
                wav_file.setframerate(frame.sample_rate)
                wav_file.writeframes(audio_data.tobytes())
            
            wav_data = wav_buffer.getvalue()
            
            # Transcription
            transcription = await self.transcribe_audio(wav_data)
            
            if transcription and len(transcription.strip()) > 2:
                self.transcriptions_made += 1
                
                # Générer une réponse audio
                response_audio = await self.generate_response_audio(transcription)
                
                if response_audio and self.room:
                    # Envoyer la réponse audio
                    audio_source = rtc.AudioSource(sample_rate=22050, num_channels=1)
                    track = rtc.LocalAudioTrack.create_audio_track("coaching_response", audio_source)
                    
                    # Publier le track audio
                    await self.room.local_participant.publish_track(track, rtc.TrackPublishOptions())
                    
                    # Envoyer les données audio
                    await audio_source.capture_frame(rtc.AudioFrame(
                        data=response_audio,
                        sample_rate=22050,
                        num_channels=1,
                        samples_per_channel=len(response_audio) // 2
                    ))
            
        except Exception as e:
            logger.error(f"❌ Erreur traitement audio: {e}")
    
    async def connect_to_room(self, room_url: str, token: str):
        """Se connecte à la room LiveKit"""
        try:
            self.room = rtc.Room()
            
            # Événements de la room
            @self.room.on("participant_connected")
            def on_participant_connected(participant: rtc.RemoteParticipant):
                logger.info(f"👤 Participant connecté: {participant.identity}")
            
            @self.room.on("track_subscribed")
            def on_track_subscribed(track: rtc.Track, publication: rtc.TrackPublication, participant: rtc.RemoteParticipant):
                logger.info(f"🎵 Track souscrit: {track.kind}")
                if track.kind == rtc.TrackKind.KIND_AUDIO:
                    audio_track = track
                    audio_track.on("frame_received", self.on_audio_frame)
            
            # Se connecter
            await self.room.connect(room_url, token)
            logger.info(f"✅ Connecté à la room: {self.room.name}")
            
            # Message d'accueil
            welcome_message = "Bonjour ! Je suis votre coach vocal IA. Commencez à parler pour que je puisse vous aider."
            welcome_audio = await self.generate_response_audio(welcome_message)
            
            if welcome_audio:
                # Publier le message d'accueil
                audio_source = rtc.AudioSource(sample_rate=22050, num_channels=1)
                track = rtc.LocalAudioTrack.create_audio_track("welcome", audio_source)
                await self.room.local_participant.publish_track(track, rtc.TrackPublishOptions())
                
                await audio_source.capture_frame(rtc.AudioFrame(
                    data=welcome_audio,
                    sample_rate=22050,
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
    participant_identity = os.getenv("PARTICIPANT_IDENTITY", "voice_coach_agent")
    livekit_url = os.getenv("LIVEKIT_URL", "ws://livekit-server:7880")

    if not room_name:
        logger.error("❌ Variable d'environnement ROOM_NAME doit être définie.")
        return

    logger.info(f"🚀 Lancement de l'agent simple pour room: {room_name}")
    
    # Générer le token pour l'agent
    agent_token = generate_agent_token(room_name, participant_identity)
    logger.info(f"🔑 Token agent: {agent_token[:50]}...")
    
    # Créer et démarrer l'agent
    agent = SimpleVoiceCoachingAgent()
    
    success = await agent.connect_to_room(livekit_url, agent_token)
    
    if success:
        logger.info("✅ Agent démarré avec succès")
        
        # Maintenir la connexion
        try:
            while True:
                await asyncio.sleep(1)
                
                # Log des statistiques périodiquement
                if agent.audio_frames_processed % 100 == 0 and agent.audio_frames_processed > 0:
                    logger.info(f"📊 Frames traitées: {agent.audio_frames_processed}, Transcriptions: {agent.transcriptions_made}")
                    
        except KeyboardInterrupt:
            logger.info("🛑 Arrêt de l'agent demandé")
        except Exception as e:
            logger.error(f"❌ Erreur dans la boucle principale: {e}")
        finally:
            if agent.room:
                await agent.room.disconnect()
            logger.info("🔌 Agent déconnecté")
    else:
        logger.error("❌ Impossible de démarrer l'agent")

if __name__ == "__main__":
    asyncio.run(main())