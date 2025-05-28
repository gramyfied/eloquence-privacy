#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Système de test complet pour LiveKit - Coaching Vocal Interactif
Génère des logs détaillés pour identifier les problèmes dans le pipeline
"""

import asyncio
import time
import json
import sys
import os
import random
import uuid
import logging
from pathlib import Path
from datetime import datetime
import threading
import queue

# Configuration de l'encodage pour Windows
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

try:
    import colorama
    from colorama import Fore, Style, Back
    colorama.init()
    COLORS_AVAILABLE = True
except ImportError:
    COLORS_AVAILABLE = False
    class Fore:
        RED = GREEN = YELLOW = BLUE = MAGENTA = CYAN = WHITE = RESET = ""
    class Style:
        BRIGHT = DIM = RESET_ALL = ""
    class Back:
        BLACK = RED = GREEN = YELLOW = BLUE = MAGENTA = CYAN = WHITE = RESET = ""

class PipelineLogger:
    """Logger avancé avec codes couleur pour le pipeline audio"""
    
    def __init__(self, component_name):
        self.component_name = component_name
        self.start_time = time.time()
        self.packet_count = 0
        self.latency_measurements = []
        
        # Configuration du logger
        self.logger = logging.getLogger(component_name)
        self.logger.setLevel(logging.DEBUG)
        
        # Éviter les doublons de handlers
        if not self.logger.handlers:
            # Handler pour fichier
            log_file = Path("livekit_test.log")
            fh = logging.FileHandler(log_file, encoding='utf-8')
            fh.setLevel(logging.DEBUG)
            
            # Handler pour console
            ch = logging.StreamHandler()
            ch.setLevel(logging.DEBUG)
            
            # Format détaillé
            formatter = logging.Formatter(
                '%(asctime)s.%(msecs)03d [%(reltime).3fs] %(component)s - %(levelname)s: %(message)s',
                datefmt='%H:%M:%S'
            )
            
            fh.setFormatter(formatter)
            ch.setFormatter(formatter)
            
            self.logger.addHandler(fh)
            self.logger.addHandler(ch)
    
    def _log(self, level, msg, *args, **kwargs):
        """Log avec couleurs et temps relatif"""
        extra = {
            'reltime': time.time() - self.start_time,
            'component': f"[{self.component_name:12}]"
        }
        
        if COLORS_AVAILABLE:
            if level == logging.DEBUG:
                msg = f"{Fore.CYAN}{msg}{Style.RESET_ALL}"
            elif level == logging.INFO:
                msg = f"{Fore.GREEN}{msg}{Style.RESET_ALL}"
            elif level == logging.WARNING:
                msg = f"{Fore.YELLOW}{msg}{Style.RESET_ALL}"
            elif level == logging.ERROR:
                msg = f"{Fore.RED}{msg}{Style.RESET_ALL}"
            elif level == logging.CRITICAL:
                msg = f"{Back.RED}{Fore.WHITE}{msg}{Style.RESET_ALL}"
        
        self.logger.log(level, msg, *args, extra=extra, **kwargs)
    
    def debug(self, msg, *args, **kwargs):
        self._log(logging.DEBUG, msg, *args, **kwargs)
    
    def info(self, msg, *args, **kwargs):
        self._log(logging.INFO, msg, *args, **kwargs)
    
    def warning(self, msg, *args, **kwargs):
        self._log(logging.WARNING, msg, *args, **kwargs)
    
    def error(self, msg, *args, **kwargs):
        self._log(logging.ERROR, msg, *args, **kwargs)
    
    def critical(self, msg, *args, **kwargs):
        self._log(logging.CRITICAL, msg, *args, **kwargs)
    
    def audio_packet(self, packet_id, size, timestamp, metadata=None):
        """Log spécifique pour les paquets audio"""
        self.packet_count += 1
        metadata_str = f", metadata: {metadata}" if metadata else ""
        self.debug(f"AUDIO PACKET #{packet_id} | Size: {size} bytes | TS: {timestamp:.3f}{metadata_str}")
    
    def latency(self, component, value_ms):
        """Log et stockage des mesures de latence"""
        self.latency_measurements.append(value_ms)
        
        if value_ms < 100:
            self.info(f"LATENCY | {component}: {value_ms:.2f} ms (EXCELLENT)")
        elif value_ms < 300:
            self.info(f"LATENCY | {component}: {value_ms:.2f} ms (BON)")
        elif value_ms < 500:
            self.warning(f"LATENCY | {component}: {value_ms:.2f} ms (ACCEPTABLE)")
        else:
            self.error(f"LATENCY | {component}: {value_ms:.2f} ms (PROBLEMATIQUE)")
    
    def get_stats(self):
        """Retourne les statistiques du composant"""
        if self.latency_measurements:
            avg_latency = sum(self.latency_measurements) / len(self.latency_measurements)
            max_latency = max(self.latency_measurements)
            min_latency = min(self.latency_measurements)
        else:
            avg_latency = max_latency = min_latency = 0
        
        return {
            "component": self.component_name,
            "packets": self.packet_count,
            "avg_latency": avg_latency,
            "max_latency": max_latency,
            "min_latency": min_latency,
            "uptime": time.time() - self.start_time
        }

# Configuration LiveKit avec les bonnes clés
LIVEKIT_CONFIG = {
    "livekit_url": "ws://localhost:7880",
    "api_key": "devkey",
    "api_secret": "devsecret123456789abcdef0123456789abcdef0123456789abcdef",
    "room_name": "coaching_vocal_test"
}

# Phrases de test pour le coaching vocal
PHRASES_COACHING = [
    "Bonjour, je suis votre coach vocal IA. Commençons par un exercice de respiration.",
    "Excellent travail ! Votre diction s'améliore considérablement.",
    "Essayons maintenant de travailler sur l'intonation. Répétez après moi.",
    "Votre rythme de parole est parfait pour une présentation professionnelle.",
    "N'oubliez pas de faire des pauses entre vos phrases pour plus d'impact.",
    "Bravo ! Votre confiance vocale progresse à chaque session.",
    "Concentrez-vous sur l'articulation de cette phrase complexe.",
    "Votre projection vocale est maintenant optimale pour un public large."
]

# Loggers globaux
synth_logger = PipelineLogger("VOICE_SYNTH")
sender_logger = PipelineLogger("SENDER")
livekit_logger = PipelineLogger("LIVEKIT")
receiver_logger = PipelineLogger("RECEIVER")
pipeline_logger = PipelineLogger("PIPELINE")
stats_logger = PipelineLogger("STATS")

class AudioMetrics:
    """Collecteur de métriques audio"""
    
    def __init__(self):
        self.reset()
    
    def reset(self):
        self.packets_sent = 0
        self.packets_received = 0
        self.packets_lost = 0
        self.total_latency = 0
        self.latency_count = 0
        self.start_time = time.time()
        self.errors = []
    
    def packet_sent(self):
        self.packets_sent += 1
    
    def packet_received(self):
        self.packets_received += 1
    
    def packet_lost(self):
        self.packets_lost += 1
    
    def add_latency(self, latency_ms):
        self.total_latency += latency_ms
        self.latency_count += 1
    
    def add_error(self, error):
        self.errors.append({
            "timestamp": time.time(),
            "error": str(error)
        })
    
    def get_stats(self):
        uptime = time.time() - self.start_time
        loss_rate = (self.packets_lost / max(self.packets_sent, 1)) * 100
        avg_latency = self.total_latency / max(self.latency_count, 1)
        
        return {
            "uptime": uptime,
            "packets_sent": self.packets_sent,
            "packets_received": self.packets_received,
            "packets_lost": self.packets_lost,
            "loss_rate": loss_rate,
            "avg_latency": avg_latency,
            "errors": len(self.errors)
        }

metrics = AudioMetrics()

async def generate_synthetic_voice():
    """Génère de la voix synthétisée pour le coaching vocal"""
    try:
        import pyttsx3
        engine = pyttsx3.init()
        
        # Configuration optimisée pour le coaching
        engine.setProperty('rate', 160)  # Vitesse modérée
        engine.setProperty('volume', 0.8)  # Volume confortable
        
        # Sélectionner une voix féminine si disponible
        voices = engine.getProperty('voices')
        for voice in voices:
            if 'female' in voice.name.lower() or 'woman' in voice.name.lower():
                engine.setProperty('voice', voice.id)
                break
        
        synth_logger.info("Générateur de voix initialisé pour coaching vocal")
        
    except ImportError:
        synth_logger.warning("pyttsx3 non disponible, simulation de la synthèse vocale")
        engine = None
    
    packet_id = 0
    
    while True:
        try:
            # Sélection intelligente de phrase
            phrase = random.choice(PHRASES_COACHING)
            phrase_id = str(uuid.uuid4())[:8]
            
            synth_logger.info(f"Génération phrase coaching #{phrase_id}: '{phrase[:50]}...'")
            generation_start = time.time()
            
            if engine:
                # Génération réelle
                temp_file = f"temp_audio_test/coaching_audio_{phrase_id}.wav"
                os.makedirs("temp_audio_test", exist_ok=True)
                
                synth_logger.debug(f"Sauvegarde dans {temp_file}")
                engine.save_to_file(phrase, temp_file)
                engine.runAndWait()
                
                if Path(temp_file).exists():
                    file_size = Path(temp_file).stat().st_size
                    synth_logger.debug(f"Fichier généré: {file_size} bytes")
                else:
                    synth_logger.error("Échec de génération du fichier audio")
                    continue
            else:
                # Simulation
                await asyncio.sleep(0.5)  # Simuler le temps de génération
                file_size = random.randint(50000, 150000)  # Taille simulée
                temp_file = None
            
            generation_time = (time.time() - generation_start) * 1000
            synth_logger.latency("generation", generation_time)
            
            # Métadonnées enrichies
            packet_id += 1
            metadata = {
                "phrase_id": phrase_id,
                "text": phrase,
                "generation_time": generation_time,
                "file_size": file_size,
                "coaching_type": "feedback" if "excellent" in phrase.lower() else "instruction"
            }
            
            # Envoi au pipeline LiveKit
            await send_audio_to_livekit(temp_file, packet_id, metadata)
            
            # Nettoyage
            if temp_file and Path(temp_file).exists():
                Path(temp_file).unlink()
            
            # Intervalle variable pour simuler une conversation naturelle
            interval = random.uniform(3.0, 8.0)
            synth_logger.debug(f"Attente {interval:.1f}s avant prochaine phrase")
            await asyncio.sleep(interval)
            
        except Exception as e:
            synth_logger.error(f"Erreur lors de la génération: {str(e)}")
            metrics.add_error(e)
            await asyncio.sleep(2)

async def send_audio_to_livekit(audio_file, packet_id, metadata):
    """Envoie l'audio à LiveKit avec métriques détaillées"""
    send_start = time.time()
    sender_logger.info(f"Envoi paquet coaching #{packet_id} vers LiveKit")
    
    try:
        from livekit import rtc, api
        
        # Créer token et connexion (simulation pour ce test)
        token_builder = api.AccessToken(LIVEKIT_CONFIG['api_key'], LIVEKIT_CONFIG['api_secret'])
        video_grants = api.VideoGrants(
            room_join=True,
            room=LIVEKIT_CONFIG['room_name'],
            can_publish=True,
            can_subscribe=True,
            can_publish_data=True
        )
        token = token_builder.with_identity(f"coach_ai_{packet_id}") \
                            .with_name("Coach IA") \
                            .with_grants(video_grants) \
                            .to_jwt()
        
        sender_logger.debug(f"Token généré pour paquet #{packet_id}")
        
        # Simulation de l'envoi (dans un vrai système, utilisez room.publish_data)
        await asyncio.sleep(random.uniform(0.05, 0.15))  # Simulation réseau
        
        send_time = (time.time() - send_start) * 1000
        sender_logger.latency("envoi", send_time)
        
        # Log du paquet avec métadonnées
        livekit_logger.audio_packet(
            packet_id,
            metadata.get("file_size", 0),
            time.time(),
            metadata
        )
        
        metrics.packet_sent()
        metrics.add_latency(send_time)
        
        # Simuler la réception
        await receive_audio_from_livekit(packet_id, metadata, send_start)
        
    except Exception as e:
        sender_logger.error(f"Erreur lors de l'envoi: {str(e)}")
        metrics.add_error(e)

