"""
Service Agent LiveKit intégré pour connexion automatique
Basé sur la documentation LiveKit Agents officielle
"""

import asyncio
import logging
import os
import threading
import time
import jwt
import requests
import tempfile
import numpy as np
import signal
from typing import Dict, Optional, AsyncGenerator
from datetime import datetime

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("LIVEKIT_AGENT_SERVICE")

class EventLoopManager:
    """Gestionnaire de boucles d'événements persistantes pour LiveKit"""
    
    def __init__(self):
        self.loop = None
        self.running = True
        self.agents = {}
        
    async def setup_persistent_loop(self):
        """Configure une boucle d'événements persistante"""
        try:
            # Obtenir ou créer la boucle d'événements
            try:
                self.loop = asyncio.get_running_loop()
                logger.info("✅ BOUCLE: Utilisation de la boucle existante")
            except RuntimeError:
                self.loop = asyncio.new_event_loop()
                asyncio.set_event_loop(self.loop)
                logger.info("✅ BOUCLE: Nouvelle boucle créée")
            
            # Configurer les signaux pour maintenir la boucle active (Windows compatible)
            try:
                if hasattr(signal, 'SIGTERM'):
                    self.loop.add_signal_handler(signal.SIGTERM, self.shutdown)
                if hasattr(signal, 'SIGINT'):
                    self.loop.add_signal_handler(signal.SIGINT, self.shutdown)
                logger.info("✅ BOUCLE: Gestionnaires de signaux configurés")
            except (NotImplementedError, OSError):
                # Windows ne supporte pas add_signal_handler
                logger.info("⚠️ BOUCLE: Gestionnaires de signaux non supportés (Windows)")
                
            logger.info("✅ BOUCLE: Boucle d'événements persistante configurée")
            return self.loop
            
        except Exception as e:
            logger.error(f"❌ BOUCLE: Échec configuration: {e}")
            raise Exception(f"ÉCHEC CONFIGURATION BOUCLE: {e}")
            
    def shutdown(self):
        """Arrêt propre de la boucle"""
        logger.info("🛑 BOUCLE: Arrêt propre demandé")
        self.running = False
        
    async def keep_alive(self):
        """Maintient la boucle d'événements active"""
        logger.info("🔄 BOUCLE: Maintien de la boucle active")
        while self.running:
            await asyncio.sleep(1)
            
    def register_agent(self, session_id: str, agent):
        """Enregistre un agent dans le gestionnaire"""
        self.agents[session_id] = agent
        logger.info(f"📝 BOUCLE: Agent {session_id} enregistré")
        
    def unregister_agent(self, session_id: str):
        """Désenregistre un agent"""
        if session_id in self.agents:
            del self.agents[session_id]
            logger.info(f"🗑️ BOUCLE: Agent {session_id} désenregistré")

# Instance globale du gestionnaire de boucles
loop_manager = EventLoopManager()

