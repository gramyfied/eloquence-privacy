#!/usr/bin/env python3
"""
Script de lancement rapide pour les tests LiveKit
Utilise la configuration existante du projet
"""

import asyncio
import sys
import os
from pathlib import Path

# Ajouter le répertoire parent au path pour importer les modules du projet
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    from temp_complete_repo.backend.eloquence_backend.core.config import settings
    CONFIG_AVAILABLE = True
except ImportError:
    CONFIG_AVAILABLE = False
    print("⚠️ Configuration du projet non trouvée, utilisation des valeurs par défaut")

from main import LiveKitTestRunner

def get_project_config():
    """Récupère la configuration depuis le projet existant"""
    if CONFIG_AVAILABLE and settings.LIVEKIT_HOST:
        # Construire l'URL LiveKit
        livekit_url = settings.LIVEKIT_HOST
        if not livekit_url.startswith(('ws://', 'wss://')):
            livekit_url = f"ws://{livekit_url}"
        
        config = {
            "livekit_url": livekit_url,
            "api_key": settings.LIVEKIT_API_KEY or "devkey",
            "api_secret": settings.LIVEKIT_API_SECRET or "secret",
            "room_name": "test_coaching_vocal_eloquence",
            "temp_dir": "./temp_audio_test"
        }
        
        print("✅ Configuration chargée depuis le projet Eloquence")
        print(f"🌐 LiveKit URL: {config['livekit_url']}")
        print(f"🔑 API Key: {'✅ Définie' if config['api_key'] != 'devkey' else '⚠️ Par défaut'}")
        print(f"🔐 API Secret: {'✅ Définie' if config['api_secret'] != 'secret' else '⚠️ Par défaut'}")
        
        return config
    else:
        # Configuration par défaut
        config = {
            "livekit_url": "ws://localhost:7880",
            "api_key": "devkey",
            "api_secret": "secret",
            "room_name": "test_coaching_vocal",
            "temp_dir": "./temp_audio_test"
        }
        
        print("⚠️ Utilisation de la configuration par défaut")
        print("💡 Pour utiliser votre configuration, assurez-vous que les variables LIVEKIT_* sont définies")
        
        return config

async def run_quick_test():
    """Lance un test rapide pour vérifier le fonctionnement"""
    print("\n" + "="*60)
    print("🚀 TEST RAPIDE LIVEKIT - COACHING VOCAL")
    print("="*60)
    
    config = get_project_config()
    
    # Créer le répertoire temporaire
    temp_dir = Path(config['temp_dir'])
    temp_dir.mkdir(exist_ok=True)
    
    runner = LiveKitTestRunner(config)
    
    try:
        print("\n🧪 Exécution d'un test de base de 20 secondes...")
        result = await runner.run_single_test('basic', duration=20)
        
        if 'error' in result:
            print(f"\n❌ Test échoué: {result['error']}")
            return False
        else:
            print(f"\n✅ Test réussi!")
            print(f"📤 Paquets envoyés: {result.get('packets_sent', 0)}")
            print(f"📥 Paquets reçus: {result.get('packets_received', 0)}")
            
            latency_stats = result.get('latency_stats', {})
            if latency_stats:
                print(f"⚡ Latence moyenne: {latency_stats.get('avg_ms', 0):.2f}ms")
                print(f"⚡ Latence min/max: {latency_stats.get('min_ms', 0):.2f}/{latency_stats.get('max_ms', 0):.2f}ms")
            
            packet_loss = result.get('packet_loss_rate', 0)
            print(f"📉 Taux de perte: {packet_loss:.2%}")
            
            if result.get('errors_count', 0) > 0:
                print(f"⚠️ Erreurs rencontrées: {result['errors_count']}")
            
            return True
            
    except KeyboardInterrupt:
        print("\n🛑 Test interrompu par l'utilisateur")
        return False
    except Exception as e:
        print(f"\n💥 Erreur: {e}")
        return False

async def run_full_suite():
    """Lance la suite complète de tests"""
    print("\n" + "="*60)
    print("🎭 SUITE COMPLÈTE DE TESTS LIVEKIT")
    print("="*60)
    
    config = get_project_config()
    
    # Créer le répertoire temporaire
    temp_dir = Path(config['temp_dir'])
    temp_dir.mkdir(exist_ok=True)
    
    runner = LiveKitTestRunner(config)
    
    try:
        print("\n🚀 Lancement de tous les tests...")
        results = await runner.run_all_tests()
        
        # Sauvegarder les résultats
        runner.save_results(results, "livekit_test_results_complete.json")
        
        # Afficher le résumé
        if 'summary' in results:
            summary = results['summary']
            print(f"\n📊 RÉSUMÉ FINAL:")
            print(f"  ✅ Tests réussis: {summary['tests_successful']}")
            print(f"  ❌ Tests échoués: {summary['tests_failed']}")
            print(f"  📤 Paquets envoyés: {summary['total_packets_sent']}")
            print(f"  📥 Paquets reçus: {summary['total_packets_received']}")
            print(f"  📉 Taux de perte: {summary['overall_packet_loss']:.2%}")
            print(f"  ⚡ Latence moyenne: {summary['average_latency_ms']:.2f}ms")
            print(f"  ❌ Erreurs totales: {summary['total_errors']}")
            
            return summary['tests_failed'] == 0
        
        return False
        
    except KeyboardInterrupt:
        print("\n🛑 Tests interrompus par l'utilisateur")
        return False
    except Exception as e:
        print(f"\n💥 Erreur: {e}")
        return False

def main():
    """Fonction principale avec menu interactif"""
    print("🎯 SYSTÈME DE TEST LIVEKIT - COACHING VOCAL")
    print("=" * 50)
    print("1. Test rapide (20 secondes)")
    print("2. Suite complète de tests")
    print("3. Quitter")
    print("=" * 50)
    
    while True:
        try:
            choice = input("\nChoisissez une option (1-3): ").strip()
            
            if choice == '1':
                success = asyncio.run(run_quick_test())
                if success:
                    print("\n🎉 Test rapide terminé avec succès!")
                else:
                    print("\n❌ Test rapide échoué")
                break
                
            elif choice == '2':
                success = asyncio.run(run_full_suite())
                if success:
                    print("\n🎉 Suite complète terminée avec succès!")
                else:
                    print("\n❌ Certains tests ont échoué")
                break
                
            elif choice == '3':
                print("👋 Au revoir!")
                break
                
            else:
                print("❌ Option invalide, veuillez choisir 1, 2 ou 3")
                
        except KeyboardInterrupt:
            print("\n👋 Au revoir!")
            break
        except EOFError:
            print("\n👋 Au revoir!")
            break

if __name__ == "__main__":
    main()