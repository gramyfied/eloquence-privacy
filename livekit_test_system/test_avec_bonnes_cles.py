#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test LiveKit avec les bonnes clés API du projet
"""

import asyncio
import sys
import os
from pathlib import Path

# Configuration de l'encodage pour Windows
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

async def test_livekit_avec_bonnes_cles():
    """Test avec les vraies clés du projet"""
    print("=" * 60)
    print("TEST LIVEKIT AVEC LES BONNES CLES")
    print("=" * 60)
    
    # Configuration avec les vraies clés
    config = {
        "livekit_url": "ws://localhost:7880",
        "api_key": "devkey",
        "api_secret": "devsecret123456789abcdef0123456789abcdef0123456789abcdef",
        "room_name": "test_coaching_vocal"
    }
    
    print(f"URL: {config['livekit_url']}")
    print(f"Room: {config['room_name']}")
    print(f"API Key: {config['api_key']}")
    print(f"API Secret: {config['api_secret'][:20]}...")
    print()
    
    try:
        from livekit import rtc, api
        
        # Créer un token avec les bonnes clés
        token_builder = api.AccessToken(config['api_key'], config['api_secret'])
        video_grants = api.VideoGrants(
            room_join=True,
            room=config['room_name'],
            can_publish=True,
            can_subscribe=True,
            can_publish_data=True
        )
        token = token_builder.with_identity("test_user_coaching") \
                            .with_name("Test User Coaching") \
                            .with_grants(video_grants) \
                            .to_jwt()
        
        print("SUCCES Token genere avec les bonnes cles")
        print(f"Token: {token[:50]}...")
        print()
        
        # Tenter la connexion
        room = rtc.Room()
        
        print("Tentative de connexion...")
        
        try:
            await asyncio.wait_for(
                room.connect(config['livekit_url'], token),
                timeout=15
            )
            
            print("SUCCES CONNEXION LIVEKIT REUSSIE!")
            print(f"Connecte a la room: {room.name}")
            print(f"Participant local: {room.local_participant.identity}")
            print()
            
            # Test d'envoi de données
            print("Test d'envoi de donnees...")
            test_data = b"Test de donnees audio pour coaching vocal"
            await room.local_participant.publish_data(test_data)
            print(f"SUCCES Donnees envoyees: {len(test_data)} bytes")
            print()
            
            # Attendre un peu
            print("Attente de 3 secondes...")
            await asyncio.sleep(3)
            
            # Déconnexion
            await room.disconnect()
            print("SUCCES Deconnexion reussie")
            print()
            
            print("=" * 60)
            print("TOUS LES TESTS SONT PASSES!")
            print("Le systeme LiveKit fonctionne parfaitement!")
            print("=" * 60)
            print()
            print("Vous pouvez maintenant utiliser:")
            print("  - python main.py --test basic")
            print("  - python run_tests.py")
            print("  - test_livekit.bat")
            
            return True
            
        except asyncio.TimeoutError:
            print("ERREUR Timeout de connexion (15s)")
            return False
        except Exception as e:
            print(f"ERREUR Erreur de connexion: {e}")
            return False
            
    except Exception as e:
        print(f"ERREUR Erreur lors du test: {e}")
        return False

def main():
    """Fonction principale"""
    try:
        success = asyncio.run(test_livekit_avec_bonnes_cles())
        return 0 if success else 1
    except KeyboardInterrupt:
        print("\nARRET Test interrompu")
        return 130
    except Exception as e:
        print(f"\nERREUR Erreur inattendue: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())