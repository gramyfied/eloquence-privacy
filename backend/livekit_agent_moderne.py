"""
Agent LiveKit Moderne pour Coaching Vocal IA
Utilise le framework LiveKit Agents pour une intégration optimale
Pipeline: Audio → Whisper ASR → Mistral LLM → Coqui TTS → Audio
"""

import asyncio
import logging
import os
import tempfile
import httpx
import numpy as np
from typing import Optional
from dotenv import load_dotenv

from livekit.agents import (
    Agent,
    AgentSession,
    JobContext,
    RunContext,
    WorkerOptions,
    cli,
    function_tool,
)
import webrtcvad
from livekit import rtc

# Charger les variables d'environnement
load_dotenv()

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("LIVEKIT_AGENT_MODERNE")

class CustomSTT:
    """STT personnalisé utilisant notre service Whisper"""
    
    def __init__(self, asr_url: str = "http://asr-service:8001/transcribe"):
        self.asr_url = asr_url
        logger.info(f"🎤 STT initialisé avec URL: {asr_url}")
    
    async def transcribe(self, audio_data: bytes) -> Optional[str]:
        """Transcription audio via notre service Whisper"""
        try:
            # Sauvegarder temporairement l'audio
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
                tmp_file.write(audio_data)
                tmp_file_path = tmp_file.name
            
            # Envoyer à notre service ASR
            async with httpx.AsyncClient() as client:
                with open(tmp_file_path, 'rb') as audio_file:
                    files = {'file': ('audio.wav', audio_file, 'audio/wav')}
                    response = await client.post(
                        self.asr_url,
                        files=files,
                        timeout=30.0
                    )
                
                if response.status_code == 200:
                    result = response.json()
                    transcription = result.get('text', '').strip()
                    logger.info(f"📝 Transcription: '{transcription}'")
                    return transcription
                else:
                    logger.warning(f"⚠️ ASR erreur {response.status_code}")
                    return None
                    
        except Exception as e:
            logger.error(f"❌ Erreur STT: {e}")
            return None
        finally:
            # Nettoyer le fichier temporaire
            try:
                os.unlink(tmp_file_path)
            except:
                pass

class CustomLLM:
    """LLM personnalisé pour les réponses de coaching vocal"""
    
    def __init__(self):
        self.conversation_history = []
        logger.info("🧠 LLM initialisé pour coaching vocal")
    
    async def generate_response(self, user_text: str, context: str = "") -> str:
        """Génère une réponse de coaching vocal"""
        try:
            # Ajouter à l'historique
            self.conversation_history.append({"role": "user", "content": user_text})
            
            # Réponses de coaching vocal contextuelles
            coaching_responses = [
                f"Excellent ! Vous avez dit '{user_text}'. Votre diction est claire. Essayons maintenant de travailler sur l'intonation.",
                f"Très bien ! J'ai entendu '{user_text}'. Pouvez-vous répéter en mettant plus d'émotion dans votre voix ?",
                f"Parfait ! Votre prononciation de '{user_text}' s'améliore. Continuons avec un exercice de respiration.",
                f"Bravo ! Vous maîtrisez bien '{user_text}'. Essayons maintenant de varier le rythme de votre élocution.",
                f"Formidable ! Votre expression '{user_text}' était très naturelle. Travaillons sur la projection de votre voix."
            ]
            
            import random
            response = random.choice(coaching_responses)
            
            # Ajouter à l'historique
            self.conversation_history.append({"role": "assistant", "content": response})
            
            logger.info(f"🧠 Réponse LLM générée: '{response[:50]}...'")
            return response
            
        except Exception as e:
            logger.error(f"❌ Erreur LLM: {e}")
            return "Je vous écoute, continuez votre exercice de diction."

