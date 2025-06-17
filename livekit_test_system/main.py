#!/usr/bin/env python3
"""
Système de test LiveKit pour le coaching vocal interactif
Script principal pour lancer les tests de streaming audio
"""

import asyncio
import argparse
import signal
import sys
import json
from pathlib import Path
from typing import Dict, Any, Optional
import os

from pipeline_logger import PipelineLogger, metrics_collector
from test_orchestrator import LiveKitTestOrchestrator

# Configuration par défaut
DEFAULT_CONFIG = {
    "livekit_url": "ws://localhost:7880",
    "api_key": "devkey",
    "api_secret": "secret",
    "room_name": "test_coaching_vocal",
    "temp_dir": "./temp_audio_test"
}

class LiveKitTestRunner:
    """
    Runner principal pour les tests LiveKit
    Gère l'exécution des différents scénarios de test
    """
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = PipelineLogger("TEST_RUNNER")
        self.orchestrator: Optional[LiveKitTestOrchestrator] = None
        self.shutdown_requested = False
        
        # Configurer la gestion des signaux
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
        self.logger.info("🎯 Test Runner LiveKit initialisé")
    
    def _signal_handler(self, signum, frame):
        """Gestionnaire pour l'arrêt propre"""
        self.logger.warning(f"🛑 Signal reçu: {signum}")
        self.shutdown_requested = True
        
        if self.orchestrator:
            self.orchestrator.stop_test()
    
    async def run_all_tests(self) -> Dict[str, Any]:
        """
        Exécute tous les tests disponibles
        
        Returns:
            Résultats consolidés de tous les tests
        """
        self.logger.info("🚀 Démarrage de la suite complète de tests")
        
        all_results = {
            'test_suite': 'complete',
            'start_time': asyncio.get_event_loop().time(),
            'tests': {},
            'summary': {}
        }
        
        try:
            # Initialiser l'orchestrateur
            self.orchestrator = LiveKitTestOrchestrator(self.config)
            await self.orchestrator.initialize_components()
            
            # Connecter les clients
            connected = await self.orchestrator.connect_clients()
            if not connected:
                self.logger.error("❌ Impossible de connecter les clients")
                return all_results
            
            # Test 1: Test de base
            if not self.shutdown_requested:
                self.logger.info("\n" + "="*50)
                self.logger.info("🧪 TEST 1: Test de base")
                self.logger.info("="*50)
                
                try:
                    result = await self.orchestrator.run_basic_test(duration_seconds=30)
                    all_results['tests']['basic_test'] = result
                    self.logger.success("✅ Test de base terminé")
                except Exception as e:
                    self.logger.error(f"💥 Échec test de base: {e}")
                    all_results['tests']['basic_test'] = {'error': str(e)}
            
            # Pause entre les tests
            if not self.shutdown_requested:
                self.logger.info("⏳ Pause de 5 secondes entre les tests...")
                await asyncio.sleep(5)
            
            # Test 2: Test de stress
            if not self.shutdown_requested:
                self.logger.info("\n" + "="*50)
                self.logger.info("🔥 TEST 2: Test de stress")
                self.logger.info("="*50)
                
                try:
                    result = await self.orchestrator.run_stress_test(
                        packets_count=30,
                        interval_ms=800
                    )
                    all_results['tests']['stress_test'] = result
                    self.logger.success("✅ Test de stress terminé")
                except Exception as e:
                    self.logger.error(f"💥 Échec test de stress: {e}")
                    all_results['tests']['stress_test'] = {'error': str(e)}
            
            # Pause entre les tests
            if not self.shutdown_requested:
                self.logger.info("⏳ Pause de 5 secondes entre les tests...")
                await asyncio.sleep(5)
            
            # Test 3: Test de latence
            if not self.shutdown_requested:
                self.logger.info("\n" + "="*50)
                self.logger.info("⚡ TEST 3: Test de latence")
                self.logger.info("="*50)
                
                try:
                    result = await self.orchestrator.run_latency_test(quick_packets=15)
                    all_results['tests']['latency_test'] = result
                    self.logger.success("✅ Test de latence terminé")
                except Exception as e:
                    self.logger.error(f"💥 Échec test de latence: {e}")
                    all_results['tests']['latency_test'] = {'error': str(e)}
            
            # Compiler le résumé
            all_results['summary'] = self._compile_summary(all_results['tests'])
            all_results['end_time'] = asyncio.get_event_loop().time()
            all_results['total_duration'] = all_results['end_time'] - all_results['start_time']
            
            return all_results
            
        except Exception as e:
            self.logger.error(f"💥 Erreur fatale dans la suite de tests: {e}")
            all_results['fatal_error'] = str(e)
            return all_results
        
        finally:
            # Nettoyage
            if self.orchestrator:
                await self.orchestrator.disconnect_all()
                self.orchestrator.print_final_summary()
    
    async def run_single_test(self, test_name: str, **kwargs) -> Dict[str, Any]:
        """
        Exécute un test spécifique
        
        Args:
            test_name: Nom du test ('basic', 'stress', 'latency')
            **kwargs: Paramètres spécifiques au test
        
        Returns:
            Résultats du test
        """
        self.logger.info(f"🎯 Exécution du test: {test_name}")
        
        try:
            # Initialiser l'orchestrateur
            self.orchestrator = LiveKitTestOrchestrator(self.config)
            await self.orchestrator.initialize_components()
            
            # Connecter les clients
            connected = await self.orchestrator.connect_clients()
            if not connected:
                self.logger.error("❌ Impossible de connecter les clients")
                return {'error': 'connection_failed'}
            
            # Exécuter le test demandé
            if test_name == 'basic':
                duration = kwargs.get('duration', 30)
                result = await self.orchestrator.run_basic_test(duration_seconds=duration)
            
            elif test_name == 'stress':
                packets = kwargs.get('packets', 50)
                interval = kwargs.get('interval', 500)
                result = await self.orchestrator.run_stress_test(
                    packets_count=packets,
                    interval_ms=interval
                )
            
            elif test_name == 'latency':
                packets = kwargs.get('packets', 20)
                result = await self.orchestrator.run_latency_test(quick_packets=packets)
            
            else:
                self.logger.error(f"❌ Test inconnu: {test_name}")
                return {'error': f'unknown_test: {test_name}'}
            
            self.logger.success(f"✅ Test {test_name} terminé avec succès")
            return result
            
        except Exception as e:
            self.logger.error(f"💥 Erreur dans le test {test_name}: {e}")
            return {'error': str(e)}
        
        finally:
            # Nettoyage
            if self.orchestrator:
                await self.orchestrator.disconnect_all()
                self.orchestrator.print_final_summary()
    
    def _compile_summary(self, test_results: Dict[str, Any]) -> Dict[str, Any]:
        """Compile un résumé des résultats de tests"""
        summary = {
            'tests_executed': len(test_results),
            'tests_successful': 0,
            'tests_failed': 0,
            'total_packets_sent': 0,
            'total_packets_received': 0,
            'overall_packet_loss': 0.0,
            'average_latency_ms': 0.0,
            'total_errors': 0
        }
        
        latency_measurements = []
        
        for test_name, result in test_results.items():
            if 'error' in result:
                summary['tests_failed'] += 1
                continue
            
            summary['tests_successful'] += 1
            summary['total_packets_sent'] += result.get('packets_sent', 0)
            summary['total_packets_received'] += result.get('packets_received', 0)
            summary['total_errors'] += result.get('errors_count', 0)
            
            # Collecter les mesures de latence
            latency_stats = result.get('latency_stats', {})
            if 'avg_ms' in latency_stats:
                latency_measurements.append(latency_stats['avg_ms'])
        
        # Calculer les moyennes globales
        if summary['total_packets_sent'] > 0:
            summary['overall_packet_loss'] = max(0, 
                (summary['total_packets_sent'] - summary['total_packets_received']) / 
                summary['total_packets_sent']
            )
        
        if latency_measurements:
            summary['average_latency_ms'] = sum(latency_measurements) / len(latency_measurements)
        
        return summary
    
    def save_results(self, results: Dict[str, Any], output_file: Optional[str] = None):
        """Sauvegarde les résultats dans un fichier JSON"""
        if not output_file:
            timestamp = int(asyncio.get_event_loop().time())
            output_file = f"livekit_test_results_{timestamp}.json"
        
        output_path = Path(output_file)
        
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(results, f, indent=2, ensure_ascii=False)
            
            self.logger.success(f"📄 Résultats sauvegardés: {output_path}")
            
        except Exception as e:
            self.logger.error(f"💥 Erreur sauvegarde: {e}")


