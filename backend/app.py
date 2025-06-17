from flask import Flask, jsonify, request
from flask_cors import CORS
from celery import Celery
import os
import time
import uuid
import jwt
import asyncio
import threading
import logging
from datetime import datetime, timedelta

app = Flask(__name__)
CORS(app) # Active CORS pour toutes les routes

# Configuration Celery
app.config['CELERY_BROKER_URL'] = os.getenv('REDIS_URL', 'redis://redis:6379/0')
app.config['CELERY_RESULT_BACKEND'] = os.getenv('REDIS_URL', 'redis://redis:6379/0')

# Configuration LiveKit
LIVEKIT_API_KEY = os.getenv('LIVEKIT_API_KEY', 'devkey')
LIVEKIT_API_SECRET = os.getenv('LIVEKIT_API_SECRET', 'devsecret123456789abcdef0123456789abcdef0123456789abcdef')
LIVEKIT_URL_INTERNAL = os.getenv('LIVEKIT_URL', 'ws://livekit:7880')  # Pour Docker interne
LIVEKIT_URL_EXTERNAL = 'ws://localhost:7880'  # Pour les clients externes

# Initialisation Celery
celery = Celery(
    app.import_name,
    broker=app.config['CELERY_BROKER_URL'],
    backend=app.config['CELERY_RESULT_BACKEND']
)
celery.conf.update(app.config)

# Configuration du logging pour le diagnostic
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("BACKEND_DIAGNOSTIC")

# Tâches Celery
@celery.task
def example_task(param):
    """Tâche d'exemple pour tester Celery"""
    return f"Tâche exécutée avec le paramètre: {param}"

@celery.task
def process_audio_task(audio_data):
    """Tâche pour traiter l'audio"""
    # Logique de traitement audio ici
    return {"status": "processed", "data": audio_data}

@celery.task
def diagnostic_asr_task(audio_data):
    """DIAGNOSTIC: Tâche Celery pour tester l'ASR"""
    logger.info(f"🔄 DIAGNOSTIC: Tâche ASR Celery exécutée avec {len(audio_data) if audio_data else 0} bytes")
    try:
        # Simuler le traitement ASR
        import httpx
        import asyncio
        
        async def test_asr():
            async with httpx.AsyncClient() as client:
                response = await client.get("http://asr-service:8001/health", timeout=2.0)
                return response.status_code == 200
        
        # Exécuter le test ASR
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        asr_available = loop.run_until_complete(test_asr())
        loop.close()
        
        if asr_available:
            logger.info("✅ DIAGNOSTIC: Service ASR accessible depuis Celery")
            return {"status": "success", "asr_available": True}
        else:
            logger.warning("⚠️ DIAGNOSTIC: Service ASR non accessible depuis Celery")
            return {"status": "warning", "asr_available": False}
            
    except Exception as e:
        logger.error(f"❌ DIAGNOSTIC: Erreur tâche ASR Celery: {e}")
        return {"status": "error", "error": str(e)}

@celery.task
def diagnostic_tts_task(text):
    """DIAGNOSTIC: Tâche Celery pour tester le TTS"""
    logger.info(f"🔄 DIAGNOSTIC: Tâche TTS Celery exécutée avec texte: '{text[:50]}...'")
    try:
        # Simuler le traitement TTS
        import httpx
        import asyncio
        
        async def test_tts():
            async with httpx.AsyncClient() as client:
                response = await client.get("http://tts-service:5002/health", timeout=2.0)
                return response.status_code == 200
        
        # Exécuter le test TTS
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        tts_available = loop.run_until_complete(test_tts())
        loop.close()
        
        if tts_available:
            logger.info("✅ DIAGNOSTIC: Service TTS accessible depuis Celery")
            return {"status": "success", "tts_available": True}
        else:
            logger.warning("⚠️ DIAGNOSTIC: Service TTS non accessible depuis Celery")
            return {"status": "warning", "tts_available": False}
            
    except Exception as e:
        logger.error(f"❌ DIAGNOSTIC: Erreur tâche TTS Celery: {e}")
        return {"status": "error", "error": str(e)}

