import asyncio
import time
import sys
import os
import json
import wave
import numpy as np
import httpx
from pathlib import Path
from typing import Dict, Any, Optional, Callable

# Configuration de l'encodage pour Windows
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

# Assurez-vous que les modules locaux sont dans le PYTHONPATH
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))

from livekit_client import LiveKitTestClient
from pipeline_logger import PipelineLogger, metrics_collector
from voice_synthesizer import VoiceSynthesizer # Pour la synthèse vocale

# --- Configuration ---
BACKEND_URL = "http://192.168.1.44:8000" # URL de votre backend FastAPI
API_KEY = "eloquence_secure_api_key_production_2025" # Clé API pour le backend
SCENARIO_ID = "debat_politique"
ROOM_NAME_PREFIX = "debat_test_" # Préfixe pour les noms de room LiveKit

# LiveKit config (sera mis à jour par la réponse du backend)
LIVEKIT_URL = "ws://localhost:7880" # Valeur par défaut, sera écrasée
LIVEKIT_API_KEY = "APIzdkP2xtqwZTm" # Clé API LiveKit Cloud
LIVEKIT_API_SECRET = "Oe4KFyglWE5K865sFNilI5itntiasPSM9DZfoiQfvJEA" # Secret API LiveKit Cloud

# --- Logger global ---
logger = PipelineLogger("REALTIME_DIAGNOSIS")
metrics_collector.register_logger(logger)