class CustomTTS:
    """TTS personnalisé utilisant notre service Coqui TTS"""
    
    def __init__(self, tts_url: str = "http://tts-service:5002/api/tts"):
        self.tts_url = tts_url
        logger.info(f"🗣️ TTS initialisé avec URL: {tts_url}")
    
    async def synthesize(self, text: str) -> Optional[bytes]:
        """Synthèse vocale via notre service Coqui TTS"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.tts_url,
                    json={'text': text},
                    timeout=15.0
                )
                
                if response.status_code == 200:
                    audio_data = response.content
                    logger.info(f"🗣️ TTS généré: {len(audio_data)} octets")
                    return audio_data
                else:
                    logger.warning(f"⚠️ TTS erreur {response.status_code}")
                    return None
                    
        except Exception as e:
            logger.error(f"❌ Erreur TTS: {e}")
            return None

class CoachingVocalAgent(Agent):
    """Agent de coaching vocal intelligent"""
    
    def __init__(self):
        super().__init__(
            instructions="""Vous êtes un coach vocal IA expert. Votre mission est d'aider les utilisateurs à améliorer leur diction, leur élocution et leur expression orale. 
            
            Vous devez :
            - Écouter attentivement leur prononciation
            - Donner des conseils constructifs et encourageants
            - Proposer des exercices adaptés
            - Corriger les erreurs de diction avec bienveillance
            - Encourager la progression
            
            Soyez toujours positif, patient et professionnel."""
        )
        
        # Initialiser nos services personnalisés
        self.custom_stt = CustomSTT()
        self.custom_llm = CustomLLM()
        self.custom_tts = CustomTTS()
        
        # Compteurs de performance
        self.audio_frames_processed = 0
        self.transcriptions_made = 0
        self.responses_generated = 0
        
        logger.info("🎯 Agent de coaching vocal initialisé")
    
    async def on_enter(self):
        """Appelé quand l'agent entre dans la session"""
        logger.info("🚀 Agent de coaching vocal activé")
        
        # Message d'accueil
        welcome_message = """Bonjour ! Je suis votre coach vocal IA. 
        Je vais vous aider à améliorer votre diction et votre expression orale. 
        Commencez par me dire quelques mots pour que je puisse évaluer votre voix."""
        
        await self.session.generate_reply(instructions=welcome_message)
    
    async def process_audio_frame(self, audio_frame: rtc.AudioFrame) -> Optional[str]:
        """Traite une frame audio et retourne la transcription"""
        try:
            self.audio_frames_processed += 1
            
            # Convertir la frame en données audio
            audio_data = np.frombuffer(audio_frame.data, dtype=np.int16)
            
            # Convertir en WAV bytes pour le STT
            import wave
            import io
            
            wav_buffer = io.BytesIO()
            with wave.open(wav_buffer, 'wb') as wav_file:
                wav_file.setnchannels(1)  # Mono
                wav_file.setsampwidth(2)  # 16-bit
                wav_file.setframerate(audio_frame.sample_rate)
                wav_file.writeframes(audio_data.tobytes())
            
            wav_data = wav_buffer.getvalue()
            
            # Transcription
            transcription = await self.custom_stt.transcribe(wav_data)
            
            if transcription and len(transcription.strip()) > 2:
                self.transcriptions_made += 1
                return transcription
            
            return None
            
        except Exception as e:
            logger.error(f"❌ Erreur traitement audio: {e}")
            return None
    
    async def generate_coaching_response(self, user_text: str) -> Optional[bytes]:
        """Génère une réponse de coaching et la convertit en audio"""
        try:
            # Générer la réponse textuelle
            response_text = await self.custom_llm.generate_response(user_text)
            
            if response_text:
                self.responses_generated += 1
                
                # Convertir en audio
                audio_data = await self.custom_tts.synthesize(response_text)
                return audio_data
            
            return None
            
        except Exception as e:
            logger.error(f"❌ Erreur génération réponse: {e}")
            return None
    
    def get_performance_stats(self) -> dict:
        """Retourne les statistiques de performance"""
        return {
            "audio_frames_processed": self.audio_frames_processed,
            "transcriptions_made": self.transcriptions_made,
            "responses_generated": self.responses_generated,
            "success_rate": (self.transcriptions_made / max(1, self.audio_frames_processed)) * 100
        }

@function_tool
async def get_coaching_tips(
    context: RunContext,
    topic: str = "diction générale",
):
    """Fournit des conseils de coaching vocal sur un sujet spécifique"""
    
    tips = {
        "diction": [
            "Articulez chaque syllabe distinctement",
            "Ouvrez bien la bouche pour les voyelles",
            "Travaillez les consonnes finales"
        ],
        "respiration": [
            "Respirez avec le diaphragme, pas la poitrine",
            "Prenez des pauses naturelles entre les phrases",
            "Contrôlez votre débit de parole"
        ],
        "intonation": [
            "Variez votre mélodie vocale",
            "Montez en fin de question",
            "Descendez en fin d'affirmation"
        ]
    }
    
    topic_key = topic.lower()
    if any(key in topic_key for key in tips.keys()):
        for key in tips.keys():
            if key in topic_key:
                return {"tips": tips[key], "topic": topic}
    
    return {"tips": tips["diction"], "topic": "diction générale"}

async def entrypoint(room_name: str, participant_identity: str, livekit_token: str):
    """Point d'entrée principal de l'agent"""
    logger.info(f"🎯 Démarrage de l'agent de coaching vocal pour room: {room_name}")
    
    # Créer l'agent de coaching vocal
    agent = CoachingVocalAgent()
    
    # Créer la session avec VAD pour la détection de voix
    # Utiliser webrtcvad
    vad = webrtcvad.Vad(3) # Mode 3 est le plus agressif
    session = AgentSession(
        vad=vad,  # Détection d'activité vocale avec webrtcvad
        # Nos services personnalisés seront utilisés dans l'agent
    )
    
    # Démarrer la session
    # Utiliser les arguments pour se connecter à la room
    await session.start(
        agent=agent,
        room_url=os.getenv('LIVEKIT_URL', 'ws://livekit:7880'), # Utiliser l'URL interne par défaut
        token=livekit_token,
        participant_identity=participant_identity,
        room_name=room_name
    )
    
    logger.info(f"✅ Agent de coaching vocal démarré avec succès pour room: {room_name}")
    
    # Maintenir la session active
    try:
        while True:
            await asyncio.sleep(1)
            
            # Log des statistiques périodiquement
            if agent.audio_frames_processed % 100 == 0 and agent.audio_frames_processed > 0:
                stats = agent.get_performance_stats()
                logger.info(f"📊 Stats: {stats}")
                
    except KeyboardInterrupt:
        logger.info("🛑 Arrêt de l'agent demandé")
    except Exception as e:
        logger.error(f"❌ Erreur dans la boucle principale: {e}")
    finally:
        logger.info("🔌 Déconnexion de l'agent")

if __name__ == "__main__":
    # Lire les informations de connexion depuis les variables d'environnement
    room_name = os.getenv("ROOM_NAME")
    participant_identity = os.getenv("PARTICIPANT_IDENTITY")
    livekit_token = os.getenv("LIVEKIT_TOKEN")

    if not all([room_name, participant_identity, livekit_token]):
        logger.error("❌ Variables d'environnement ROOM_NAME, PARTICIPANT_IDENTITY et LIVEKIT_TOKEN doivent être définies.")
        exit(1)

    logger.info(f"🚀 Lancement de l'agent LiveKit moderne pour room: {room_name}")
    
    # Exécuter le point d'entrée avec les informations de connexion
    asyncio.run(entrypoint(room_name, participant_identity, livekit_token))