@app.route('/')
def home():
    return "Bienvenue sur le backend Flask!"

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "ok"}), 200

@app.route('/api/data')
def get_data():
    data = {
        "message": "Données du backend Flask",
        "version": "1.0"
    }
    return jsonify(data)

@app.route('/api/test-celery')
def test_celery():
    """Endpoint pour tester Celery"""
    task = example_task.delay("test")
    return jsonify({"task_id": task.id, "status": "Task started"})

def generate_livekit_token(room_name: str, participant_identity: str) -> str:
    """Génère un token LiveKit pour un participant"""
    now = datetime.utcnow()
    exp = now + timedelta(hours=24)  # Token valide 24h
    
    payload = {
        'iss': LIVEKIT_API_KEY,
        'sub': participant_identity,
        'iat': int(now.timestamp()),
        'exp': int(exp.timestamp()),
        'room': room_name,
        'grants': {
            'room': room_name,
            'roomJoin': True,
            'roomList': True,
            'roomRecord': False,
            'roomAdmin': False,
            'roomCreate': False,
            'canPublish': True,
            'canSubscribe': True,
            'canPublishData': True,
            'canUpdateOwnMetadata': True
        }
    }
    
    return jwt.encode(payload, LIVEKIT_API_SECRET, algorithm='HS256')

@app.route('/api/sessions', methods=['POST'])
def create_session():
    """Crée une session LiveKit pour les tests"""
    try:
        data = request.get_json()
        
        # Validation des données requises
        if not data:
            return jsonify({"error": "Données JSON requises"}), 400
            
        user_id = data.get('user_id')
        scenario_id = data.get('scenario_id', 'default')
        language = data.get('language', 'fr')
        
        if not user_id:
            return jsonify({"error": "user_id requis"}), 400
        
        # Générer un nom de room unique
        room_name = f"session_{scenario_id}_{int(time.time())}"
        
        # Générer le token LiveKit
        participant_identity = f"user_{user_id}"
        livekit_token = generate_livekit_token(room_name, participant_identity)
        
        # Message initial selon le scénario
        initial_messages = {
            'debat_politique': "Bienvenue dans ce débat politique. Je suis votre interlocuteur IA. Quel sujet souhaitez-vous aborder ?",
            'coaching_vocal': "Bonjour ! Je suis votre coach vocal IA. Commençons par quelques exercices de diction.",
            'default': "Bonjour ! Je suis votre assistant IA. Comment puis-je vous aider aujourd'hui ?"
        }
        
        initial_message = initial_messages.get(scenario_id, initial_messages['default'])
        
        # Réponse avec les informations de session
        session_data = {
            "session_id": str(uuid.uuid4()),
            "user_id": user_id,
            "scenario_id": scenario_id,
            "language": language,
            "room_name": room_name,
            "livekit_url": LIVEKIT_URL_EXTERNAL,  # Utiliser l'URL externe pour les clients
            "livekit_token": livekit_token,
            "participant_identity": participant_identity,
            "initial_message": {
                "text": initial_message,
                "timestamp": int(time.time())
            },
            "created_at": datetime.utcnow().isoformat(),
            "status": "active"
        }
        
        # Démarrer l'agent LiveKit dans un conteneur Docker séparé
        try:
            import subprocess
            
            # Construire la commande docker run
            command = [
                "docker", "run",
                "--rm", # Supprime le conteneur après l'arrêt
                "--network", "projeteloquence_livekit-network", # Spécifier le réseau Docker Compose
                "-e", f"ROOM_NAME={room_name}",
                "-e", f"PARTICIPANT_IDENTITY={participant_identity}",
                "-e", f"LIVEKIT_TOKEN={livekit_token}",
                "projeteloquence-livekit-agent:latest", # Utiliser le nom de l'image de l'agent
                "python", "livekit_agent_moderne.py" # Commande à exécuter dans le conteneur
            ]
            
            logger.info(f"🚀 Démarrage de l'agent LiveKit avec la commande: {' '.join(command)}")
            
            # Exécuter la commande en arrière-plan
            # Utiliser shell=True pour que les variables d'environnement soient correctement interprétées
            subprocess.Popen(" ".join(command), shell=True, cwd=".") # Exécuter dans le répertoire courant
            
            logger.info(f"✅ Agent LiveKit démarré pour session {session_data['session_id']}")
            
        except Exception as e:
            logger.error(f"❌ Erreur lors du démarrage de l'agent Docker: {str(e)}")
            # Continuer même si l'agent ne démarre pas, la session est quand même créée
            pass # Ou retourner une erreur si le démarrage de l'agent est critique
        
        # Tester les services ASR/TTS via Celery
        logger.info("🔧 DIAGNOSTIC: Test des services ASR/TTS via Celery")
        asr_task = diagnostic_asr_task.delay(b"test_audio_data")
        tts_task = diagnostic_tts_task.delay("Test TTS depuis backend")
        
        logger.info(f"🔧 DIAGNOSTIC: Tâches Celery lancées - ASR: {asr_task.id}, TTS: {tts_task.id}")
        
        return jsonify(session_data), 201
        
    except Exception as e:
        logger.error(f"❌ DIAGNOSTIC: Erreur création session: {str(e)}")
        return jsonify({"error": f"Erreur lors de la création de session: {str(e)}"}), 500