class RealTimeStreamingTTS:
    """Service TTS streaming temps réel avec Tom français"""
    
    def __init__(self):
        # CORRECTION: Utiliser localhost au lieu du nom Docker interne
        self.tts_service_url = "http://localhost:5002/api/tts"
        self.sample_rate = 22050
        self.chunk_size = 1024
        
    async def stream_generate_audio(self, text: str) -> AsyncGenerator[bytes, None]:
        """Génère l'audio en streaming temps réel"""
        try:
            logger.info(f"🎯 STREAMING TTS: Génération pour '{text[:50]}...'")
            
            # Segmentation du texte pour streaming
            sentences = self._split_text_for_streaming(text)
            
            for sentence in sentences:
                if sentence.strip():
                    # Génération audio par phrase
                    audio_data = await self._generate_audio_chunk(sentence)
                    
                    if audio_data:
                        # Découpage en chunks pour streaming
                        for chunk in self._split_audio_chunks(audio_data):
                            yield chunk
                            # Délai minimal pour streaming fluide
                            await asyncio.sleep(0.01)
                            
        except Exception as e:
            logger.error(f"❌ ÉCHEC STREAMING TTS: {e}")
            # Générer un chunk de silence en cas d'erreur
            yield self._generate_silence_chunk()
            
    def _split_text_for_streaming(self, text: str) -> list:
        """Découpe le texte en phrases pour streaming"""
        import re
        # Découpage par phrases avec ponctuation
        sentences = re.split(r'[.!?]+', text)
        return [s.strip() for s in sentences if s.strip()]
        
    async def _generate_audio_chunk(self, sentence: str) -> bytes:
        """Génère un chunk audio pour une phrase"""
        try:
            # Appel au service TTS existant
            payload = {
                "text": sentence,
                "voice": "tom-fr-high"  # Voix Tom français
            }
            
            # CORRECTION: Utiliser la boucle persistante du gestionnaire
            if loop_manager.loop and not loop_manager.loop.is_closed():
                loop = loop_manager.loop
                logger.info("✅ TTS: Utilisation de la boucle persistante")
            else:
                try:
                    loop = asyncio.get_running_loop()
                    logger.info("✅ TTS: Utilisation de la boucle courante")
                except RuntimeError:
                    logger.error("❌ TTS: Aucune boucle disponible")
                    return self._generate_silence_chunk()
            
            response = await loop.run_in_executor(
                None,
                lambda: requests.post(
                    self.tts_service_url,
                    json=payload,
                    timeout=10
                )
            )
            
            if response.status_code == 200:
                logger.info(f"✅ CHUNK TTS généré: {len(response.content)} bytes")
                return response.content
            else:
                logger.error(f"❌ Erreur TTS service: {response.status_code}")
                return self._generate_silence_chunk()
                
        except Exception as e:
            logger.error(f"❌ Erreur génération chunk: {e}")
            return self._generate_silence_chunk()
        
    def _split_audio_chunks(self, audio_data: bytes) -> list:
        """Découpe l'audio en chunks pour streaming"""
        chunks = []
        for i in range(0, len(audio_data), self.chunk_size):
            chunk = audio_data[i:i + self.chunk_size]
            chunks.append(chunk)
        return chunks
        
    def _generate_silence_chunk(self) -> bytes:
        """Génère un chunk de silence en cas d'erreur"""
        try:
            # Générer 0.1 seconde de silence
            duration = 0.1
            samples = int(self.sample_rate * duration)
            silence = np.zeros(samples, dtype=np.int16)
            return silence.tobytes()
        except:
            return b'\x00' * 1024  # Silence basique