def load_config(config_file: Optional[str] = None) -> Dict[str, Any]:
    """Charge la configuration depuis un fichier ou utilise les valeurs par défaut"""
    config = DEFAULT_CONFIG.copy()
    
    # Charger depuis un fichier si spécifié
    if config_file and Path(config_file).exists():
        try:
            with open(config_file, 'r') as f:
                file_config = json.load(f)
                config.update(file_config)
            print(f"✅ Configuration chargée depuis: {config_file}")
        except Exception as e:
            print(f"⚠️ Erreur chargement config: {e}, utilisation des valeurs par défaut")
    
    # Surcharger avec les variables d'environnement
    env_mappings = {
        'LIVEKIT_URL': 'livekit_url',
        'LIVEKIT_API_KEY': 'api_key',
        'LIVEKIT_API_SECRET': 'api_secret',
        'LIVEKIT_ROOM': 'room_name'
    }
    
    for env_var, config_key in env_mappings.items():
        if os.getenv(env_var):
            config[config_key] = os.getenv(env_var)
    
    return config


async def main():
    """Fonction principale"""
    parser = argparse.ArgumentParser(
        description="Système de test LiveKit pour coaching vocal",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples d'utilisation:
  python main.py --all                    # Exécute tous les tests
  python main.py --test basic --duration 60  # Test de base de 60s
  python main.py --test stress --packets 100  # Test de stress avec 100 paquets
  python main.py --test latency --packets 30  # Test de latence avec 30 paquets
  python main.py --config my_config.json     # Utilise une config personnalisée
        """
    )
    
    parser.add_argument('--config', '-c', 
                       help='Fichier de configuration JSON')
    parser.add_argument('--all', action='store_true',
                       help='Exécuter tous les tests')
    parser.add_argument('--test', choices=['basic', 'stress', 'latency'],
                       help='Exécuter un test spécifique')
    parser.add_argument('--duration', type=int, default=30,
                       help='Durée du test de base en secondes')
    parser.add_argument('--packets', type=int, default=50,
                       help='Nombre de paquets pour les tests stress/latence')
    parser.add_argument('--interval', type=int, default=500,
                       help='Intervalle en ms pour le test de stress')
    parser.add_argument('--output', '-o',
                       help='Fichier de sortie pour les résultats JSON')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Mode verbeux')
    
    args = parser.parse_args()
    
    # Charger la configuration
    config = load_config(args.config)
    
    # Créer le répertoire temporaire
    temp_dir = Path(config['temp_dir'])
    temp_dir.mkdir(exist_ok=True)
    
    # Afficher la configuration
    print("\n" + "="*60)
    print("🎭 SYSTÈME DE TEST LIVEKIT - COACHING VOCAL")
    print("="*60)
    print(f"🌐 LiveKit URL: {config['livekit_url']}")
    print(f"🏠 Room: {config['room_name']}")
    print(f"📁 Répertoire temp: {config['temp_dir']}")
    print("="*60 + "\n")
    
    # Créer le runner
    runner = LiveKitTestRunner(config)
    
    try:
        # Exécuter les tests selon les arguments
        if args.all:
            results = await runner.run_all_tests()
        elif args.test:
            test_kwargs = {}
            if args.test == 'basic':
                test_kwargs['duration'] = args.duration
            elif args.test == 'stress':
                test_kwargs['packets'] = args.packets
                test_kwargs['interval'] = args.interval
            elif args.test == 'latency':
                test_kwargs['packets'] = args.packets
            
            results = await runner.run_single_test(args.test, **test_kwargs)
        else:
            print("❌ Veuillez spécifier --all ou --test <nom_test>")
            parser.print_help()
            return 1
        
        # Sauvegarder les résultats
        if args.output or args.all:
            runner.save_results(results, args.output)
        
        # Afficher un résumé final
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
        
        return 0
        
    except KeyboardInterrupt:
        print("\n🛑 Test interrompu par l'utilisateur")
        return 130
    except Exception as e:
        print(f"\n💥 Erreur fatale: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))