@app.route('/api/diagnostic', methods=['GET'])
def get_diagnostic_status():
    """
    DIAGNOSTIC: Endpoint pour vérifier l'état des services
    """
    try:
        logger.info("🔧 DIAGNOSTIC: Vérification état des services")
        
        diagnostic_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "backend_status": "running",
            "services_status": {},
            "celery_status": "unknown"
        }
        
        # Tester la connectivité des services
        import httpx
        import asyncio
        
        async def test_services():
            services = {
                "asr": "http://asr-service:8001/health",
                "tts": "http://tts-service:5002/health",
                "redis": "redis://redis:6379"
            }
            
            results = {}
            
            # Test ASR
            try:
                async with httpx.AsyncClient() as client:
                    response = await client.get(services["asr"], timeout=2.0)
                    results["asr"] = {
                        "status": "ok" if response.status_code == 200 else "error",
                        "response_code": response.status_code
                    }
            except Exception as e:
                results["asr"] = {"status": "error", "error": str(e)}
            
            # Test TTS
            try:
                async with httpx.AsyncClient() as client:
                    response = await client.get(services["tts"], timeout=2.0)
                    results["tts"] = {
                        "status": "ok" if response.status_code == 200 else "error",
                        "response_code": response.status_code
                    }
            except Exception as e:
                results["tts"] = {"status": "error", "error": str(e)}
            
            # Test Redis (via Celery)
            try:
                test_task = example_task.delay("diagnostic_test")
                results["redis"] = {
                    "status": "ok",
                    "celery_task_id": test_task.id
                }
                diagnostic_data["celery_status"] = "ok"
            except Exception as e:
                results["redis"] = {"status": "error", "error": str(e)}
                diagnostic_data["celery_status"] = "error"
            
            return results
        
        # Exécuter les tests de service
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        services_results = loop.run_until_complete(test_services())
        loop.close()
        
        diagnostic_data["services_status"] = services_results
        
        logger.info(f"✅ DIAGNOSTIC: État des services récupéré")
        return jsonify(diagnostic_data), 200
        
    except Exception as e:
        logger.error(f"❌ DIAGNOSTIC: Erreur récupération état: {str(e)}")
        return jsonify({"error": f"Erreur diagnostic: {str(e)}"}), 500

@app.route('/api/diagnostic/logs', methods=['GET'])
def get_diagnostic_logs():
    """
    DIAGNOSTIC: Endpoint pour récupérer les logs de diagnostic
    """
    try:
        # Récupérer les derniers logs (simulation)
        logs = []
        
        return jsonify({
            "logs": logs,
            "timestamp": datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        logger.error(f"❌ DIAGNOSTIC: Erreur récupération logs: {str(e)}")
        return jsonify({"error": f"Erreur logs diagnostic: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)