#!/usr/bin/env python3
"""
Test simple et autonome pour LiveKit
Version simplifiée sans dépendances complexes
"""

import asyncio
import time
import json
import sys
import os
from pathlib import Path

# Test des imports
def test_imports():
    """Teste si toutes les dépendances sont disponibles"""
    print("🔍 Vérification des dépendances...")
    
    missing_deps = []
    
    try:
        import colorama
        print("✅ colorama: OK")
    except ImportError:
        missing_deps.append("colorama")
        print("❌ colorama: MANQUANT")
    
    try:
        import livekit
        print("✅ livekit: OK")
    except ImportError:
        missing_deps.append("livekit-server-sdk-python")
        print("❌ livekit: MANQUANT")
    
    try:
        import pyttsx3
        print("✅ pyttsx3: OK")
    except ImportError:
        missing_deps.append("pyttsx3")
        print("❌ pyttsx3: MANQUANT")
    
    if missing_deps:
        print(f"\n❌ Dépendances manquantes: {', '.join(missing_deps)}")
        print("\n💡 Pour les installer:")
        print(f"pip install {' '.join(missing_deps)}")
        return False
    
    print("\n✅ Toutes les dépendances sont disponibles!")
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
            
        print("✅ Configuration chargée depuis le projet Eloquence")
    except:
        print("⚠️ Configuration du projet non trouvée, utilisation des valeurs par défaut")
    
    return config

async def test_livekit_connection(config):
    """Test simple de connexion LiveKit"""
    print(f"\n🔗 Test de connexion LiveKit...")
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
        
        print("✅ Token généré avec succès")
        
        # Tenter la connexion
        room = rtc.Room()
        
        connection_timeout = 10  # 10 secondes
        
        try:
            await asyncio.wait_for(
                room.connect(config['livekit_url'], token),
                timeout=connection_timeout
            )
            
            print("✅ Connexion LiveKit réussie!")
            
            # Attendre un peu puis se déconnecter
            await asyncio.sleep(2)
            await room.disconnect()
            
            print("✅ Déconnexion réussie")
            return True
            
        except asyncio.TimeoutError:
            print(f"❌ Timeout de connexion ({connection_timeout}s)")
            print("💡 Vérifiez que le serveur LiveKit est démarré")
            return False
        except Exception as e:
            print(f"❌ Erreur de connexion: {e}")
            return False
            
    except Exception as e:
        print(f"❌ Erreur lors du test: {e}")
        return False

def test_tts():
    """Test simple du TTS"""
    print(f"\n🎤 Test du générateur de voix...")
    
    try:
        import pyttsx3
        
        engine = pyttsx3.init()
        
        # Test de base
        voices = engine.getProperty('voices')
        if voices:
            print(f"✅ {len(voices)} voix disponibles")
        else:
            print("⚠️ Aucune voix trouvée")
        
        # Test de génération
        temp_file = "test_audio.wav"
        engine.save_to_file("Ceci est un test de synthèse vocale", temp_file)
        engine.runAndWait()
        
        if Path(temp_file).exists():
            size = Path(temp_file).stat().st_size
            print(f"✅ Fichier audio généré: {temp_file} ({size} bytes)")
            
            # Nettoyer
            Path(temp_file).unlink()
            return True
        else:
            print("❌ Échec de génération du fichier audio")
            return False
            
    except Exception as e:
        print(f"❌ Erreur TTS: {e}")
        return False

async def run_simple_test():
    """Lance un test simple complet"""
    print("=" * 60)
    print("🧪 TEST SIMPLE LIVEKIT - COACHING VOCAL")
    print("=" * 60)
    
    # 1. Test des imports
    if not test_imports():
        return False
    
    # 2. Test TTS
    if not test_tts():
        print("⚠️ TTS non fonctionnel, mais on continue...")
    
    # 3. Configuration
    config = get_livekit_config()
    print(f"\n📋 Configuration:")
    print(f"  URL: {config['livekit_url']}")
    print(f"  Room: {config['room_name']}")
    print(f"  API Key: {'✅ Définie' if config['api_key'] != 'devkey' else '⚠️ Par défaut'}")
    
    # 4. Test de connexion
    connection_ok = await test_livekit_connection(config)
    
    if connection_ok:
        print("\n🎉 TOUS LES TESTS SONT PASSÉS!")
        print("\n💡 Vous pouvez maintenant utiliser:")
        print("  - python main.py --test basic")
        print("  - python run_tests.py")
        print("  - test_livekit.bat")
        return True
    else:
        print("\n❌ PROBLÈME DE CONNEXION LIVEKIT")
        print("\n🔧 Solutions possibles:")
        print("1. Démarrer le serveur LiveKit:")
        print("   livekit-server --dev")
        print("\n2. Ou avec Docker:")
        print("   docker run --rm -p 7880:7880 -p 7881:7881 -p 7882:7882/udp livekit/livekit-server --dev")
        print("\n3. Vérifier l'URL dans la configuration")
        print("4. Vérifier les clés API")
        return False

def main():
    """Fonction principale"""
    try:
        success = asyncio.run(run_simple_test())
        return 0 if success else 1
    except KeyboardInterrupt:
        print("\n🛑 Test interrompu")
        return 130
    except Exception as e:
        print(f"\n💥 Erreur inattendue: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())