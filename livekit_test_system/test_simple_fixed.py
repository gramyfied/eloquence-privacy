#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test simple et autonome pour LiveKit
Version corrigée pour Windows sans emojis problématiques
"""

import asyncio
import time
import json
import sys
import os
from pathlib import Path

# Configuration de l'encodage pour Windows
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

def test_imports():
    """Teste si toutes les dépendances sont disponibles"""
    print("Verification des dependances...")
    
    missing_deps = []
    
    try:
        import colorama
        print("OK colorama: OK")
    except ImportError:
        missing_deps.append("colorama")
        print("ERREUR colorama: MANQUANT")
    
    try:
        import livekit
        print("OK livekit: OK")
    except ImportError:
        missing_deps.append("livekit-server-sdk-python")
        print("ERREUR livekit: MANQUANT")
    
    try:
        import pyttsx3
        print("OK pyttsx3: OK")
    except ImportError:
        missing_deps.append("pyttsx3")
        print("ERREUR pyttsx3: MANQUANT")
    
    if missing_deps:
        print(f"\nERREUR Dependances manquantes: {', '.join(missing_deps)}")
        print("\nPour les installer:")
        print(f"pip install {' '.join(missing_deps)}")
        return False
    
    print("\nSUCCES Toutes les dependances sont disponibles!")
    return True

def get_livekit_config():
    """Récupère la configuration LiveKit"""
    config = {
        "livekit_url": "ws://localhost:7880",
        "api_key": "devkey", 
        "api_secret": "secret",
        "room_name": "test_simple"
    }
    
    # Vérifier les variables d'environnement
    if os.getenv("LIVEKIT_URL"):
        config["livekit_url"] = os.getenv("LIVEKIT_URL")
    if os.getenv("LIVEKIT_API_KEY"):
        config["api_key"] = os.getenv("LIVEKIT_API_KEY")
    if os.getenv("LIVEKIT_API_SECRET"):
        config["api_secret"] = os.getenv("LIVEKIT_API_SECRET")
    
    # Essayer de charger depuis le projet
    try:
        sys.path.insert(0, str(Path(__file__).parent.parent))
        from temp_complete_repo.backend.eloquence_backend.core.config import settings
        
        if settings.LIVEKIT_HOST:
            livekit_url = settings.LIVEKIT_HOST
            if not livekit_url.startswith(('ws://', 'wss://')):
                livekit_url = f"ws://{livekit_url}"
            config["livekit_url"] = livekit_url
        
        if settings.LIVEKIT_API_KEY:
            config["api_key"] = settings.LIVEKIT_API_KEY
        if settings.LIVEKIT_API_SECRET:
            config["api_secret"] = settings.LIVEKIT_API_SECRET
            
        print("SUCCES Configuration chargee depuis le projet Eloquence")
    except:
        print("AVERTISSEMENT Configuration du projet non trouvee, utilisation des valeurs par defaut")
    
    return config

async def test_livekit_connection(config):
    """Test simple de connexion LiveKit"""
    print(f"\nTest de connexion LiveKit...")
    print(f"URL: {config['livekit_url']}")
    print(f"Room: {config['room_name']}")
    
    try:
        from livekit import rtc, api
        
        # Créer un token
        token_builder = api.AccessToken(config['api_key'], config['api_secret'])
        video_grants = api.VideoGrants(
            room_join=True,
            room=config['room_name'],
            can_publish=True,
            can_subscribe=True,
            can_publish_data=True
        )
        token = token_builder.with_identity("test_user") \
                            .with_name("Test User") \
                            .with_grants(video_grants) \
                            .to_jwt()
        
        print("SUCCES Token genere avec succes")
        
        # Tenter la connexion
        room = rtc.Room()
        
        connection_timeout = 10  # 10 secondes
        
        try:
            await asyncio.wait_for(
                room.connect(config['livekit_url'], token),
                timeout=connection_timeout
            )
            
            print("SUCCES Connexion LiveKit reussie!")
            
            # Attendre un peu puis se déconnecter
            await asyncio.sleep(2)
            await room.disconnect()
            
            print("SUCCES Deconnexion reussie")
            return True
            
        except asyncio.TimeoutError:
            print(f"ERREUR Timeout de connexion ({connection_timeout}s)")
            print("CONSEIL Verifiez que le serveur LiveKit est demarre")
            return False
        except Exception as e:
            print(f"ERREUR Erreur de connexion: {e}")
            return False
            
    except Exception as e:
        print(f"ERREUR Erreur lors du test: {e}")
        return False

def test_tts():
    """Test simple du TTS"""
    print(f"\nTest du generateur de voix...")
    
    try:
        import pyttsx3
        
        engine = pyttsx3.init()
        
        # Test de base
        voices = engine.getProperty('voices')
        if voices:
            print(f"SUCCES {len(voices)} voix disponibles")
        else:
            print("AVERTISSEMENT Aucune voix trouvee")
        
        # Test de génération
        temp_file = "test_audio.wav"
        engine.save_to_file("Ceci est un test de synthese vocale", temp_file)
        engine.runAndWait()
        
        if Path(temp_file).exists():
            size = Path(temp_file).stat().st_size
            print(f"SUCCES Fichier audio genere: {temp_file} ({size} bytes)")
            
            # Nettoyer
            Path(temp_file).unlink()
            return True
        else:
            print("ERREUR Echec de generation du fichier audio")
            return False
            
    except Exception as e:
        print(f"ERREUR TTS: {e}")
        return False

async def run_simple_test():
    """Lance un test simple complet"""
    print("=" * 60)
    print("TEST SIMPLE LIVEKIT - COACHING VOCAL")
    print("=" * 60)
    
    # 1. Test des imports
    if not test_imports():
        return False
    
    # 2. Test TTS
    if not test_tts():
        print("AVERTISSEMENT TTS non fonctionnel, mais on continue...")
    
    # 3. Configuration
    config = get_livekit_config()
    print(f"\nConfiguration:")
    print(f"  URL: {config['livekit_url']}")
    print(f"  Room: {config['room_name']}")
    print(f"  API Key: {'SUCCES Definie' if config['api_key'] != 'devkey' else 'AVERTISSEMENT Par defaut'}")
    
    # 4. Test de connexion
    connection_ok = await test_livekit_connection(config)
    
    if connection_ok:
        print("\nSUCCES TOUS LES TESTS SONT PASSES!")
        print("\nVous pouvez maintenant utiliser:")
        print("  - python main.py --test basic")
        print("  - python run_tests.py")
        print("  - test_livekit.bat")
        return True
    else:
        print("\nERREUR PROBLEME DE CONNEXION LIVEKIT")
        print("\nSolutions possibles:")
        print("1. Demarrer le serveur LiveKit:")
        print("   livekit-server --dev")
        print("\n2. Ou avec Docker:")
        print("   docker run --rm -p 7880:7880 -p 7881:7881 -p 7882:7882/udp livekit/livekit-server --dev")
        print("\n3. Verifier l'URL dans la configuration")
        print("4. Verifier les cles API")
        return False

def main():
    """Fonction principale"""
    try:
        success = asyncio.run(run_simple_test())
        return 0 if success else 1
    except KeyboardInterrupt:
        print("\nARRET Test interrompu")
        return 130
    except Exception as e:
        print(f"\nERREUR Erreur inattendue: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())