class LiveKitAgentService:
    """Service pour gérer les agents LiveKit automatiquement"""
    
    def __init__(self):
        self.api_key = os.getenv('LIVEKIT_API_KEY', 'devkey')
        self.api_secret = os.getenv('LIVEKIT_API_SECRET', 'devsecret123456789abcdef0123456789abcdef')
        # CORRECTION: Utiliser l'URL externe pour les agents aussi
        self.livekit_url = 'ws://192.168.1.44:7880'  # URL externe fixe
        self.active_agents: Dict[str, 'SimpleAgent'] = {}
        self.agent_lock = threading.Lock()
        logger.info(f"Service Agent initialisé - URL: {self.livekit_url}")
    
    def generate_agent_token(self, room_name: str, participant_identity: str) -> str:
        """Génère un token LiveKit pour l'agent"""
        now_timestamp = int(time.time())
        exp_timestamp = now_timestamp + (24 * 3600)  # +24 heures
        
        payload = {
            'iss': self.api_key,
            'sub': participant_identity,
            'iat': now_timestamp,
            'exp': exp_timestamp,
            'nbf': now_timestamp,
            'video': {
                'room': room_name,
                'roomJoin': True,
                'roomList': True,
                'roomRecord': False,
                'roomAdmin': False,
                'roomCreate': False,
                'canPublish': True,
                'canSubscribe': True,
                'canPublishData': True,
                'canUpdateOwnMetadata': True
            }
        }
        
        return jwt.encode(payload, self.api_secret, algorithm='HS256')
    
    async def connect_agent_to_session(self, session_data: dict) -> bool:
        """Connecte un agent automatiquement à une session"""
        session_id = session_data['session_id']
        room_name = session_data['room_name']
        agent_identity = f"ai_agent_{session_id}"
        
        logger.info(f"🤖 CONNEXION AGENT: session={session_id}, room={room_name}")
        
        try:
            # Vérifier si agent déjà connecté
            with self.agent_lock:
                if session_id in self.active_agents:
                    existing_agent = self.active_agents[session_id]
                    if existing_agent.is_connected:
                        logger.info(f"✅ Agent déjà connecté pour session {session_id}")
                        return True
                    else:
                        # Agent déconnecté, le supprimer
                        del self.active_agents[session_id]
            
            # Créer nouvel agent
            agent = SimpleAgent(
                session_id=session_id,
                room_name=room_name,
                participant_identity=agent_identity,
                api_key=self.api_key,
                api_secret=self.api_secret,
                livekit_url=self.livekit_url
            )
            
            # Connecter agent
            success = await agent.connect()
            
            if success:
                with self.agent_lock:
                    self.active_agents[session_id] = agent
                logger.info(f"✅ AGENT CONNECTÉ: {agent_identity} dans {room_name}")
                return True
            else:
                logger.error(f"❌ ÉCHEC CONNEXION AGENT: {session_id}")
                return False
                
        except Exception as e:
            logger.error(f"❌ ERREUR SERVICE AGENT: {e}")
            return False
    
    def start_agent_for_session(self, session_data: dict) -> bool:
        """Lance un agent avec boucle d'événements persistante"""
        try:
            session_id = session_data['session_id']
            logger.info(f"🔄 BOUCLE: Démarrage agent pour session {session_id}")
            
            # Créer un thread dédié pour l'agent avec boucle persistante
            def run_agent_with_persistent_loop():
                try:
                    # Créer une nouvelle boucle pour ce thread
                    loop = asyncio.new_event_loop()
                    asyncio.set_event_loop(loop)
                    
                    # Enregistrer la boucle dans le gestionnaire
                    loop_manager.loop = loop
                    
                    logger.info(f"✅ BOUCLE: Boucle persistante créée pour agent {session_id}")
                    
                    # Exécuter la connexion agent
                    result = loop.run_until_complete(self.connect_agent_to_session(session_data))
                    
                    if result:
                        logger.info(f"✅ BOUCLE: Agent {session_id} connecté, maintien de la boucle active")
                        
                        # CRITIQUE: Maintenir la boucle active indéfiniment
                        loop.run_until_complete(self._keep_agent_alive(session_id))
                    else:
                        logger.error(f"❌ BOUCLE: Échec connexion agent {session_id}")
                        
                except Exception as e:
                    logger.error(f"❌ BOUCLE: Erreur thread agent {session_id}: {e}")
                finally:
                    # Nettoyer seulement en cas d'erreur ou arrêt explicite
                    if loop and not loop.is_closed():
                        logger.info(f"🧹 BOUCLE: Nettoyage boucle pour agent {session_id}")
                        loop.close()
            
            # Lancer l'agent dans un thread séparé
            agent_thread = threading.Thread(
                target=run_agent_with_persistent_loop,
                name=f"agent_thread_{session_id}",
                daemon=True
            )
            agent_thread.start()
            
            # Attendre un peu pour vérifier que l'agent démarre
            time.sleep(2)
            
            logger.info(f"✅ BOUCLE: Thread agent {session_id} démarré")
            return True
            
        except Exception as e:
            logger.error(f"❌ ERREUR LANCEMENT AGENT: {e}")
            return False
    
    async def _keep_agent_alive(self, session_id: str):
        """Maintient l'agent actif avec sa boucle d'événements"""
        logger.info(f"🔄 BOUCLE: Maintien agent {session_id} actif")
        
        try:
            # Boucle infinie pour maintenir l'agent actif
            while True:
                # Vérifier si l'agent est toujours dans le registre
                with self.agent_lock:
                    if session_id not in self.active_agents:
                        logger.info(f"🛑 BOUCLE: Agent {session_id} retiré du registre, arrêt")
                        break
                        
                    agent = self.active_agents[session_id]
                    if not agent.is_connected:
                        logger.warning(f"⚠️ BOUCLE: Agent {session_id} déconnecté, arrêt")
                        break
                
                # Attendre avant la prochaine vérification
                await asyncio.sleep(5)
                
        except Exception as e:
            logger.error(f"❌ BOUCLE: Erreur maintien agent {session_id}: {e}")
        finally:
            logger.info(f"🏁 BOUCLE: Fin maintien agent {session_id}")
    
    def cleanup_agent(self, session_id: str):
        """Nettoie un agent à la fin de session"""
        try:
            with self.agent_lock:
                if session_id in self.active_agents:
                    agent = self.active_agents[session_id]
                    # Note: Dans un vrai système, on ferait agent.disconnect()
                    del self.active_agents[session_id]
                    logger.info(f"🧹 Agent nettoyé pour session {session_id}")
        except Exception as e:
            logger.error(f"❌ Erreur nettoyage agent: {e}")
    
    def get_active_agents_count(self) -> int:
        """Retourne le nombre d'agents actifs"""
        with self.agent_lock:
            return len(self.active_agents)
    
    def get_agent_status(self, session_id: str) -> dict:
        """Retourne le statut d'un agent"""
        with self.agent_lock:
            if session_id in self.active_agents:
                agent = self.active_agents[session_id]
                return {
                    'connected': agent.is_connected,
                    'identity': agent.participant_identity,
                    'room': agent.room_name,
                    'connected_at': agent.connected_at
                }
            else:
                return {'connected': False}

