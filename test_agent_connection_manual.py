#!/usr/bin/env python3
"""
Script de test OBLIGATOIRE pour diagnostiquer la connexion agent LiveKit
"""

import asyncio
import logging
import jwt
import time
from datetime import datetime

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("AGENT_CONNECTION_TEST")

# Configuration LiveKit
LIVEKIT_API_KEY = "devkey"
LIVEKIT_API_SECRET = "devsecret123456789abcdef0123456789abcdef"
LIVEKIT_URL = "ws://192.168.1.44:7880"
ROOM_NAME = "session_demo-1_1750250905"  # Room créée par le test précédent
AGENT_IDENTITY = "ai_agent_test_manual"

def generate_agent_token(room_name: str, participant_identity: str) -> str:
    """Génère un token LiveKit pour l'agent"""
    now_timestamp = int(time.time())
    exp_timestamp = now_timestamp + (24 * 3600)  # +24 heures
    
    payload = {
        'iss': LIVEKIT_API_KEY,
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
    
    return jwt.encode(payload, LIVEKIT_API_SECRET, algorithm='HS256')

async def test_agent_connection():
    """Test OBLIGATOIRE de connexion agent"""
    logger.info("🔍 DÉBUT TEST CONNEXION AGENT MANUEL")
    
    try:
        # Vérifier si livekit est installé
        try:
            from livekit import rtc
            logger.info("✅ Module livekit importé avec succès")
        except ImportError as e:
            logger.error(f"❌ ERREUR: Module livekit non trouvé: {e}")
            logger.error("💡 SOLUTION: pip install livekit")
            return False
        
        # Générer token agent
        logger.info(f"🎫 Génération token pour agent: {AGENT_IDENTITY}")
        token = generate_agent_token(ROOM_NAME, AGENT_IDENTITY)
        logger.info(f"🎫 Token généré: {token[:50]}...")
        
        # Créer room et tenter connexion
        logger.info(f"🔄 Tentative connexion à: {LIVEKIT_URL}")
        logger.info(f"🏠 Room: {ROOM_NAME}")
        
        room = rtc.Room()
        
        # Setup listeners pour diagnostic
        @room.on("connected")
        def on_connected():
            logger.info("✅ AGENT CONNECTÉ AVEC SUCCÈS!")
        
        @room.on("disconnected")
        def on_disconnected(reason):
            logger.info(f"🔌 Agent déconnecté: {reason}")
        
        @room.on("participant_connected")
        def on_participant_connected(participant):
            logger.info(f"👤 Participant connecté: {participant.identity}")
        
        @room.on("participant_disconnected")
        def on_participant_disconnected(participant):
            logger.info(f"👤 Participant déconnecté: {participant.identity}")
        
        # Connexion avec timeout
        logger.info("⏳ Connexion en cours...")
        await asyncio.wait_for(
            room.connect(LIVEKIT_URL, token),
            timeout=30.0
        )
        
        logger.info("✅ CONNEXION RÉUSSIE!")
        
        # Vérifier l'état de la room
        logger.info(f"🏠 Room connectée: {room.name}")
        logger.info(f"🔗 État connexion: {room.connection_state}")
        logger.info(f"👥 Participant local: {room.local_participant.identity if room.local_participant else 'None'}")
        logger.info(f"👥 Participants distants: {len(room.remote_participants)}")
        
        # Lister les participants
        if room.remote_participants:
            for participant in room.remote_participants.values():
                logger.info(f"  - Participant distant: {participant.identity}")
        else:
            logger.warning("⚠️ AUCUN PARTICIPANT DISTANT TROUVÉ")
        
        # Attendre un peu pour observer
        logger.info("⏳ Maintien connexion pendant 10 secondes...")
        await asyncio.sleep(10)
        
        # Déconnexion propre
        await room.disconnect()
        logger.info("🔌 Déconnexion propre effectuée")
        
        return True
        
    except asyncio.TimeoutError:
        logger.error("❌ TIMEOUT: Connexion agent impossible (30s)")
        return False
    except Exception as e:
        logger.error(f"❌ ERREUR CONNEXION AGENT: {e}")
        logger.error(f"❌ Type erreur: {type(e).__name__}")
        return False

async def main():
    """Fonction principale"""
    logger.info("🚀 DÉMARRAGE TEST AGENT LIVEKIT")
    logger.info(f"📊 Configuration:")
    logger.info(f"  - URL LiveKit: {LIVEKIT_URL}")
    logger.info(f"  - Room: {ROOM_NAME}")
    logger.info(f"  - Agent Identity: {AGENT_IDENTITY}")
    logger.info(f"  - API Key: {LIVEKIT_API_KEY}")
    logger.info(f"  - Timestamp: {datetime.now()}")
    
    success = await test_agent_connection()
    
    if success:
        logger.info("✅ TEST RÉUSSI: Agent peut se connecter à LiveKit")
        return 0
    else:
        logger.error("❌ TEST ÉCHOUÉ: Agent ne peut pas se connecter")
        return 1

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    exit(exit_code)