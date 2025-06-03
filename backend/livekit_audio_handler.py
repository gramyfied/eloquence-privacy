import asyncio
import logging
import json
import time
from typing import Dict, Any, Optional
from livekit import api
import httpx

# Configuration du logging pour le diagnostic
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("LIVEKIT_AUDIO_HANDLER")

class LiveKitAudioHandler:
    """
    Handler simplifié pour diagnostiquer l'intégration audio LiveKit
    Utilise uniquement l'API LiveKit pour les tests de base
    """
    
    def __init__(self, room_name: str, api_key: str, api_secret: str, livekit_url: str):
        self.room_name = room_name
        self.api_key = api_key
        self.api_secret = api_secret
        self.livekit_url = livekit_url
        self.connected = False
        
        # Compteurs de diagnostic
        self.audio_frames_received = 0
        self.data_messages_received = 0
        self.asr_requests_sent = 0
        self.tts_responses_sent = 0
        self.errors_count = 0
        
        logger.info(f"[DIAGNOSTIC] LiveKitAudioHandler initialisé pour room: {room_name}")
    
    async def connect_to_room(self) -> bool:
        """
        Simule la connexion à la room LiveKit (version simplifiée)
        """
        try:
            logger.info(f"[DIAGNOSTIC] Tentative de connexion à LiveKit...")
            logger.info(f"   - URL: {self.livekit_url}")
            logger.info(f"   - Room: {self.room_name}")
            logger.info(f"   - API Key: {self.api_key[:10]}...")
            
            # Créer le token pour le backend agent
            token = api.AccessToken(self.api_key, self.api_secret) \
                .with_identity("backend-agent") \
                .with_name("Backend AI Agent") \
                .with_grants(api.VideoGrants(
                    room_join=True,
                    room=self.room_name,
                    can_publish=True,
                    can_subscribe=True,
                    can_publish_data=True
                ))
            
            # Vérifier que le token est valide
            jwt_token = token.to_jwt()
            if jwt_token:
                self.connected = True
                logger.info("[OK] DIAGNOSTIC: Token LiveKit généré avec succès")
                
                # Simuler la réception d'audio pour les tests
                await self._simulate_audio_processing()
                return True
            else:
                logger.error("[FAIL] DIAGNOSTIC: Échec génération token LiveKit")
                return False
            
        except Exception as e:
            logger.error(f"[FAIL] DIAGNOSTIC: Erreur connexion LiveKit: {e}")
            self.errors_count += 1
            return False
    
    async def _simulate_audio_processing(self):
        """
        Simule le traitement audio pour les tests de diagnostic
        """
        logger.info("[DIAGNOSTIC] Simulation du traitement audio...")
        
        # Simuler la réception de quelques frames audio
        for i in range(5):
            self.audio_frames_received += 1
            await self._send_to_asr_simulation()
            await asyncio.sleep(0.1)
        
        # Simuler la réception d'un message de données
        await self._simulate_data_message("Test message from user")
    
    async def _send_to_asr_simulation(self):
        """
        DIAGNOSTIC: Simuler l'envoi à l'ASR
        """
        try:
            logger.debug(f"[DIAGNOSTIC] Simulation envoi ASR (frame #{self.audio_frames_received})")
            
            # Test de connectivité ASR
            async with httpx.AsyncClient() as client:
                response = await client.get("http://asr-service:8001/health", timeout=1.0)
                if response.status_code == 200:
                    self.asr_requests_sent += 1
                    logger.debug(f"[OK] DIAGNOSTIC: ASR accessible ({self.asr_requests_sent} requêtes)")
                else:
                    logger.warning(f"[WARN] DIAGNOSTIC: ASR répond avec status {response.status_code}")
                    
        except httpx.ConnectTimeout:
            logger.error("[FAIL] DIAGNOSTIC: Timeout connexion ASR")
            self.errors_count += 1
        except httpx.ConnectError:
            logger.error("[FAIL] DIAGNOSTIC: Impossible de se connecter à l'ASR")
            self.errors_count += 1
        except Exception as e:
            logger.error(f"[FAIL] DIAGNOSTIC: Erreur ASR inattendue: {e}")
            self.errors_count += 1
    
    async def _simulate_data_message(self, message: str):
        """
        Simule la réception d'un message de données
        """
        self.data_messages_received += 1
        logger.info(f"[DIAGNOSTIC] Simulation message reçu: {message}")
        
        # Simuler une réponse IA
        response = f"IA: J'ai reçu votre message '{message[:50]}...' à {time.strftime('%H:%M:%S')}"
        await self._send_tts_response(response)
    
    async def _send_tts_response(self, text: str):
        """
        DIAGNOSTIC: Tenter d'envoyer une réponse TTS
        """
        try:
            logger.info(f"[DIAGNOSTIC] Simulation envoi TTS: '{text[:50]}...'")
            
            # Test de connectivité TTS
            async with httpx.AsyncClient() as client:
                response = await client.get("http://tts-service:5002/health", timeout=1.0)
                if response.status_code == 200:
                    self.tts_responses_sent += 1
                    logger.info(f"[OK] DIAGNOSTIC: TTS accessible ({self.tts_responses_sent} réponses)")
                else:
                    logger.warning(f"[WARN] DIAGNOSTIC: TTS répond avec status {response.status_code}")
                    
        except httpx.ConnectTimeout:
            logger.error("[FAIL] DIAGNOSTIC: Timeout connexion TTS")
            self.errors_count += 1
        except httpx.ConnectError:
            logger.error("[FAIL] DIAGNOSTIC: Impossible de se connecter au TTS")
            self.errors_count += 1
        except Exception as e:
            logger.error(f"[FAIL] DIAGNOSTIC: Erreur TTS inattendue: {e}")
            self.errors_count += 1
    
    def get_diagnostic_report(self) -> Dict[str, Any]:
        """
        Génère un rapport de diagnostic
        """
        return {
            "timestamp": time.strftime('%Y-%m-%d %H:%M:%S'),
            "room_name": self.room_name,
            "audio_frames_received": self.audio_frames_received,
            "data_messages_received": self.data_messages_received,
            "asr_requests_sent": self.asr_requests_sent,
            "tts_responses_sent": self.tts_responses_sent,
            "errors_count": self.errors_count,
            "status": "CONNECTED" if self.connected else "DISCONNECTED"
        }
    
    async def disconnect(self):
        """
        Déconnecte le handler
        """
        self.connected = False
        logger.info("[DIAGNOSTIC] Handler déconnecté")