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

# Import du service agent
from services.livekit_agent_service import agent_service

app = Flask(__name__)
CORS(app) # Active CORS pour toutes les routes

# Configuration Celery
app.config['CELERY_BROKER_URL'] = os.getenv('REDIS_URL', 'redis://redis:6379/0')
app.config['CELERY_RESULT_BACKEND'] = os.getenv('REDIS_URL', 'redis://redis:6379/0')

# Configuration LiveKit
LIVEKIT_API_KEY = os.getenv('LIVEKIT_API_KEY', 'devkey')
LIVEKIT_API_SECRET = os.getenv('LIVEKIT_API_SECRET', 'devsecret123456789abcdef0123456789abcdef')
LIVEKIT_URL_INTERNAL = os.getenv('LIVEKIT_URL', 'ws://livekit:7880')  # Pour Docker interne
LIVEKIT_URL_EXTERNAL = 'ws://192.168.1.44:7880'  # Pour les clients externes (IP réseau)

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

# Registre des sessions actives pour éviter les doublons
active_sessions = {}
session_lock = threading.Lock()

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
    return jsonify({"status": "healthy", "service": "eloquence-api"}), 200

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
    # CORRECTION: Utiliser timestamp local au lieu d'UTC pour éviter les problèmes de fuseau horaire
    import time
    now_timestamp = int(time.time())  # Timestamp Unix local
    exp_timestamp = now_timestamp + (24 * 3600)  # +24 heures
    
    # Log pour diagnostic
    logger.info(f"🔑 GÉNÉRATION TOKEN: now={now_timestamp}, exp={exp_timestamp}")
    logger.info(f"🔑 Date now: {datetime.fromtimestamp(now_timestamp)}")
    logger.info(f"🔑 Date exp: {datetime.fromtimestamp(exp_timestamp)}")
    
    payload = {
        'iss': LIVEKIT_API_KEY,
        'sub': participant_identity,
        'iat': now_timestamp,
        'exp': exp_timestamp,
        'nbf': now_timestamp,  # Not Before - requis par LiveKit
        'video': {  # CORRECTION: utiliser 'video' au lieu de 'grants'
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

@app.route('/api/scenarios', methods=['GET'])
def get_scenarios():
    """Retourne la liste des scénarios disponibles"""
    try:
        language = request.args.get('language', 'fr')
        
        # Scénarios de démonstration
        scenarios = [
            {
                "id": "demo-1",
                "title": "Entretien d'embauche" if language == 'fr' else "Job Interview",
                "description": "Préparez-vous pour un entretien d'embauche avec un coach IA" if language == 'fr' else "Prepare for a job interview with an AI coach",
                "category": "professional",
                "difficulty": "intermediate",
                "duration_minutes": 15,
                "language": language,
                "tags": ["entretien", "professionnel", "coaching"] if language == 'fr' else ["interview", "professional", "coaching"],
                "created_at": "2025-06-17T00:00:00Z",
                "updated_at": "2025-06-17T00:00:00Z"
            },
            {
                "id": "demo-2",
                "title": "Présentation publique" if language == 'fr' else "Public Speaking",
                "description": "Améliorez vos compétences de présentation en public" if language == 'fr' else "Improve your public speaking skills",
                "category": "communication",
                "difficulty": "advanced",
                "duration_minutes": 20,
                "language": language,
                "tags": ["présentation", "public", "communication"] if language == 'fr' else ["presentation", "public", "communication"],
                "created_at": "2025-06-17T00:00:00Z",
                "updated_at": "2025-06-17T00:00:00Z"
            },
            {
                "id": "demo-3",
                "title": "Conversation informelle" if language == 'fr' else "Casual Conversation",
                "description": "Pratiquez une conversation détendue avec l'IA" if language == 'fr' else "Practice casual conversation with AI",
                "category": "social",
                "difficulty": "beginner",
                "duration_minutes": 10,
                "language": language,
                "tags": ["conversation", "social", "débutant"] if language == 'fr' else ["conversation", "social", "beginner"],
                "created_at": "2025-06-17T00:00:00Z",
                "updated_at": "2025-06-17T00:00:00Z"
            }
        ]
        
        logger.info(f"✅ Scénarios récupérés pour langue: {language}")
        return jsonify({
            "scenarios": scenarios,
            "total": len(scenarios),
            "language": language,
            "timestamp": datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        logger.error(f"❌ Erreur récupération scénarios: {str(e)}")
        return jsonify({"error": f"Erreur lors de la récupération des scénarios: {str(e)}"}), 500

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
        
        # Clé unique pour identifier la session
        session_key = f"{user_id}_{scenario_id}"
        
        with session_lock:
            # Vérifier si une session active existe déjà
            if session_key in active_sessions:
                existing_session = active_sessions[session_key]
                # Vérifier si la session est encore valide (moins de 30 minutes)
                session_age = time.time() - existing_session.get('created_timestamp', 0)
                if session_age < 1800:  # 30 minutes
                    logger.info(f"🔄 Réutilisation session existante: {existing_session['room_name']}")
                    # Régénérer le token pour le client
                    new_token = generate_livekit_token(existing_session['room_name'], f"user_{user_id}")
                    existing_session['livekit_token'] = new_token
                    return jsonify(existing_session), 200
                else:
                    # Session expirée, la supprimer
                    logger.info(f"🗑️ Session expirée supprimée: {existing_session['room_name']}")
                    del active_sessions[session_key]
        
        # Créer une nouvelle session
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
            "created_timestamp": time.time(),  # Pour vérifier l'expiration
            "status": "active"
        }
        
        # CORRECTION CRITIQUE: Connecter l'agent AUTOMATIQUEMENT
        logger.info(f"🤖 LANCEMENT AGENT AUTOMATIQUE pour room: {room_name}")
        agent_connected = agent_service.start_agent_for_session(session_data)
        
        if agent_connected:
            logger.info(f"✅ AGENT CONNECTÉ avec succès pour session {session_data['session_id']}")
            # Ajouter les informations agent à la réponse
            session_data['agent_connected'] = True
            session_data['agent_identity'] = f"ai_agent_{session_data['session_id']}"
        else:
            logger.warning(f"⚠️ AGENT NON CONNECTÉ pour session {session_data['session_id']}")
            session_data['agent_connected'] = False
            session_data['agent_identity'] = None
        
        # Enregistrer la session dans le registre
        with session_lock:
            active_sessions[session_key] = session_data
            logger.info(f"📝 Session enregistrée: {room_name} (clé: {session_key})")
        
        # TEMPORAIRE: Désactiver Celery pour test agent
        logger.info("🔧 DIAGNOSTIC: Tests Celery désactivés temporairement")
        
        return jsonify(session_data), 201
        
    except Exception as e:
        logger.error(f"❌ DIAGNOSTIC: Erreur création session: {str(e)}")
        return jsonify({"error": f"Erreur lors de la création de session: {str(e)}"}), 500

@app.route('/api/session/start', methods=['POST'])
def start_session():
    """Endpoint alternatif pour démarrer une session (compatibilité)"""
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
        
        # Réponse simplifiée pour compatibilité
        session_data = {
            "session_id": str(uuid.uuid4()),
            "user_id": user_id,
            "scenario_id": scenario_id,
            "language": language,
            "room_name": room_name,
            "livekit_url": LIVEKIT_URL_EXTERNAL,
            "livekit_token": livekit_token,
            "participant_identity": participant_identity,
            "status": "active",
            "created_at": datetime.utcnow().isoformat()
        }
        
        logger.info(f"✅ Session démarrée via endpoint alternatif: {session_data['session_id']}")
        return jsonify(session_data), 201
        
    except Exception as e:
        logger.error(f"❌ Erreur démarrage session: {str(e)}")
        return jsonify({"error": f"Erreur lors du démarrage de session: {str(e)}"}), 500

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

@app.route('/api/sessions/active', methods=['GET'])
def get_active_sessions():
    """
    DIAGNOSTIC: Endpoint pour consulter les sessions actives
    """
    try:
        with session_lock:
            # Nettoyer les sessions expirées
            current_time = time.time()
            expired_keys = []
            for key, session in active_sessions.items():
                session_age = current_time - session.get('created_timestamp', 0)
                if session_age > 1800:  # 30 minutes
                    expired_keys.append(key)
            
            for key in expired_keys:
                logger.info(f"🗑️ Nettoyage session expirée: {active_sessions[key]['room_name']}")
                del active_sessions[key]
            
            sessions_info = {
                "active_sessions": dict(active_sessions),
                "total_active": len(active_sessions),
                "timestamp": datetime.utcnow().isoformat()
            }
        
        logger.info(f"📊 Sessions actives consultées: {len(active_sessions)} sessions")
        return jsonify(sessions_info), 200
        
    except Exception as e:
        logger.error(f"❌ DIAGNOSTIC: Erreur consultation sessions: {str(e)}")
        return jsonify({"error": f"Erreur consultation sessions: {str(e)}"}), 500

@app.route('/api/agents/status', methods=['GET'])
def get_agents_status():
    """
    DIAGNOSTIC: Endpoint pour consulter l'état des agents
    """
    try:
        agents_count = agent_service.get_active_agents_count()
        
        agents_info = {
            "active_agents_count": agents_count,
            "timestamp": datetime.utcnow().isoformat(),
            "service_status": "running"
        }
        
        logger.info(f"🤖 Agents actifs consultés: {agents_count} agents")
        return jsonify(agents_info), 200
        
    except Exception as e:
        logger.error(f"❌ DIAGNOSTIC: Erreur consultation agents: {str(e)}")
        return jsonify({"error": f"Erreur consultation agents: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)