# --- Fonctions utilitaires ---
async def create_backend_session(scenario_id: str) -> Optional[Dict[str, Any]]:
    """
    Crée une session via l'API backend et retourne les infos LiveKit.
    """
    logger.info(f"🚀 Demande de création de session pour le scénario: {scenario_id}")
    session_creation_url = f"{BACKEND_URL}/api/sessions"
    headers = {"X-API-Key": API_KEY}
    user_id = f"test-user-{int(time.time())}"

    payload = {
        "user_id": user_id,
        "language": "fr",
        "scenario_id": scenario_id,
        "is_multi_agent": False
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(session_creation_url, json=payload, headers=headers, timeout=30)
            response.raise_for_status()
            session_data = response.json()

            logger.success(f"✅ Session backend créée: {session_data.get('session_id')}")
            logger.debug(f"Session data: {session_data}")

            # Extraire les informations LiveKit
            livekit_url = session_data.get("livekit_url")
            livekit_token = session_data.get("livekit_token")
            room_name = session_data.get("room_name")
            initial_message = session_data.get("initial_message", {}).get("text", "")

            if not all([livekit_url, livekit_token, room_name]):
                logger.error("❌ Informations LiveKit manquantes dans la réponse du backend.")
                return None

            # Mettre à jour les variables globales de LiveKit
            global LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET
            # Convertir l'URL Docker en URL localhost pour le test depuis l'hôte
            if livekit_url.startswith("ws://livekit:"):
                LIVEKIT_URL = livekit_url.replace("ws://livekit:", "ws://localhost:")
            else:
                LIVEKIT_URL = livekit_url
            # Les clés API ne sont pas retournées par l'API de session, elles sont utilisées pour générer le token
            # On garde les valeurs par défaut ou celles définies manuellement pour le client LiveKit
            
            logger.info(f"LiveKit URL: {LIVEKIT_URL}, Room: {room_name}")
            return {
                "livekit_url": livekit_url,
                "livekit_token": livekit_token,
                "room_name": room_name,
                "initial_message": initial_message
            }

    except httpx.RequestError as e:
        logger.error(f"❌ Erreur réseau lors de la création de session: {e}")
        return None
    except httpx.HTTPStatusError as e:
        logger.error(f"❌ Erreur HTTP lors de la création de session: {e.response.status_code} - {e.response.text}")
        return None
    except Exception as e:
        logger.error(f"❌ Erreur inattendue lors de la création de session: {e}")
        return None

# --- Classe de test ---
class RealtimeAudioTester:
    def __init__(self, livekit_url: str, api_key: str, api_secret: str, room_name: str):
        self.livekit_url = livekit_url
        self.api_key = api_key
        self.api_secret = api_secret
        self.room_name = room_name

        self.sender_client = LiveKitTestClient(livekit_url, api_key, api_secret, client_type="sender")
        self.receiver_client = LiveKitTestClient(livekit_url, api_key, api_secret, client_type="receiver")
        
        self.voice_synthesizer = VoiceSynthesizer()
        
        self.sent_packets: Dict[int, Dict[str, Any]] = {}
        self.received_packets: Dict[int, Dict[str, Any]] = {}
        
        self.logger = PipelineLogger("REALTIME_TESTER")
        metrics_collector.register_logger(self.logger)

        # Configurer les callbacks de réception
        self.receiver_client.on_audio_received = self._on_audio_received
        self.receiver_client.on_data_received = self._on_data_received
        self.receiver_client.on_participant_connected = self._on_participant_connected
        
        self.ai_conversation_history = [] # Pour stocker les messages de l'IA

    async def _on_audio_received(self, audio_data: bytes, participant_identity: str, audio_frame: Any):
        """Callback pour l'audio reçu"""
        packet_id = self.receiver_client.packet_counter # Utiliser le compteur du client récepteur
        self.received_packets[packet_id] = {
            "timestamp": time.time(),
            "type": "audio",
            "participant": participant_identity,
            "size": len(audio_data),
            "sample_rate": audio_frame.frame.sample_rate,
            "channels": audio_frame.frame.num_channels
        }
        self.logger.info(f"🎧 Audio reçu de {participant_identity} (chunk #{packet_id})")
        # Mesurer la latence si c'est une réponse à un paquet envoyé
        # (nécessite un mécanisme pour lier les paquets envoyés/reçus)

    async def _on_data_received(self, data: bytes, participant: Any, kind: Any):
        """Callback pour les messages de données reçus"""
        try:
            message = data.decode('utf-8')
            log_message = f"💬 Message de données reçu de {participant.identity} (Kind: {kind}): {message}"
            self.logger.info(log_message)
            
            # Si c'est un message de l'IA, on le logue comme une réponse et on l'ajoute à l'historique
            if participant.identity.startswith("backend-agent"):
                self.logger.info(f"🤖 IA: {message}") # Rendre le log de l'IA plus visible
                self.ai_conversation_history.append({"sender": participant.identity, "message": message, "timestamp": time.time()})
            elif participant.identity.startswith("sender_test"): # Si c'est le message de confirmation de l'émetteur
                self.logger.info(f"🗣️ Utilisateur: {message}") # Loguer comme un message utilisateur
        except UnicodeDecodeError:
            self.logger.info(f"📦 Données binaires reçues de {participant.identity} (non-texte, Kind: {kind})")
        except Exception as e:
            self.logger.error(f"❌ Erreur décodage données de {participant.identity}: {e}")
        
    async def _on_participant_connected(self, participant: Any):
        """Callback quand un participant se connecte"""
        self.logger.info(f"👤 Participant connecté: {participant.identity}")
        if participant.identity.startswith("backend-agent"):
            self.logger.success("🎉 Agent IA détecté et connecté!")

    async def run_test(self, phrases: list[str], duration_seconds: int = 60):
        """
        Exécute le test de diagnostic en temps réel.
        """
        logger.info("--- Démarrage du test de diagnostic en temps réel ---")
        
        # 1. Connexion des clients LiveKit
        logger.info("🔗 Connexion des clients LiveKit...")
        sender_connected = await self.sender_client.connect(self.room_name, "sender_test")
        receiver_connected = await self.receiver_client.connect(self.room_name, "receiver_test")

        if not sender_connected or not receiver_connected:
            logger.error("❌ Échec de la connexion d'un ou plusieurs clients LiveKit.")
            return False

        logger.success("✅ Clients LiveKit connectés.")
        await asyncio.sleep(5) # Attendre la découverte des participants

        # Publier la piste audio pour l'émetteur
        await self.sender_client.publish_audio_track()

        # 2. Envoyer des phrases synthétisées
        logger.info("🎤 Envoi de phrases synthétisées...")
        for i, phrase in enumerate(phrases):
            logger.info(f"--- Envoi phrase {i+1}/{len(phrases)}: '{phrase[:50]}...' ---")
            
            # Générer l'audio
            audio_info = await self.voice_synthesizer.generate_audio(phrase, f"temp_test_phrase_{i}.wav")
            if not audio_info or 'file_path' not in audio_info:
                logger.error(f"❌ Échec de la génération audio ou chemin de fichier manquant pour: {phrase}")
                continue
            
            audio_file_path = Path(audio_info['file_path'])
            
            # Lire le fichier WAV pour obtenir les données brutes et les métadonnées
            with wave.open(str(audio_file_path), 'rb') as wav_file:
                audio_data = wav_file.readframes(wav_file.getnframes())
                sample_rate = wav_file.getframerate()
                channels = wav_file.getnchannels()

            # Envoyer l'audio via LiveKit en utilisant la nouvelle méthode send_audio_file
            send_start_time = time.time()
            success = await self.sender_client.send_audio_file(audio_file_path, {"phrase_id": i})
            send_end_time = time.time()
            
            if success:
                self.logger.success(f"✅ Phrase audio {i+1} envoyée: '{phrase[:50]}...' en {(send_end_time - send_start_time)*1000:.2f}ms") # Ajout du texte de la phrase
                self.sent_packets[i] = {"timestamp": send_start_time, "phrase": phrase}
            else:
                self.logger.error(f"❌ Échec de l'envoi de la phrase audio {i+1}: '{phrase[:50]}...'") # Ajout du texte de la phrase
            
            await asyncio.sleep(5) # Attendre la réponse de l'IA

        # 3. Maintenir la session et analyser les retours
        logger.info(f"⏱️ Maintien de la session pendant {duration_seconds} secondes pour l'analyse...")
        end_time = time.time() + duration_seconds
        while time.time() < end_time:
            # Ici, on pourrait envoyer des messages de "ping" ou d'autres données
            # pour maintenir l'activité et mesurer la latence continue.
            # Pour l'instant, on attend juste les événements.
            await asyncio.sleep(1)

        logger.info("--- Fin du test ---")
        return True

    async def disconnect(self):
        """Déconnecte les clients LiveKit"""
        logger.info("🔌 Déconnexion des clients LiveKit...")
        await self.sender_client.disconnect()
        await self.receiver_client.disconnect()
        logger.success("✅ Clients LiveKit déconnectés.")

    def generate_report(self):
        """Génère un rapport de test détaillé."""
        report = {
            "test_summary": "Rapport de diagnostic LiveKit en temps réel",
            "backend_url": BACKEND_URL,
            "scenario_id": SCENARIO_ID,
            "livekit_url": LIVEKIT_URL,
            "room_name": self.room_name,
            "sender_identity": self.sender_client.participant_identity,
            "receiver_identity": self.receiver_client.participant_identity,
            "sent_phrases_count": len(self.sent_packets),
            "received_audio_frames_count": self.receiver_client.received_audio_count,
            "received_data_messages_count": self.receiver_client.received_data_count,
            "ai_conversation_history": self.ai_conversation_history, # Ajout de l'historique de conversation
            "metrics": metrics_collector.get_global_metrics()
        }

        # Analyse des latences (simplifiée pour l'instant)
        # Pour une analyse plus poussée, il faudrait lier les paquets envoyés et reçus
        # en utilisant les IDs de paquets ou les horodatages.
        
        if self.receiver_client.received_audio_count > 0:
            report["audio_reception_status"] = "OK: Audio frames reçus."
            logger.success("🎉 Audio frames reçus avec succès par le récepteur!")
        else:
            report["audio_reception_status"] = "WARNING: Aucun audio frame reçu par le récepteur."
            logger.warning("⚠️ Aucun audio frame reçu par le récepteur.")

        if self.receiver_client.received_data_count > 0:
            report["data_reception_status"] = "OK: Messages de données reçus."
            logger.success("🎉 Messages de données reçus avec succès par le récepteur!")
        else:
            report["data_reception_status"] = "WARNING: Aucun message de données reçu par le récepteur."
            logger.warning("⚠️ Aucun message de données reçu par le récepteur.")

        # Afficher le rapport
        logger.info("\n--- RAPPORT DE TEST FINAL ---")
        logger.info(json.dumps(report, indent=2, ensure_ascii=False)) # ensure_ascii=False pour afficher les caractères spéciaux
        logger.info("-----------------------------")
        
        # Déplacer l'historique de conversation pour qu'il soit plus visible
        if self.ai_conversation_history:
            logger.info("\n--- HISTORIQUE DE CONVERSATION IA ---")
            for msg in self.ai_conversation_history:
                logger.info(f"[{time.strftime('%H:%M:%S', time.localtime(msg['timestamp']))}] {msg['sender']}: {msg['message']}")
            logger.info("-------------------------------------")
        else:
            logger.warning("⚠️ Aucun message de l'IA n'a été reçu pendant le test.")

        return report

async def main():
    logger.info("Démarrage du script de diagnostic LiveKit...")

    # 1. Créer la session backend
    session_info = await create_backend_session(SCENARIO_ID)
    if not session_info:
        logger.critical("Impossible de démarrer le test sans session backend.")
        sys.exit(1)

    livekit_url = session_info["livekit_url"]
    livekit_token = session_info["livekit_token"]
    room_name = session_info["room_name"]
    initial_message = session_info["initial_message"]

    logger.info(f"Message initial de l'IA: {initial_message}")

    # 2. Initialiser le testeur audio
    tester = RealtimeAudioTester(livekit_url, LIVEKIT_API_KEY, LIVEKIT_API_SECRET, room_name)
    
    phrases_a_envoyer = [
        "Bonjour, je suis votre interlocuteur IA. Commençons ce débat politique.",
        "Quel est votre point de vue sur la politique environnementale actuelle ?",
        "Pourriez-vous développer votre argumentation sur ce sujet ?",
        "Je vous écoute attentivement. N'hésitez pas à exprimer vos idées.",
        "Très bien. Passons maintenant à la question de l'économie."
    ]

    try:
        success = await tester.run_test(phrases_a_envoyer, duration_seconds=30)
        
        # Récupérer les métriques globales pour une analyse plus approfondie
        global_metrics = metrics_collector.get_global_metrics()
        livekit_sender_metrics = global_metrics['components'].get('LIVEKIT_SENDER', {})
        
        # Vérifier le taux de perte de paquets
        packet_loss_rate = livekit_sender_metrics.get('packet_loss_rate', 1.0) # Default to 1.0 if not found
        
        if success and packet_loss_rate < 0.05: # Tolérance de 5% de perte de paquets
            logger.success("Test de diagnostic terminé avec succès. Taux de perte de paquets acceptable.")
        else:
            logger.error(f"Le test de diagnostic s'est terminé avec des erreurs ou un taux de perte de paquets élevé: {packet_loss_rate:.2%}")
            success = False # Marquer le test comme échoué si la perte est trop élevée
    except Exception as e:
        logger.critical(f"Erreur critique durant l'exécution du test: {e}")
    finally:
        await tester.disconnect()
        tester.generate_report()
        metrics_collector.print_global_summary()

if __name__ == "__main__":
    asyncio.run(main())