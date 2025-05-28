import asyncio
import time
import random
import uuid
import tempfile
import os
from typing import List, Dict, Any, Optional
import pyttsx3
import threading
from pathlib import Path
import wave
import numpy as np

from pipeline_logger import PipelineLogger, metrics_collector

class VoiceSynthesizer:
    """
    Générateur de voix synthétisée pour les tests LiveKit
    Utilise pyttsx3 pour générer de l'audio synthétique
    """
    
    # Phrases de test pour différents scénarios
    TEST_PHRASES = {
        'greeting': [
            "Bonjour, ceci est un test de streaming audio.",
            "Bienvenue dans le système de coaching vocal.",
            "Salut ! Comment allez-vous aujourd'hui ?",
        ],
        'coaching': [
            "Excellent travail ! Continuez comme ça.",
            "Votre prononciation s'améliore considérablement.",
            "Essayez de parler un peu plus lentement.",
            "Parfait ! Votre intonation est très naturelle.",
        ],
        'questions': [
            "Pouvez-vous répéter cette phrase s'il vous plaît ?",
            "Que pensez-vous de ce sujet ?",
            "Comment vous sentez-vous par rapport à cet exercice ?",
        ],
        'technical': [
            "Test de latence du système de streaming.",
            "Vérification de la qualité audio en temps réel.",
            "Analyse des performances du pipeline LiveKit.",
            "Mesure de la robustesse de la connexion.",
        ],
        'long': [
            "Ceci est un test avec une phrase beaucoup plus longue pour analyser le comportement du système avec des contenus audio de durée variable et observer comment le pipeline gère les différentes tailles de données.",
            "Dans ce test approfondi, nous évaluons la capacité du système à maintenir une qualité audio constante même avec des phrases complexes contenant de nombreux mots et des structures grammaticales variées.",
        ]
    }
    
    def __init__(self, temp_dir: Optional[str] = None):
        self.logger = PipelineLogger("VOICE_SYNTH")
        metrics_collector.register_logger(self.logger)
        
        self.temp_dir = Path(temp_dir) if temp_dir else Path(tempfile.gettempdir()) / "livekit_test_audio"
        self.temp_dir.mkdir(exist_ok=True)
        
        self.packet_id_counter = 0
        self._lock = threading.Lock()
        
        # Configuration de pyttsx3
        self.engine = None
        self._init_tts_engine()
        
        self.logger.info("🎤 Générateur de voix synthétisée initialisé")
        self.logger.debug(f"📁 Répertoire temporaire: {self.temp_dir}")
    
    def _init_tts_engine(self):
        """Initialise le moteur TTS avec gestion d'erreurs"""
        try:
            self.engine = pyttsx3.init()
            
            # Configuration du moteur
            voices = self.engine.getProperty('voices')
            if voices:
                # Préférer une voix française si disponible
                french_voice = None
                for voice in voices:
                    if 'french' in voice.name.lower() or 'fr' in voice.id.lower():
                        french_voice = voice
                        break
                
                if french_voice:
                    self.engine.setProperty('voice', french_voice.id)
                    self.logger.info(f"🗣️ Voix française sélectionnée: {french_voice.name}")
                else:
                    self.logger.warning("⚠️ Aucune voix française trouvée, utilisation de la voix par défaut")
            
            # Configuration des paramètres
            self.engine.setProperty('rate', 150)  # Vitesse de parole
            self.engine.setProperty('volume', 0.9)  # Volume
            
            self.logger.success("Moteur TTS initialisé avec succès")
            
        except Exception as e:
            self.logger.error(f"Erreur lors de l'initialisation du moteur TTS: {e}")
            self.engine = None
    
    def get_random_phrase(self, category: str = None) -> str:
        """Retourne une phrase aléatoire d'une catégorie donnée"""
        if category and category in self.TEST_PHRASES:
            phrases = self.TEST_PHRASES[category]
        else:
            # Sélectionner une catégorie aléatoire
            category = random.choice(list(self.TEST_PHRASES.keys()))
            phrases = self.TEST_PHRASES[category]
        
        phrase = random.choice(phrases)
        self.logger.debug(f"📝 Phrase sélectionnée ({category}): '{phrase[:50]}...'")
        return phrase
    
    async def generate_audio(self, text: str, phrase_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Génère un fichier audio à partir du texte
        Retourne les métadonnées de génération
        """
        if not self.engine:
            self.logger.error("❌ Moteur TTS non disponible")
            return None
        
        if not phrase_id:
            phrase_id = str(uuid.uuid4())[:8]
        
        generation_start = time.time()
        
        self.logger.info(f"🎵 Génération audio pour phrase #{phrase_id}")
        self.logger.debug(f"📝 Texte: '{text}'")
        
        try:
            # Créer le fichier temporaire
            audio_file = self.temp_dir / f"synth_audio_{phrase_id}.wav"
            
            # Génération synchrone dans un thread séparé pour éviter le blocage
            def generate_sync():
                try:
                    self.engine.save_to_file(text, str(audio_file))
                    self.engine.runAndWait()
                    return True
                except Exception as e:
                    self.logger.error(f"Erreur génération TTS: {e}")
                    return False
            
            # Exécuter dans un thread séparé
            loop = asyncio.get_event_loop()
            success = await loop.run_in_executor(None, generate_sync)
            
            if not success or not audio_file.exists():
                self.logger.error(f"❌ Échec de la génération audio pour {phrase_id}")
                return None
            
            generation_time = (time.time() - generation_start) * 1000
            
            # Analyser le fichier audio généré
            audio_info = self._analyze_audio_file(audio_file)
            
            metadata = {
                "phrase_id": phrase_id,
                "text": text,
                "generation_time_ms": generation_time,
                "file_path": str(audio_file),
                "file_size": audio_file.stat().st_size,
                "audio_info": audio_info,
                "timestamp": time.time()
            }
            
            self.logger.latency("génération", generation_time)
            self.logger.success(f"Audio généré: {audio_file.name} ({metadata['file_size']} bytes)")
            
            return metadata
            
        except Exception as e:
            self.logger.error(f"💥 Erreur lors de la génération audio: {e}")
            return None
    
    def _analyze_audio_file(self, audio_file: Path) -> Dict[str, Any]:
        """Analyse les propriétés d'un fichier audio WAV"""
        try:
            with wave.open(str(audio_file), 'rb') as wav_file:
                frames = wav_file.getnframes()
                sample_rate = wav_file.getframerate()
                channels = wav_file.getnchannels()
                sample_width = wav_file.getsampwidth()
                duration = frames / sample_rate
                
                info = {
                    "duration_seconds": duration,
                    "sample_rate": sample_rate,
                    "channels": channels,
                    "sample_width": sample_width,
                    "total_frames": frames,
                    "bitrate": sample_rate * channels * sample_width * 8
                }
                
                self.logger.debug(f"🎵 Audio analysé: {duration:.2f}s, {sample_rate}Hz, {channels}ch")
                return info
                
        except Exception as e:
            self.logger.warning(f"⚠️ Impossible d'analyser le fichier audio: {e}")
            return {}
    
    async def generate_continuous_stream(self, 
                                       interval_range: tuple = (2.0, 5.0),
                                       max_phrases: Optional[int] = None,
                                       categories: Optional[List[str]] = None) -> None:
        """
        Génère un flux continu de phrases synthétisées
        
        Args:
            interval_range: Intervalle (min, max) entre les phrases en secondes
            max_phrases: Nombre maximum de phrases à générer (None = infini)
            categories: Liste des catégories à utiliser (None = toutes)
        """
        self.logger.info("🚀 Démarrage du flux continu de génération audio")
        self.logger.info(f"⏱️ Intervalle: {interval_range[0]}-{interval_range[1]}s")
        
        if max_phrases:
            self.logger.info(f"🔢 Limite: {max_phrases} phrases")
        
        phrase_count = 0
        
        try:
            while True:
                # Vérifier la limite
                if max_phrases and phrase_count >= max_phrases:
                    self.logger.info(f"✅ Limite atteinte: {max_phrases} phrases générées")
                    break
                
                # Sélectionner une catégorie
                category = None
                if categories:
                    category = random.choice(categories)
                
                # Générer une phrase
                text = self.get_random_phrase(category)
                
                with self._lock:
                    self.packet_id_counter += 1
                    packet_id = self.packet_id_counter
                
                # Générer l'audio
                metadata = await self.generate_audio(text, f"stream_{packet_id}")
                
                if metadata:
                    phrase_count += 1
                    self.logger.audio_packet(
                        packet_id, 
                        metadata['file_size'], 
                        metadata['timestamp'],
                        {
                            'category': category,
                            'duration': metadata['audio_info'].get('duration_seconds', 0),
                            'generation_time': metadata['generation_time_ms']
                        }
                    )
                    
                    # Yield pour permettre le traitement
                    yield metadata
                else:
                    self.logger.error(f"❌ Échec génération phrase #{packet_id}")
                
                # Attendre avant la prochaine phrase
                wait_time = random.uniform(*interval_range)
                self.logger.debug(f"⏳ Attente {wait_time:.1f}s avant prochaine phrase")
                await asyncio.sleep(wait_time)
                
        except asyncio.CancelledError:
            self.logger.info("🛑 Flux continu interrompu")
        except Exception as e:
            self.logger.error(f"💥 Erreur dans le flux continu: {e}")
        finally:
            self.logger.info(f"📊 Total généré: {phrase_count} phrases")
    
    async def generate_test_scenario(self, scenario_name: str) -> List[Dict[str, Any]]:
        """
        Génère un scénario de test prédéfini
        
        Args:
            scenario_name: Nom du scénario ('basic', 'stress', 'mixed', 'latency')
        """
        scenarios = {
            'basic': {
                'phrases': ['greeting'] * 3,
                'interval': (1.0, 2.0)
            },
            'stress': {
                'phrases': ['technical'] * 10,
                'interval': (0.5, 1.0)
            },
            'mixed': {
                'phrases': ['greeting', 'coaching', 'questions', 'technical'],
                'interval': (1.5, 3.0)
            },
            'latency': {
                'phrases': ['technical'] * 5,
                'interval': (0.1, 0.3)  # Très rapide pour tester la latence
            }
        }
        
        if scenario_name not in scenarios:
            self.logger.error(f"❌ Scénario inconnu: {scenario_name}")
            return []
        
        scenario = scenarios[scenario_name]
        self.logger.info(f"🎬 Démarrage du scénario: {scenario_name}")
        
        results = []
        
        for i, category in enumerate(scenario['phrases']):
            text = self.get_random_phrase(category)
            metadata = await self.generate_audio(text, f"{scenario_name}_{i+1}")
            
            if metadata:
                results.append(metadata)
                self.logger.success(f"✅ Phrase {i+1}/{len(scenario['phrases'])} générée")
            
            # Attendre entre les phrases (sauf pour la dernière)
            if i < len(scenario['phrases']) - 1:
                wait_time = random.uniform(*scenario['interval'])
                await asyncio.sleep(wait_time)
        
        self.logger.success(f"🎬 Scénario {scenario_name} terminé: {len(results)} phrases")
        return results
    
    def cleanup_temp_files(self, max_age_hours: float = 1.0):
        """Nettoie les fichiers temporaires anciens"""
        try:
            current_time = time.time()
            max_age_seconds = max_age_hours * 3600
            
            cleaned = 0
            for audio_file in self.temp_dir.glob("synth_audio_*.wav"):
                if current_time - audio_file.stat().st_mtime > max_age_seconds:
                    audio_file.unlink()
                    cleaned += 1
            
            if cleaned > 0:
                self.logger.info(f"🧹 Nettoyage: {cleaned} fichiers temporaires supprimés")
                
        except Exception as e:
            self.logger.warning(f"⚠️ Erreur lors du nettoyage: {e}")
    
    def get_statistics(self) -> Dict[str, Any]:
        """Retourne les statistiques du générateur"""
        temp_files = list(self.temp_dir.glob("synth_audio_*.wav"))
        total_size = sum(f.stat().st_size for f in temp_files)
        
        return {
            'total_files_generated': len(temp_files),
            'total_size_bytes': total_size,
            'temp_directory': str(self.temp_dir),
            'phrases_available': sum(len(phrases) for phrases in self.TEST_PHRASES.values()),
            'categories_available': list(self.TEST_PHRASES.keys())
        }
    
    def __del__(self):
        """Nettoyage lors de la destruction de l'objet"""
        try:
            if hasattr(self, 'engine') and self.engine:
                self.engine.stop()
        except:
            pass