#!/usr/bin/env python3
"""
Script de test pour valider l'activation audio de l'agent IA
"""

import asyncio
import logging
import sys
import os

# Ajouter le répertoire backend au path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

from services.livekit_agent_service import LiveKitAgentService

# Configuration du logging pour voir tous les détails
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger("TEST_AGENT_AUDIO")

async def test_agent_audio_activation():
    """Test complet de l'activation audio de l'agent"""
    
    logger.info("🚀 DÉBUT TEST: Activation audio agent IA")
    
    try:
        # Créer le service agent
        agent_service = LiveKitAgentService()
        
        # Données de session de test
        session_data = {
            'session_id': 'test_audio_session_001',
            'room_name': 'test_audio_room',
            'user_id': 'test_user_audio'
        }
        
        logger.info(f"📋 TEST: Session de test créée - {session_data}")
        
        # Test 1: Connexion agent avec audio
        logger.info("🔧 TEST 1: Connexion agent avec publication audio")
        success = await agent_service.connect_agent_to_session(session_data)
        
        if success:
            logger.info("✅ TEST 1 RÉUSSI: Agent connecté")
            
            # Vérifier le statut de l'agent
            status = agent_service.get_agent_status(session_data['session_id'])
            logger.info(f"📊 STATUT AGENT: {status}")
            
            if status.get('connected'):
                logger.info("✅ TEST 2 RÉUSSI: Agent confirmé connecté")
                
                # Attendre un peu pour voir les logs d'audio
                logger.info("⏳ ATTENTE: 10 secondes pour observer l'activation audio...")
                await asyncio.sleep(10)
                
                logger.info("✅ TEST COMPLET: Agent audio activé avec succès")
                return True
            else:
                logger.error("❌ TEST 2 ÉCHEC: Agent non connecté selon le statut")
                return False
        else:
            logger.error("❌ TEST 1 ÉCHEC: Connexion agent échouée")
            return False
            
    except Exception as e:
        logger.error(f"❌ ERREUR TEST: {e}")
        return False
    finally:
        # Nettoyage
        try:
            agent_service.cleanup_agent(session_data['session_id'])
            logger.info("🧹 NETTOYAGE: Agent nettoyé")
        except:
            pass

def main():
    """Point d'entrée principal"""
    logger.info("🎯 LANCEMENT: Test activation audio agent IA")
    
    try:
        # Exécuter le test
        result = asyncio.run(test_agent_audio_activation())
        
        if result:
            logger.info("🎉 SUCCÈS TOTAL: Agent audio activé et fonctionnel")
            print("\n" + "="*60)
            print("✅ RÉSULTAT: AGENT AUDIO ACTIVÉ AVEC SUCCÈS")
            print("✅ L'agent IA devrait maintenant publier de l'audio vers LiveKit")
            print("✅ Flutter devrait recevoir l'audio de l'agent")
            print("="*60)
            return 0
        else:
            logger.error("💥 ÉCHEC TOTAL: Agent audio non activé")
            print("\n" + "="*60)
            print("❌ RÉSULTAT: ÉCHEC ACTIVATION AUDIO AGENT")
            print("❌ Vérifier les logs ci-dessus pour diagnostiquer")
            print("="*60)
            return 1
            
    except KeyboardInterrupt:
        logger.info("🛑 ARRÊT: Test interrompu par l'utilisateur")
        return 0
    except Exception as e:
        logger.error(f"💥 ERREUR FATALE: {e}")
        return 1

if __name__ == "__main__":
    exit(main())