async def receive_audio_from_livekit(packet_id, metadata, send_start):
    """Simule la réception et le traitement côté IA"""
    receive_start = time.time()
    
    # Simulation de délai réseau variable
    network_delay = random.uniform(0.02, 0.1)
    await asyncio.sleep(network_delay)
    
    # Simulation de perte de paquet (2% de perte)
    if random.random() < 0.02:
        livekit_logger.warning(f"Paquet #{packet_id} perdu dans le réseau")
        metrics.packet_lost()
        return
    
    receiver_logger.info(f"Réception paquet coaching #{packet_id}")
    
    # Simulation du traitement IA (analyse vocale, génération de feedback)
    processing_delay = random.uniform(0.1, 0.3)
    await asyncio.sleep(processing_delay)
    
    receive_time = (time.time() - receive_start) * 1000
    receiver_logger.latency("réception", receive_time)
    
    # Calcul de la latence totale bout-en-bout
    total_latency = (time.time() - send_start) * 1000
    pipeline_logger.latency("totale", total_latency)
    
    metrics.packet_received()
    metrics.add_latency(total_latency)
    
    # Analyse de la qualité du coaching
    coaching_type = metadata.get("coaching_type", "unknown")
    if coaching_type == "feedback":
        receiver_logger.info(f"Feedback positif traité avec succès")
    else:
        receiver_logger.info(f"Instruction de coaching traitée")
    
    # Évaluation de la performance
    if total_latency < 200:
        pipeline_logger.info(f"Performance EXCELLENTE: {total_latency:.2f}ms")
    elif total_latency < 500:
        pipeline_logger.info(f"Performance BONNE: {total_latency:.2f}ms")
    elif total_latency < 1000:
        pipeline_logger.warning(f"Performance ACCEPTABLE: {total_latency:.2f}ms")
    else:
        pipeline_logger.error(f"Performance PROBLÉMATIQUE: {total_latency:.2f}ms")

