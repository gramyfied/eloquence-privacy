import asyncio
import logging
import json
import time
import tempfile
import os
from typing import Dict, Any, Optional
from livekit import rtc, api
import httpx
import numpy as np
# Remplacer pydub par notre solution scipy
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from audio_utils_scipy import AudioSegmentScipy, resample_audio_scipy, create_wav_file_scipy

# Configuration du logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("LIVEKIT_REAL_HANDLER")

class LiveKitRealAudioHandler:
    """
    VRAI Handler LiveKit pour l'orchestration audio en temps réel
    Frontend → LiveKit → Whisper ASR → IA → Coqui TTS → LiveKit → Frontend
    """
    
    def __init__(self, room_name: str, api_key: str, api_secret: str, livekit_url: str):
        self.room_name = room_name
        self.api_key = api_key
        self.api_secret = api_secret
        self.livekit_url = livekit_url
        
        # Composants LiveKit
        self.room = None
        self.audio_source = None
        self.connected = False
        
        # Buffers audio
        self.audio_buffer = []
        self.sample_rate = 48000  # LiveKit sample rate
        self.target_asr_sample_rate = 16000 # Whisper ASR target sample rate
        self.PROCESS_CHUNK_THRESHOLD = 240 # Process every 240 samples (one LiveKit audio frame)
        
        # Compteurs de diagnostic
        self.audio_frames_received = 0
        self.transcriptions_made = 0
        self.tts_responses_sent = 0
        self.errors_count = 0
        
        logger.info(f"🎯 REAL HANDLER: Initialisé pour room {room_name}")
    
    async def connect_to_room(self) -> bool:
        """Connexion RÉELLE à LiveKit"""
        try:
            logger.info(f"🔗 REAL HANDLER: Connexion à LiveKit...")
            
            # Créer le token
            token = api.AccessToken(self.api_key, self.api_secret) \
                .with_identity("ai-backend-agent") \
                .with_name("IA Backend Agent") \
                .with_grants(api.VideoGrants(
                    room_join=True,
                    room=self.room_name,
                    can_publish=True,
                    can_subscribe=True,
                    can_publish_data=True
                ))
            
            # Connexion à la room
            self.room = rtc.Room()
            
            # Configurer les callbacks
            self.room.on("track_subscribed", self._on_track_subscribed)
            self.room.on("participant_connected", self._on_participant_connected)
            self.room.on("data_received", self._on_data_received)
            
            # Se connecter
            await self.room.connect(self.livekit_url, token.to_jwt())
            
            # Créer la source audio pour les réponses TTS
            self.audio_source = rtc.AudioSource(self.sample_rate, 1)  # 48kHz, mono
            track = rtc.LocalAudioTrack.create_audio_track("ai-response", self.audio_source)
            
            # Publier la piste audio
            await self.room.local_participant.publish_track(track, rtc.TrackPublishOptions())
            
            self.connected = True
            logger.info("✅ REAL HANDLER: Connecté à LiveKit avec succès!")
            return True
            
        except Exception as e:
            logger.error(f"❌ REAL HANDLER: Erreur connexion: {e}")
            self.errors_count += 1
            return False
    
    def _on_participant_connected(self, participant):
        """Callback: nouveau participant connecté"""
        logger.info(f"👤 REAL HANDLER: Participant connecté: {participant.identity}")
    
    def _on_track_subscribed(self, track, publication, participant):
        """Callback: nouvelle piste audio reçue"""
        logger.info(f"🎵 REAL HANDLER: Piste audio reçue de {participant.identity}")
        
        if track.kind == rtc.TrackKind.KIND_AUDIO:
            # Configurer le stream audio
            audio_stream = rtc.AudioStream(track)
            asyncio.create_task(self._process_audio_stream(audio_stream, participant))
    
    async def _process_audio_stream(self, audio_stream, participant):
        """Traitement du stream audio en temps réel"""
        logger.info(f"🎧 REAL HANDLER: Démarrage traitement audio de {participant.identity}")
        
        logger.debug(f"🎧 REAL HANDLER: Entrée dans la boucle de traitement audio. Niveau de log actuel: {logger.level}")
        async for audio_frame_event in audio_stream:
            try:
                self.audio_frames_received += 1
                logger.debug(f"🎧 REAL HANDLER: AudioFrameEvent reçu. Frame size: {len(audio_frame_event.frame.data)} bytes, SampleRate: {audio_frame_event.frame.sample_rate}, Channels: {audio_frame_event.frame.num_channels}")
                
                # Extraire les données audio
                audio_frame = audio_frame_event.frame
                audio_data = np.frombuffer(audio_frame.data, dtype=np.int16)
                
                logger.debug(f"🎧 REAL HANDLER: AudioData extraite: {len(audio_data)} samples. (samples_per_channel: {audio_frame.samples_per_channel}). Dtype: {audio_data.dtype}")
                
                # Ajouter au buffer
                self.audio_buffer.extend(audio_data)
                
                logger.debug(f"🎧 REAL HANDLER: Buffer audio après ajout: {len(self.audio_buffer)} échantillons.")
                
                # Traiter quand on a assez de données (1 seconde)
                logger.debug(f"🎧 REAL HANDLER: Vérification du buffer. Taille actuelle: {len(self.audio_buffer)} échantillons. Taille cible: {self.PROCESS_CHUNK_THRESHOLD} échantillons.")
                logger.debug(f"DEBUG: Buffer length: {len(self.audio_buffer)}, Process Threshold: {self.PROCESS_CHUNK_THRESHOLD}, Condition: {len(self.audio_buffer) >= self.PROCESS_CHUNK_THRESHOLD}")
                
                # Vérifier le niveau du logger juste avant la condition
                logger.debug(f"DEBUG: Niveau du logger avant condition: {logging.getLevelName(logger.level)}")
                
                if len(self.audio_buffer) >= self.PROCESS_CHUNK_THRESHOLD:
                    logger.debug(f"🔄 REAL HANDLER: Condition remplie. Buffer audio atteint {len(self.audio_buffer)} échantillons. Traitement du chunk...")
                    # Extraire le chunk à traiter et le supprimer du buffer
                    chunk_to_process = self.audio_buffer[:self.PROCESS_CHUNK_THRESHOLD]
                    self.audio_buffer = self.audio_buffer[self.PROCESS_CHUNK_THRESHOLD:]
                    
                    await self._process_audio_chunk(chunk_to_process)
                    logger.debug(f"✅ REAL HANDLER: _process_audio_chunk appelé. Buffer restant: {len(self.audio_buffer)} échantillons.")
                else:
                    logger.debug(f"⏳ REAL HANDLER: Condition non remplie. Buffer audio actuel: {len(self.audio_buffer)} échantillons. Attente de plus de données.")
                    
            except Exception as e:
                logger.error(f"❌ REAL HANDLER: Erreur traitement frame: {e}")
                self.errors_count += 1
    
    async def _process_audio_chunk(self, chunk_data_48khz: np.ndarray):
        """Traiter un chunk d'audio complet"""
        try:
            logger.debug(f"🔄 REAL HANDLER: Début du traitement du chunk audio.")
            # Le chunk_data_48khz est déjà passé en argument
            
            logger.debug(f"🔄 REAL HANDLER: Traitement chunk audio ({len(chunk_data_48khz)} échantillons, {len(chunk_data_48khz)/self.sample_rate:.2f}s) à 48kHz")
            
            # Rééchantillonner à 16kHz pour Whisper ASR
            # from pydub import AudioSegment # Already imported at the top
            # from pydub.playback import play # Commented out as it's not used and can cause issues
            # import io # Already imported at the top
            
            # Rééchantillonner directement avec scipy (48kHz -> 16kHz)
            audio_16khz = resample_audio_scipy(chunk_data_48khz, self.sample_rate, self.target_asr_sample_rate)
            
            # Sauvegarder temporairement en WAV pour ASR
            tmp_file_path = None
            try:
                with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as tmp_file:
                    tmp_file_path = tmp_file.name
                    create_wav_file_scipy(audio_16khz, self.target_asr_sample_rate, tmp_file_path)
                logger.debug(f"💾 REAL HANDLER: Fichier WAV temporaire 16kHz créé pour ASR: {tmp_file_path}")
                
                # Envoyer à Whisper ASR
                logger.debug(f"📤 REAL HANDLER: Appel de _send_to_whisper_asr avec fichier: {tmp_file_path}")
                transcription = await self._send_to_whisper_asr(tmp_file_path)
                
                if transcription and len(transcription.strip()) > 2:
                    logger.info(f"📝 REAL HANDLER: Transcription: '{transcription}'")
                    
                    # Générer réponse IA
                    ai_response = await self._generate_ai_response(transcription)
                    logger.info(f"🧠 REAL HANDLER: Réponse IA générée: '{ai_response[:50]}...'")
                    
                    # Convertir en audio avec Coqui TTS
                    await self._send_tts_response(ai_response)
                else:
                    logger.info(f"🚫 REAL HANDLER: Aucune transcription significative de l'ASR ou transcription trop courte: '{transcription}'")
                    
            finally:
                if tmp_file_path and os.path.exists(tmp_file_path):
                    os.unlink(tmp_file_path)
                    logger.debug(f"🗑️ REAL HANDLER: Fichier WAV temporaire ASR supprimé: {tmp_file_path}")
                
        except Exception as e:
            logger.error(f"❌ REAL HANDLER: Erreur traitement chunk: {e}")
            self.errors_count += 1
    
    async def _send_to_whisper_asr(self, audio_file_path: str) -> Optional[str]:
        """Envoyer l'audio à Whisper ASR"""
        try:
            async with httpx.AsyncClient() as client:
                file_size = os.path.getsize(audio_file_path)
                logger.debug(f"📤 REAL HANDLER: Envoi audio à ASR: {audio_file_path} (Taille: {file_size} octets)")
                
                # Vérifier si le fichier est vide
                if file_size == 0:
                    logger.warning("⚠️ REAL HANDLER: Le fichier audio envoyé à ASR est vide.")
                    return None

                with open(audio_file_path, 'rb') as audio_file:
                    logger.debug(f"📂 REAL HANDLER: Fichier audio ouvert pour ASR: {audio_file_path}")
                    files = {'file': ('audio.wav', audio_file, 'audio/wav')}
                    
                    # Log avant l'envoi de la requête
                    logger.debug(f"🚀 REAL HANDLER: Envoi de la requête HTTP POST à ASR service: http://127.0.0.1:8001/transcribe")
                    
                    response = await client.post(
                        "http://127.0.0.1:8001/transcribe", # Changé de asr-service à 127.0.0.1
                        files=files,
                        timeout=30.0 # Augmenter le timeout à 30 secondes
                    )
                
                # Log après la réception de la réponse
                logger.debug(f"📩 REAL HANDLER: Réponse ASR reçue. Statut: {response.status_code}, Texte: {response.text[:200]}...") # Log les 200 premiers caractères de la réponse

                if response.status_code == 200:
                    result = response.json()
                    transcription = result.get('text', '').strip()
                    logger.debug(f"✅ REAL HANDLER: Réponse ASR ({response.status_code}): '{transcription}' (Full response: {result})")
                    self.transcriptions_made += 1
                    return transcription
                else:
                    logger.warning(f"⚠️ REAL HANDLER: ASR erreur {response.status_code}, Réponse: {response.text}")
                    return None
                    
        except httpx.RequestError as e:
            logger.error(f"❌ REAL HANDLER: Erreur réseau ASR (connexion/timeout): {type(e).__name__}: {e}") # Log plus spécifique
            self.errors_count += 1
            return None
        except Exception as e:
            logger.error(f"❌ REAL HANDLER: Erreur ASR inattendue: {type(e).__name__}: {e}") # Log plus spécifique
            self.errors_count += 1
            return None
    
    async def _generate_ai_response(self, user_text: str) -> str:
        """Générer une réponse IA simple"""
        # Pour l'instant, réponse simple
        responses = [
            f"J'ai compris que vous dites: '{user_text}'. Pouvez-vous développer?",
            f"Intéressant! Vous mentionnez '{user_text}'. Que pensez-vous de cela?",
            f"Merci pour votre message: '{user_text}'. Continuons la discussion.",
            f"Votre point sur '{user_text}' est pertinent. Quelle est votre opinion?"
        ]
        
        import random
        return random.choice(responses)
    
    async def _send_tts_response(self, text: str):
        """Générer et envoyer la réponse TTS"""
        try:
            logger.info(f"🗣️ REAL HANDLER: Génération TTS: '{text[:50]}...'")
            
            # Appeler Coqui TTS
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "http://tts-service:5002/api/tts",
                    json={'text': text},
                    timeout=10.0
                )
                
                if response.status_code == 200:
                    # Lire l'audio WAV
                    audio_data = response.content
                    
                    # Convertir en format LiveKit
                    await self._send_audio_to_livekit(audio_data)
                    
                    self.tts_responses_sent += 1
                    logger.info(f"✅ REAL HANDLER: Réponse TTS envoyée ({len(audio_data)} octets)")
                else:
                    logger.warning(f"⚠️ REAL HANDLER: TTS erreur {response.status_code}")
                    
        except Exception as e:
            logger.error(f"❌ REAL HANDLER: Erreur TTS: {e}")
            self.errors_count += 1
    
    async def _send_audio_to_livekit(self, wav_data: bytes):
        """Envoyer l'audio WAV à LiveKit"""
        try:
            if not self.audio_source:
                logger.error("❌ REAL HANDLER: Source audio non initialisée")
                return
            
            # Lire le WAV
            import wave
            import io
            
            wav_buffer = io.BytesIO(wav_data)
            with wave.open(wav_buffer, 'rb') as wav_file:
                frames = wav_file.readframes(wav_file.getnframes())
                audio_array = np.frombuffer(frames, dtype=np.int16)
            
            # Vérifier le sample rate du TTS et rééchantillonner si nécessaire pour LiveKit (48kHz)
            # Supposons que TTS renvoie du 16kHz, rééchantillonner à 48kHz pour LiveKit
            # from pydub import AudioSegment # Already imported at the top
            # from pydub.playback import play # Commented out as it's not used and can cause problems on some systems
            
            wav_buffer = io.BytesIO(wav_data)
            audio_segment_tts = AudioSegmentScipy.from_wav(wav_buffer)
            
            # Si le TTS ne renvoie pas déjà du 48kHz, rééchantillonner
            if audio_segment_tts.frame_rate != self.sample_rate:
                logger.debug(f"🔄 REAL HANDLER: Rééchantillonnage TTS de {audio_segment_tts.frame_rate}Hz à {self.sample_rate}Hz pour LiveKit")
                audio_segment_tts = audio_segment_tts.set_frame_rate(self.sample_rate)
            
            # Convertir en numpy array float32 pour LiveKit
            audio_array_float = audio_segment_tts.get_array_of_samples().astype(np.float32) / 32768.0
            
            # Envoyer à LiveKit par chunks
            # chunk_size doit être basé sur le sample_rate de LiveKit (48kHz)
            chunk_size = int(self.sample_rate * 0.01)  # 10ms de données à 48kHz
            
            for i in range(0, len(audio_array_float), chunk_size):
                chunk = audio_array_float[i:i+chunk_size]
                if len(chunk) < chunk_size:
                    # Padding si nécessaire
                    chunk = np.pad(chunk, (0, chunk_size - len(chunk)))
                
                # Créer le frame audio
                audio_frame = rtc.AudioFrame.create(
                    sample_rate=self.sample_rate, # Utiliser le sample_rate de LiveKit (48kHz)
                    num_channels=1,
                    samples_per_channel=len(chunk)
                )
                audio_frame.data[:] = chunk.tobytes()
                
                # Envoyer à LiveKit
                await self.audio_source.capture_frame(audio_frame)
                
                # Petite pause pour respecter le timing
                await asyncio.sleep(0.01)  # 10ms
            
            logger.debug("🎵 REAL HANDLER: Audio envoyé à LiveKit")
            
        except Exception as e:
            logger.error(f"❌ REAL HANDLER: Erreur envoi audio: {e}")
            self.errors_count += 1
    
    def _on_data_received(self, data, participant):
        """Callback: message de données reçu"""
        try:
            message = data.decode('utf-8')
            logger.info(f"💬 REAL HANDLER: Message reçu de {participant.identity}: {message}")
            
            # Traiter le message texte
            asyncio.create_task(self._process_text_message(message))
            
        except Exception as e:
            logger.error(f"❌ REAL HANDLER: Erreur message données: {e}")
    
    async def _process_text_message(self, message: str):
        """Traiter un message texte"""
        try:
            # Générer réponse IA
            ai_response = await self._generate_ai_response(message)
            
            # Convertir en audio
            await self._send_tts_response(ai_response)
            
        except Exception as e:
            logger.error(f"❌ REAL HANDLER: Erreur traitement message: {e}")
    
    def get_diagnostic_report(self) -> Dict[str, Any]:
        """Rapport de diagnostic détaillé"""
        return {
            "timestamp": time.strftime('%Y-%m-%d %H:%M:%S'),
            "room_name": self.room_name,
            "connected": self.connected,
            "audio_frames_received": self.audio_frames_received,
            "transcriptions_made": self.transcriptions_made,
            "tts_responses_sent": self.tts_responses_sent,
            "errors_count": self.errors_count,
            "buffer_size": len(self.audio_buffer),
            "status": "ACTIVE" if self.connected else "INACTIVE"
        }
    
    async def disconnect(self):
        """Déconnexion propre"""
        try:
            if self.room:
                await self.room.disconnect()
            self.connected = False
            logger.info("🔌 REAL HANDLER: Déconnecté")
        except Exception as e:
            logger.error(f"❌ REAL HANDLER: Erreur déconnexion: {e}")