class SimpleAgent:
    """Agent LiveKit simple pour coaching vocal avec TTS streaming"""
    
    def __init__(self, session_id: str, room_name: str, participant_identity: str,
                 api_key: str, api_secret: str, livekit_url: str):
        self.session_id = session_id
        self.room_name = room_name
        self.participant_identity = participant_identity
        self.api_key = api_key
        self.api_secret = api_secret
        self.livekit_url = livekit_url
        self.room = None
        self.is_connected = False
        self.connected_at = None
        # NOUVEAU: Service TTS streaming intégré
        self.tts_service = RealTimeStreamingTTS()
        self.audio_source = None
        self.audio_track = None
        
    async def connect(self) -> bool:
        """Connecte l'agent à LiveKit"""
        try:
            # Importer livekit seulement quand nécessaire
            from livekit import rtc
            
            # Générer token
            token = self._generate_token()
            
            # Créer room et connecter
            self.room = rtc.Room()
            
            # Setup listeners - VERSION SIMPLIFIÉE SANS ASYNC
            @self.room.on("connected")
            def on_connected():
                self.is_connected = True
                self.connected_at = datetime.now()
                logger.info(f"🎯 Agent {self.participant_identity} connecté à {self.room_name}")
                logger.info("✅ AGENT: Connexion réussie - Agent prêt pour audio")
                
                # CRITIQUE : Déclencher l'initialisation audio après connexion
                logger.info("🔧 DIAGNOSTIC: Déclenchement initialisation audio post-connexion")
                asyncio.create_task(self._post_connection_setup())
            
            @self.room.on("disconnected")
            def on_disconnected(reason):
                self.is_connected = False
                logger.info(f"🔌 Agent {self.participant_identity} déconnecté: {reason}")
            
            @self.room.on("participant_connected")
            def on_participant_connected(participant):
                logger.info(f"👤 Participant connecté: {participant.identity}")
                logger.info("🎯 AGENT: Participant détecté - Prêt pour interaction vocale")
                
            @self.room.on("track_received")
            def on_track_received(track, publication, participant):
                logger.info(f"🎵 Track reçu de {participant.identity}: {track.kind}")
                if track.kind == "audio":
                    logger.info("🎙️ AUDIO: Track audio reçu - Traitement vocal activé")
            
            # Connexion avec timeout
            await asyncio.wait_for(
                self.room.connect(self.livekit_url, token),
                timeout=30.0
            )
            
            # CORRECTION CRITIQUE : Forcer l'initialisation audio même si l'événement connected n'est pas déclenché
            logger.info("🔧 DIAGNOSTIC: Connexion terminée, vérification du statut")
            
            # Attendre un peu pour que la connexion se stabilise
            await asyncio.sleep(2)
            
            # Vérifier si l'agent est vraiment connecté
            if self.room and self.room.connection_state == "connected":
                self.is_connected = True
                self.connected_at = datetime.now()
                logger.info("✅ DIAGNOSTIC: Connexion confirmée, déclenchement manuel de l'audio")
                
                # Déclencher manuellement l'initialisation audio
                await self._post_connection_setup()
            else:
                logger.warning("⚠️ DIAGNOSTIC: Connexion incertaine, tentative d'initialisation audio quand même")
                self.is_connected = True
                self.connected_at = datetime.now()
                
                # Tenter l'initialisation audio quand même
                await self._post_connection_setup()
            
            return True
            
        except ImportError:
            logger.error("❌ Module livekit non trouvé. Installer avec: pip install livekit")
            return False
        except asyncio.TimeoutError:
            logger.error(f"❌ TIMEOUT connexion agent {self.participant_identity}")
            return False
        except Exception as e:
            logger.error(f"❌ ERREUR connexion agent {self.participant_identity}: {e}")
            return False
    
    def _generate_token(self) -> str:
        """Génère le token pour cet agent"""
        now_timestamp = int(time.time())
        exp_timestamp = now_timestamp + (24 * 3600)
        
        payload = {
            'iss': self.api_key,
            'sub': self.participant_identity,
            'iat': now_timestamp,
            'exp': exp_timestamp,
            'nbf': now_timestamp,
            'video': {
                'room': self.room_name,
                'roomJoin': True,
                'roomList': True,
                'roomRecord': False,
                'roomAdmin': False,
                'roomCreate': False,
                'canPublish': True,
                'canSubscribe': True,
                'canPublishData': True,
                'canUpdateOwnMetadata': True
            }
        }
        
        return jwt.encode(payload, self.api_secret, algorithm='HS256')
    
    async def _post_connection_setup(self):
        """Configuration post-connexion avec publication audio immédiate"""
        try:
            logger.info("🚀 POST-CONNEXION: Démarrage configuration audio")
            
            # Attendre un peu pour s'assurer que la connexion est stable
            await asyncio.sleep(1)
            
            # ÉTAPE 1 : Initialiser le streaming audio
            await self._initialize_audio_streaming()
            
            # ÉTAPE 2 : Envoyer le message de bienvenue
            await self._send_welcome_message()
            
            logger.info("✅ POST-CONNEXION: Configuration audio terminée avec succès")
            
        except Exception as e:
            logger.error(f"❌ ÉCHEC POST-CONNEXION: {e}")
    
    async def _initialize_audio_streaming(self):
        """Initialise la source audio pour streaming continu"""
        try:
            from livekit import rtc
            
            logger.info("🔧 INIT AUDIO: Création de la source audio")
            
            # Créer source audio LiveKit
            self.audio_source = rtc.AudioSource(
                sample_rate=22050,
                num_channels=1
            )
            
            # Créer track audio persistant
            self.audio_track = rtc.LocalAudioTrack.create_audio_track(
                "ai_voice_stream",
                self.audio_source
            )
            
            logger.info("🔧 INIT AUDIO: Publication du track audio vers LiveKit")
            
            # Publier vers LiveKit - CORRECTION: Supprimer le champ "name" non supporté
            await self.room.local_participant.publish_track(
                self.audio_track,
                rtc.TrackPublishOptions(
                    source=rtc.TrackSource.SOURCE_MICROPHONE
                )
            )
            
            logger.info("✅ STREAMING AUDIO: Source audio initialisée et track publié")
            
        except Exception as e:
            logger.error(f"❌ ÉCHEC INIT STREAMING AUDIO: {e}")
            raise
    
    async def _send_welcome_message(self):
        """Envoie un message de bienvenue en streaming"""
        try:
            logger.info("🎵 BIENVENUE: Préparation du message de bienvenue TTS")
            welcome_text = "Bonjour ! Je suis Tom, votre assistant vocal français. Comment puis-je vous aider aujourd'hui ?"
            
            # Vérifier que la source audio est prête
            if not self.audio_source:
                logger.error("❌ BIENVENUE: Source audio non initialisée")
                return
                
            logger.info("🎵 BIENVENUE: Démarrage streaming TTS")
            await self._stream_text_to_audio(welcome_text)
            logger.info("✅ BIENVENUE: Message de bienvenue envoyé avec succès")
            
        except Exception as e:
            logger.error(f"❌ ÉCHEC MESSAGE BIENVENUE: {e}")
            raise
    
    async def _stream_text_to_audio(self, text: str):
        """Stream texte vers audio en temps réel"""
        try:
            if not self.audio_source:
                logger.error("❌ STREAMING: Source audio non initialisée")
                return
                
            logger.info(f"🎯 STREAMING AUDIO: Début streaming pour '{text[:50]}...'")
            
            chunk_count = 0
            # Streaming audio chunk par chunk
            async for audio_chunk in self.tts_service.stream_generate_audio(text):
                chunk_count += 1
                logger.info(f"🔊 STREAMING: Envoi chunk #{chunk_count} ({len(audio_chunk)} bytes)")
                await self._send_audio_chunk(audio_chunk)
                
            logger.info(f"✅ STREAMING TERMINÉ: {chunk_count} chunks envoyés pour '{text[:30]}...'")
            
        except Exception as e:
            logger.error(f"❌ ÉCHEC STREAMING TEXTE: {e}")
            raise
    
    async def _send_audio_chunk(self, audio_chunk: bytes):
        """Envoie un chunk audio vers LiveKit"""
        try:
            from livekit import rtc
            
            if not self.audio_source:
                logger.error("❌ CHUNK: Source audio non disponible")
                return
                
            # Validation du chunk
            if not audio_chunk or len(audio_chunk) == 0:
                logger.warning("⚠️ CHUNK: Chunk audio vide, ignoré")
                return
                
            samples_per_channel = len(audio_chunk) // 2  # 16-bit audio
            logger.debug(f"🔊 CHUNK: Envoi {len(audio_chunk)} bytes ({samples_per_channel} samples)")
            
            # Conversion en AudioFrame
            audio_frame = rtc.AudioFrame(
                data=audio_chunk,
                sample_rate=22050,
                num_channels=1,
                samples_per_channel=samples_per_channel
            )
            
            # Envoi immédiat vers LiveKit
            await self.audio_source.capture_frame(audio_frame)
            logger.debug("✅ CHUNK: Chunk envoyé avec succès")
            
        except Exception as e:
            logger.error(f"❌ ERREUR CHUNK: {e}")
            raise

# Instance globale du service agent
agent_service = LiveKitAgentService()