async def display_stats():
    """Affiche les statistiques en temps réel"""
    while True:
        await asyncio.sleep(10)  # Toutes les 10 secondes
        
        stats = metrics.get_stats()
        
        stats_logger.info("=" * 50)
        stats_logger.info("STATISTIQUES TEMPS RÉEL")
        stats_logger.info("=" * 50)
        stats_logger.info(f"Durée de fonctionnement: {stats['uptime']:.1f}s")
        stats_logger.info(f"Paquets envoyés: {stats['packets_sent']}")
        stats_logger.info(f"Paquets reçus: {stats['packets_received']}")
        stats_logger.info(f"Paquets perdus: {stats['packets_lost']}")
        stats_logger.info(f"Taux de perte: {stats['loss_rate']:.2f}%")
        stats_logger.info(f"Latence moyenne: {stats['avg_latency']:.2f}ms")
        stats_logger.info(f"Erreurs: {stats['errors']}")
        
        # Statistiques des composants
        for logger_obj in [synth_logger, sender_logger, receiver_logger]:
            comp_stats = logger_obj.get_stats()
            stats_logger.debug(f"{comp_stats['component']}: {comp_stats['packets']} paquets, "
                             f"latence moy: {comp_stats['avg_latency']:.2f}ms")

async def main():
    """Fonction principale du système de test"""
    pipeline_logger.info("=" * 60)
    pipeline_logger.info("DÉMARRAGE SYSTÈME TEST COACHING VOCAL LIVEKIT")
    pipeline_logger.info("=" * 60)
    pipeline_logger.info(f"Configuration: URL={LIVEKIT_CONFIG['livekit_url']}")
    pipeline_logger.info(f"Room: {LIVEKIT_CONFIG['room_name']}")
    
    try:
        # Test de connexion initial
        livekit_logger.info("Test de connexion au serveur LiveKit...")
        
        from livekit import rtc, api
        
        # Créer une room de test
        room_name = LIVEKIT_CONFIG['room_name']
        livekit_logger.info(f"Création de la room de coaching: {room_name}")
        
        # Démarrer les tâches en parallèle
        pipeline_logger.info("Démarrage des composants du pipeline...")
        
        tasks = [
            asyncio.create_task(generate_synthetic_voice()),
            asyncio.create_task(display_stats())
        ]
        
        # Lancer tous les composants
        await asyncio.gather(*tasks)
        
    except KeyboardInterrupt:
        pipeline_logger.info("Arrêt du système de test (Ctrl+C)")
    except Exception as e:
        pipeline_logger.critical(f"Erreur critique: {str(e)}")
        metrics.add_error(e)
    finally:
        # Affichage des statistiques finales
        final_stats = metrics.get_stats()
        pipeline_logger.info("=" * 60)
        pipeline_logger.info("STATISTIQUES FINALES")
        pipeline_logger.info("=" * 60)
        for key, value in final_stats.items():
            pipeline_logger.info(f"{key}: {value}")
        
        pipeline_logger.info("=" * 60)
        pipeline_logger.info("FIN DU SYSTÈME DE TEST COACHING VOCAL")
        pipeline_logger.info("=" * 60)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nArrêt du test")
    except Exception as e:
        print(f"Erreur: {e}")