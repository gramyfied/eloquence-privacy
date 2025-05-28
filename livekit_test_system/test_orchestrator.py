import asyncio
import time
import random
import signal
import sys
from typing import Dict, Any, List, Optional
from pathlib import Path
import json

from pipeline_logger import PipelineLogger, metrics_collector
from voice_synthesizer import VoiceSynthesizer
from livekit_client import LiveKitTestClient

class LiveKitTestOrchestrator:
    """
    Orchestrateur principal pour les tests LiveKit
    Coordonne la génération de voix, l'envoi et la réception
    """
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialise l'orchestrateur avec la configuration
        
        Args:
            config: Configuration contenant les paramètres LiveKit et de test
        """
        self.config = config
        self.logger = PipelineLogger("ORCHESTRATOR")
        metrics_collector.register_logger(self.logger)
        
        # Composants
        self.voice_synthesizer: Optional[VoiceSynthesizer] = None
        self.sender_client: Optional[LiveKitTestClient] = None
        self.receiver_client: Optional[LiveKitTestClient] = None
        
        # État du test
        self.test_running = False
        self.test_start_time = None
        self.test_results = []
        self.current_test_name = None
        
        # Statistiques globales
        self.total_packets_sent = 0
        self.total_packets_received = 0
        self.total_latency_measurements = []
        self.errors_encountered = []
        
        self.logger.info("🎭 Orchestrateur de tests LiveKit initialisé")
        self._log_configuration()
    
    def _log_configuration(self):
        """Affiche la configuration de test"""
        self.logger.info("📋 Configuration de test:")
        self.logger.info(f"  🌐 LiveKit URL: {self.config.get('livekit_url', 'Non défini')}")
        self.logger.info(f"  🔑 API Key: {'✅ Définie' if self.config.get('api_key') else '❌ Manquante'}")
        self.logger.info(f"  🔐 API Secret: {'✅ Définie' if self.config.get('api_secret') else '❌ Manquante'}")
        self.logger.info(f"  🏠 Room: {self.config.get('room_name', 'test_room')}")
    
    async def initialize_components(self):
        """Initialise tous les composants nécessaires"""
        self.logger.info("🚀 Initialisation des composants...")
        
        try:
            # Initialiser le générateur de voix
            self.voice_synthesizer = VoiceSynthesizer(
                temp_dir=self.config.get('temp_dir')
            )
            self.logger.success("✅ Générateur de voix initialisé")
            
            # Initialiser le client émetteur
            self.sender_client = LiveKitTestClient(
                livekit_url=self.config['livekit_url'],
                api_key=self.config['api_key'],
                api_secret=self.config['api_secret'],
                client_type="sender"
            )
            
            # Configurer les callbacks du sender
            self.sender_client.on_participant_connected = self._on_sender_participant_connected
            self.sender_client.on_participant_disconnected = self._on_sender_participant_disconnected
            
            self.logger.success("✅ Client émetteur initialisé")
            
            # Initialiser le client récepteur
            self.receiver_client = LiveKitTestClient(
                livekit_url=self.config['livekit_url'],
                api_key=self.config['api_key'],
                api_secret=self.config['api_secret'],
                client_type="receiver"
            )
            
            # Configurer les callbacks du receiver
            self.receiver_client.on_data_received = self._on_data_received
            self.receiver_client.on_audio_received = self._on_audio_received
            self.receiver_client.on_participant_connected = self._on_receiver_participant_connected
            
            self.logger.success("✅ Client récepteur initialisé")
            
            self.logger.success("🎉 Tous les composants initialisés avec succès")
            
        except Exception as e:
            self.logger.error(f"💥 Erreur lors de l'initialisation: {e}")
            raise
    
    async def connect_clients(self, room_name: Optional[str] = None) -> bool:
        """
        Connecte les clients à la room LiveKit
        
        Args:
            room_name: Nom de la room (utilise la config par défaut si None)
        
        Returns:
            True si toutes les connexions réussissent
        """
        room_name = room_name or self.config.get('room_name', 'test_room')
        
        self.logger.info(f"🔗 Connexion à la room: {room_name}")
        
        try:
            # Connecter le récepteur en premier
            receiver_connected = await self.receiver_client.connect(
                room_name, 
                "AI_Coach_Receiver"
            )
            
            if not receiver_connected:
                self.logger.error("❌ Échec connexion du récepteur")
                return False
            
            # Attendre un peu pour que le récepteur soit prêt
            await asyncio.sleep(1)
            
            # Connecter l'émetteur
            sender_connected = await self.sender_client.connect(
                room_name,
                "Voice_Sender"
            )
            
            if not sender_connected:
                self.logger.error("❌ Échec connexion de l'émetteur")
                await self.receiver_client.disconnect()
                return False
            
            # Attendre que les participants se découvrent
            await asyncio.sleep(2)
            
            self.logger.success("🎉 Tous les clients connectés avec succès")
            return True
            
        except Exception as e:
            self.logger.error(f"💥 Erreur lors de la connexion: {e}")
            return False
    
    async def _on_sender_participant_connected(self, participant):
        """Callback quand un participant se connecte côté émetteur"""
        self.logger.info(f"👋 Émetteur voit: {participant.identity}")
    
    async def _on_sender_participant_disconnected(self, participant):
        """Callback quand un participant se déconnecte côté émetteur"""
        self.logger.info(f"👋 Émetteur perd: {participant.identity}")
    
    async def _on_receiver_participant_connected(self, participant):
        """Callback quand un participant se connecte côté récepteur"""
        self.logger.info(f"👋 Récepteur voit: {participant.identity}")
    
    async def _on_data_received(self, data_packet):
        """Callback pour les données reçues"""
        receive_time = time.time()
        
        try:
            # Décoder le paquet
            data = data_packet.data
            participant = data_packet.participant
            
            # Lire l'en-tête
            header_size = int.from_bytes(data[:4], byteorder='big')
            header_data = data[4:4+header_size]
            audio_data = data[4+header_size:]
            
            import json
            packet_info = json.loads(header_data.decode('utf-8'))
            
            # Calculer la latence
            send_time = packet_info.get('timestamp', receive_time)
            latency_ms = (receive_time - send_time) * 1000
            
            self.total_packets_received += 1
            self.total_latency_measurements.append(latency_ms)
            
            self.logger.info(f"📥 Paquet reçu #{packet_info.get('packet_id', '?')}")
            self.logger.latency("bout_en_bout", latency_ms)
            
            # Analyser la qualité
            self._analyze_packet_quality(packet_info, latency_ms, len(audio_data))
            
            # Simuler le traitement IA
            await self._simulate_ai_processing(packet_info, audio_data)
            
        except Exception as e:
            self.logger.error(f"💥 Erreur traitement paquet reçu: {e}")
            self.errors_encountered.append({
                'type': 'packet_processing_error',
                'error': str(e),
                'timestamp': receive_time
            })
    
    async def _on_audio_received(self, audio_data, participant_identity, audio_frame):
        """Callback pour l'audio reçu"""
        self.logger.debug(f"🎧 Audio reçu de {participant_identity}: {len(audio_data)} bytes")
        
        # Simuler l'analyse audio
        await self._simulate_audio_analysis(audio_data, audio_frame)
    
    def _analyze_packet_quality(self, packet_info: Dict, latency_ms: float, data_size: int):
        """Analyse la qualité d'un paquet reçu"""
        # Évaluer la latence
        if latency_ms < 100:
            quality = "excellente"
            color_code = "🟢"
        elif latency_ms < 300:
            quality = "bonne"
            color_code = "🟡"
        elif latency_ms < 500:
            quality = "acceptable"
            color_code = "🟠"
        else:
            quality = "problématique"
            color_code = "🔴"
        
        self.logger.performance_metric(
            f"qualité_paquet_{color_code}",
            latency_ms,
            f"ms ({quality})"
        )
        
        # Vérifier la taille des données
        expected_size = packet_info.get('size', 0)
        if data_size != expected_size:
            self.logger.warning(f"⚠️ Taille inattendue: {data_size} vs {expected_size} attendus")
    
    async def _simulate_ai_processing(self, packet_info: Dict, audio_data: bytes):
        """Simule le traitement IA du coaching vocal"""
        processing_start = time.time()
        
        # Simuler différents types de traitement selon le contenu
        text = packet_info.get('metadata', {}).get('text', '')
        
        if 'test' in text.lower():
            # Traitement rapide pour les tests
            await asyncio.sleep(random.uniform(0.05, 0.15))
            response_type = "technique"
        elif 'bonjour' in text.lower() or 'salut' in text.lower():
            # Traitement de salutation
            await asyncio.sleep(random.uniform(0.1, 0.3))
            response_type = "accueil"
        else:
            # Traitement normal
            await asyncio.sleep(random.uniform(0.2, 0.5))
            response_type = "coaching"
        
        processing_time = (time.time() - processing_start) * 1000
        
        self.logger.latency(f"traitement_ia_{response_type}", processing_time)
        self.logger.debug(f"🤖 IA traitement: {response_type} en {processing_time:.1f}ms")
    
    async def _simulate_audio_analysis(self, audio_data: bytes, audio_frame):
        """Simule l'analyse audio (VAD, qualité, etc.)"""
        analysis_start = time.time()
        
        # Simuler l'analyse VAD
        await asyncio.sleep(random.uniform(0.01, 0.05))
        
        # Simuler la détection de qualité
        sample_rate = audio_frame.sample_rate if audio_frame else 16000
        quality_score = random.uniform(0.7, 0.95)
        
        analysis_time = (time.time() - analysis_start) * 1000
        
        self.logger.latency("analyse_audio", analysis_time)
        self.logger.performance_metric("qualité_audio", quality_score * 100, "%")
    
    async def run_basic_test(self, duration_seconds: int = 30) -> Dict[str, Any]:
        """
        Exécute un test de base
        
        Args:
            duration_seconds: Durée du test en secondes
        
        Returns:
            Résultats du test
        """
        self.current_test_name = "basic_test"
        self.logger.info(f"🧪 Démarrage test de base ({duration_seconds}s)")
        
        test_start = time.time()
        self.test_start_time = test_start
        self.test_running = True
        
        try:
            # Générer et envoyer des phrases à intervalles réguliers
            end_time = test_start + duration_seconds
            
            async for audio_metadata in self.voice_synthesizer.generate_continuous_stream(
                interval_range=(2.0, 4.0),
                categories=['greeting', 'coaching']
            ):
                if time.time() >= end_time:
                    break
                
                if not self.test_running:
                    break
                
                # Envoyer le fichier audio
                audio_file = Path(audio_metadata['file_path'])
                success = await self.sender_client.send_audio_file(
                    audio_file,
                    audio_metadata
                )
                
                if success:
                    self.total_packets_sent += 1
                else:
                    self.errors_encountered.append({
                        'type': 'send_error',
                        'file': str(audio_file),
                        'timestamp': time.time()
                    })
            
            test_duration = time.time() - test_start
            
            # Attendre un peu pour recevoir les derniers paquets
            await asyncio.sleep(2)
            
            results = self._compile_test_results(test_duration)
            self.logger.success(f"✅ Test de base terminé en {test_duration:.1f}s")
            
            return results
            
        except Exception as e:
            self.logger.error(f"💥 Erreur pendant le test de base: {e}")
            raise
        finally:
            self.test_running = False
    
    async def run_stress_test(self, packets_count: int = 50, interval_ms: int = 500) -> Dict[str, Any]:
        """
        Exécute un test de stress avec envoi rapide
        
        Args:
            packets_count: Nombre de paquets à envoyer
            interval_ms: Intervalle entre les paquets en ms
        
        Returns:
            Résultats du test
        """
        self.current_test_name = "stress_test"
        self.logger.info(f"🔥 Démarrage test de stress ({packets_count} paquets, {interval_ms}ms)")
        
        test_start = time.time()
        self.test_start_time = test_start
        self.test_running = True
        
        try:
            for i in range(packets_count):
                if not self.test_running:
                    break
                
                # Générer une phrase courte
                text = self.voice_synthesizer.get_random_phrase('technical')
                audio_metadata = await self.voice_synthesizer.generate_audio(
                    text, 
                    f"stress_{i+1}"
                )
                
                if audio_metadata:
                    audio_file = Path(audio_metadata['file_path'])
                    success = await self.sender_client.send_audio_file(
                        audio_file,
                        audio_metadata
                    )
                    
                    if success:
                        self.total_packets_sent += 1
                    else:
                        self.errors_encountered.append({
                            'type': 'stress_send_error',
                            'packet': i+1,
                            'timestamp': time.time()
                        })
                
                # Attendre l'intervalle
                await asyncio.sleep(interval_ms / 1000)
            
            test_duration = time.time() - test_start
            
            # Attendre pour recevoir les derniers paquets
            await asyncio.sleep(3)
            
            results = self._compile_test_results(test_duration)
            self.logger.success(f"✅ Test de stress terminé en {test_duration:.1f}s")
            
            return results
            
        except Exception as e:
            self.logger.error(f"💥 Erreur pendant le test de stress: {e}")
            raise
        finally:
            self.test_running = False
    
    async def run_latency_test(self, quick_packets: int = 20) -> Dict[str, Any]:
        """
        Exécute un test de latence avec paquets rapides
        
        Args:
            quick_packets: Nombre de paquets rapides à envoyer
        
        Returns:
            Résultats du test
        """
        self.current_test_name = "latency_test"
        self.logger.info(f"⚡ Démarrage test de latence ({quick_packets} paquets)")
        
        test_start = time.time()
        self.test_start_time = test_start
        self.test_running = True
        
        try:
            for i in range(quick_packets):
                if not self.test_running:
                    break
                
                # Générer une phrase très courte
                text = f"Test latence numéro {i+1}"
                audio_metadata = await self.voice_synthesizer.generate_audio(
                    text,
                    f"latency_{i+1}"
                )
                
                if audio_metadata:
                    audio_file = Path(audio_metadata['file_path'])
                    
                    # Marquer le temps d'envoi précis
                    send_timestamp = time.time()
                    audio_metadata['precise_send_time'] = send_timestamp
                    
                    success = await self.sender_client.send_audio_file(
                        audio_file,
                        audio_metadata
                    )
                    
                    if success:
                        self.total_packets_sent += 1
                
                # Intervalle très court pour le test de latence
                await asyncio.sleep(0.2)
            
            test_duration = time.time() - test_start
            
            # Attendre plus longtemps pour s'assurer de recevoir tous les paquets
            await asyncio.sleep(5)
            
            results = self._compile_test_results(test_duration)
            self.logger.success(f"✅ Test de latence terminé en {test_duration:.1f}s")
            
            return results
            
        except Exception as e:
            self.logger.error(f"💥 Erreur pendant le test de latence: {e}")
            raise
        finally:
            self.test_running = False
    
    def _compile_test_results(self, test_duration: float) -> Dict[str, Any]:
        """Compile les résultats d'un test"""
        # Calculer les statistiques de latence
        latency_stats = {}
        if self.total_latency_measurements:
            latency_stats = {
                'min_ms': min(self.total_latency_measurements),
                'max_ms': max(self.total_latency_measurements),
                'avg_ms': sum(self.total_latency_measurements) / len(self.total_latency_measurements),
                'count': len(self.total_latency_measurements)
            }
        
        # Calculer le taux de perte
        packet_loss_rate = 0.0
        if self.total_packets_sent > 0:
            packet_loss_rate = max(0, (self.total_packets_sent - self.total_packets_received) / self.total_packets_sent)
        
        results = {
            'test_name': self.current_test_name,
            'duration_seconds': test_duration,
            'packets_sent': self.total_packets_sent,
            'packets_received': self.total_packets_received,
            'packet_loss_rate': packet_loss_rate,
            'latency_stats': latency_stats,
            'errors_count': len(self.errors_encountered),
            'errors': self.errors_encountered,
            'throughput_pps': self.total_packets_sent / test_duration if test_duration > 0 else 0,
            'timestamp': time.time()
        }
        
        # Ajouter les métriques des composants
        results['component_metrics'] = metrics_collector.get_global_metrics()
        
        return results
    
    async def disconnect_all(self):
        """Déconnecte tous les clients"""
        self.logger.info("🔌 Déconnexion de tous les clients...")
        
        tasks = []
        if self.sender_client and self.sender_client.is_connected:
            tasks.append(self.sender_client.disconnect())
        
        if self.receiver_client and self.receiver_client.is_connected:
            tasks.append(self.receiver_client.disconnect())
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        
        self.logger.success("✅ Tous les clients déconnectés")
    
    def print_final_summary(self):
        """Affiche un résumé final de tous les tests"""
        self.logger.info("\n" + "="*60)
        self.logger.info("📊 RÉSUMÉ FINAL DES TESTS LIVEKIT")
        self.logger.info("="*60)
        
        # Afficher les métriques globales
        metrics_collector.print_global_summary()
        
        # Afficher les statistiques du générateur de voix
        if self.voice_synthesizer:
            voice_stats = self.voice_synthesizer.get_statistics()
            self.logger.info(f"\n🎤 GÉNÉRATEUR DE VOIX:")
            self.logger.info(f"  📁 Fichiers générés: {voice_stats['total_files_generated']}")
            self.logger.info(f"  💾 Taille totale: {voice_stats['total_size_bytes']} bytes")
        
        # Afficher les statistiques de connexion
        if self.sender_client:
            sender_stats = self.sender_client.get_connection_stats()
            self.logger.info(f"\n📤 CLIENT ÉMETTEUR:")
            self.logger.info(f"  🆔 Identity: {sender_stats['participant_identity']}")
            self.logger.info(f"  📦 Paquets envoyés: {sender_stats['packets_sent']}")
        
        if self.receiver_client:
            receiver_stats = self.receiver_client.get_connection_stats()
            self.logger.info(f"\n📥 CLIENT RÉCEPTEUR:")
            self.logger.info(f"  🆔 Identity: {receiver_stats['participant_identity']}")
            self.logger.info(f"  👥 Participants vus: {receiver_stats.get('remote_participants_count', 0)}")
        
        self.logger.info("\n" + "="*60)
    
    def stop_test(self):
        """Arrête le test en cours"""
        self.test_running = False
        self.logger.warning("🛑 Arrêt du test demandé")