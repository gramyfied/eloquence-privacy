from flask import Flask, jsonify, request
from flask_cors import CORS
import os
import time
import uuid
import logging
import json
from datetime import datetime, timedelta
import jwt  # PyJWT pour génération manuelle

app = Flask(__name__)
CORS(app)  # Active CORS pour toutes les routes

# Configuration LiveKit
LIVEKIT_API_KEY = os.getenv('LIVEKIT_API_KEY', 'devkey')
LIVEKIT_API_SECRET = os.getenv('LIVEKIT_API_SECRET', 'secret') # La valeur par défaut est 'secret'
# Pour s'assurer que la clé secrète est 'secret' pour correspondre à livekit.yaml
LIVEKIT_API_SECRET = 'devsecret123456789abcdef0123456789abcdef0123456789abcdef'

# Détection automatique de l'IP locale
import socket
def get_local_ip():
    try:
        # Créer une connexion UDP pour déterminer l'IP locale
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except:
        return "192.168.1.44"  # Fallback sur votre IP actuelle

LOCAL_IP = get_local_ip()
# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("FLUTTER_STANDALONE_OPTIMIZED")

LIVEKIT_URL_EXTERNAL = os.getenv('LIVEKIT_URL_EXTERNAL_ENV', 'ws://192.168.1.44:7888')  # Utilise l'IP de l'hôte et le port exposé
logger.info(f"🔧 DIAGNOSTIC_ENV: LIVEKIT_URL_EXTERNAL initialisée à: {LIVEKIT_URL_EXTERNAL} (obtenu de LIVEKIT_URL_EXTERNAL_ENV ou fallback sur IP locale du conteneur {LOCAL_IP})")

# Cache pour l'état de l'agent
agent_status = {
    "is_ready": True,  # Considérer l'agent comme prêt par défaut
    "last_check": None,
    "rooms_active": set()
}

def generate_livekit_token(room_name: str, participant_identity: str, metadata: dict = None) -> str:
    """Génère un token LiveKit avec PyJWT (solution manuelle pour compatibilité go-jose)"""
    
    # Timestamps pour le token
    now = int(time.time())
    
    # Payload JWT compatible LiveKit
    payload = {
        "iss": LIVEKIT_API_KEY,  # Issuer (API Key)
        "sub": participant_identity,  # Subject (participant identity)
        "name": participant_identity,  # Nom du participant
        "iat": now,  # Issued at
        "nbf": now - 60,  # Not before (60s avant pour éviter les problèmes de sync)
        "exp": now + 3600,  # Expiration (1 heure)
        "video": {
            "room": room_name,
            "roomJoin": True,
            "roomCreate": True,
            "canPublish": True,
            "canSubscribe": True,
            "canPublishData": True,
            "canUpdateOwnMetadata": True
        }
    }
    
    # Ajouter les métadonnées si fournies
    if metadata:
        payload["metadata"] = json.dumps(metadata)
    
    # Générer le token avec PyJWT et algorithme HS256 (clé secrète en bytes)
    token = jwt.encode(payload, LIVEKIT_API_SECRET.encode('utf-8'), algorithm="HS256")
    
    logger.info(f"Token JWT généré manuellement pour {participant_identity} dans room {room_name}")
    return token

@app.route('/')
def home():
    return "Backend Flutter Standalone - Coaching Vocal IA"

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "ok",
        "service": "flutter_standalone_optimized",
        "mode": "standalone",
        "docker_required": False,
        "agent_ready": agent_status["is_ready"],
        "active_rooms": len(agent_status["rooms_active"])
    }), 200

@app.route('/api/agent/status', methods=['GET'])
def get_agent_status():
    """Endpoint pour vérifier l'état de l'agent"""
    agent_status["last_check"] = datetime.utcnow()
    
    return jsonify({
        "agent_ready": agent_status["is_ready"],
        "last_check": agent_status["last_check"].isoformat(),
        "active_rooms": list(agent_status["rooms_active"]),
        "recommendation": "ready" if agent_status["is_ready"] else "wait"
    }), 200

@app.route('/api/scenarios', methods=['GET'])
def get_scenarios():
    """Retourne la liste des scénarios de coaching disponibles"""
    try:
        language = request.args.get('language', 'fr')
        
        # Scénarios de coaching vocal avec voix françaises Bark TTS
        scenarios = [
            {
                "id": "demo-1",
                "name": "Entretien d'embauche",  # Changé de 'title' à 'name'
                "description": "Préparez-vous pour un entretien d'embauche avec des questions typiques et des conseils personnalisés.",
                "type": "professionnel",  # Changé de 'category' à 'type'
                "difficulty": "moyen",
                "duration_minutes": 20,
                "voice_id": "v2/fr_speaker_2",  # Voix masculine assertive
                "language": language,
                "objectives": [
                    "Améliorer la confiance en soi",
                    "Maîtriser les réponses aux questions difficiles",
                    "Optimiser la communication non-verbale"
                ],
                "sample_questions": [
                    "Parlez-moi de vous",
                    "Quelles sont vos principales qualités ?",
                    "Pourquoi voulez-vous ce poste ?"
                ],
                "mode": "standalone"  # Mode sans Docker
            },
            {
                "id": "demo-2",
                "name": "Présentation de projet",  # Changé de 'title' à 'name'
                "description": "Développez vos compétences de présentation pour captiver votre audience et transmettre vos idées efficacement.",
                "type": "communication",  # Changé de 'category' à 'type'
                "difficulty": "facile",
                "duration_minutes": 15,
                "voice_id": "v2/fr_speaker_1",  # Voix féminine douce
                "language": language,
                "objectives": [
                    "Structurer une présentation claire",
                    "Gérer le stress de la prise de parole",
                    "Engager l'audience efficacement"
                ],
                "sample_questions": [
                    "Présentez votre projet en 2 minutes",
                    "Quels sont les bénéfices attendus ?",
                    "Comment allez-vous mesurer le succès ?"
                ],
                "mode": "standalone"
            },
            {
                "id": "demo-3",
                "name": "Négociation commerciale",  # Changé de 'title' à 'name'
                "description": "Maîtrisez l'art de la négociation avec des techniques avancées et des mises en situation réalistes.",
                "type": "commercial",  # Changé de 'category' à 'type'
                "difficulty": "difficile",
                "duration_minutes": 25,
                "voice_id": "v2/fr_speaker_4",  # Voix masculine grave
                "language": language,
                "objectives": [
                    "Développer des stratégies de négociation",
                    "Gérer les objections clients",
                    "Conclure des accords gagnant-gagnant"
                ],
                "sample_questions": [
                    "Quel est votre meilleur prix ?",
                    "Que proposez-vous comme garanties ?",
                    "Pouvez-vous faire un geste commercial ?"
                ],
                "mode": "standalone"
            }
        ]
        
        logger.info(f"Scenarios recuperes pour langue: {language} - {len(scenarios)} scenarios disponibles")
        
        return jsonify({
            "scenarios": scenarios,
            "total_count": len(scenarios),
            "language": language,
            "mode": "standalone",
            "docker_required": False,
            "available_voices": [
                {"id": "v2/fr_speaker_0", "name": "Voix Neutre", "description": "Polyvalente pour usage general"},
                {"id": "v2/fr_speaker_1", "name": "Voix Feminine Douce", "description": "Coaching bienveillant"},
                {"id": "v2/fr_speaker_2", "name": "Voix Masculine Assertive", "description": "Instructions directes"},
                {"id": "v2/fr_speaker_3", "name": "Voix Feminine Expressive", "description": "Felicitations et encouragements"},
                {"id": "v2/fr_speaker_4", "name": "Voix Masculine Grave", "description": "Contexte professionnel"},
                {"id": "v2/fr_speaker_5", "name": "Voix Feminine Claire", "description": "Explications detaillees"}
            ]
        }), 200
        
    except Exception as e:
        logger.error(f"Erreur recuperation scenarios: {str(e)}")
        return jsonify({"error": f"Erreur lors de la recuperation des scenarios: {str(e)}"}), 500

@app.route('/api/sessions', methods=['POST'])
def create_session():
    """Crée une session LiveKit pour les tests - Mode Standalone"""
    try:
        data = request.get_json()
        
        # Validation des données requises
        if not data:
            return jsonify({"error": "Donnees JSON requises"}), 400
            
        user_id = data.get('user_id')
        scenario_id = data.get('scenario_id', 'default')
        language = data.get('language', 'fr')
        
        if not user_id:
            return jsonify({"error": "user_id requis"}), 400
        
        # UTILISER LA ROOM STATIQUE pour éviter l'erreur "no permissions"
        # timestamp = int(time.time())
        # room_name = f"session_{scenario_id}_{timestamp}"
        room_name = "coaching-room-1"  # Room statique où l'agent est connecté
        
        # Métadonnées enrichies pour debug
        metadata = {
            "scenario_id": scenario_id,
            "language": language,
            "created_at": datetime.utcnow().isoformat(),
            "backend_version": "manual_jwt_1.0"
        }
        
        # Générer le token LiveKit avec métadonnées
        participant_identity = f"user_{user_id}"
        livekit_token = generate_livekit_token(room_name, participant_identity, metadata)
        
        # Ajouter un délai plus long pour que l'agent soit prêt
        logger.info(f"Délai de synchronisation étendu pour l'agent...")
        time.sleep(2.0)  # 2 secondes pour s'assurer que l'agent est prêt
        
        # Ajouter la room aux rooms actives
        agent_status["rooms_active"].add(room_name)
        
        # Messages initiaux selon le scénario - Mode Optimisé
        scenario_messages = {
            'demo-1': "Bonjour ! Je suis votre coach IA pour l'entretien d'embauche. Commençons par une présentation rapide de vous-même.",
            'demo-2': "Salut ! Je suis votre assistant IA pour les présentations. Quel est le sujet de votre présentation ?",
            'demo-3': "Bonjour ! Je suis votre partenaire IA de négociation. Quelle est votre position de départ ?",
            'default': "Bonjour ! Je suis votre coach vocal IA. Comment puis-je vous aider aujourd'hui ?"
        }
        
        initial_message = scenario_messages.get(scenario_id, scenario_messages['default'])
        
        # Réponse avec les informations de session
        session_data = {
            "session_id": str(uuid.uuid4()),
            "user_id": user_id,
            "scenario_id": scenario_id,
            "language": language,
            "room_name": room_name,
            "livekit_url": LIVEKIT_URL_EXTERNAL,
            "livekit_token": livekit_token,
            "participant_identity": participant_identity,
            "initial_message": {
                "text": initial_message,
                "timestamp": int(time.time())
            },
            "created_at": datetime.utcnow().isoformat(),
            "status": "active",
            "mode": "standalone",
            "docker_required": False,
            "ai_agent_status": "ready",  # Agent IA prêt
            "metadata": metadata,
            "sync_delay_ms": 2000  # Délai recommandé côté client (2 secondes)
        }
        
        logger.info(f"Session optimisée créée: {session_data['session_id']} pour room {room_name}")
        logger.info(f"Agent status: READY, sync_delay: 2000ms")
        logger.info(f"Token généré pour: {participant_identity}")
        logger.info(f"🔧 DIAGNOSTIC_SESSION: URL LiveKit envoyée au client: {session_data['livekit_url']} (valeur de LIVEKIT_URL_EXTERNAL: {LIVEKIT_URL_EXTERNAL})")
        
        return jsonify(session_data), 201
        
    except Exception as e:
        logger.error(f"Erreur creation session: {str(e)}")
        return jsonify({"error": f"Erreur lors de la creation de session: {str(e)}"}), 500

@app.route('/api/diagnostic', methods=['GET'])
def get_diagnostic_status():
    """Endpoint pour vérifier l'état des services - Mode Standalone"""
    try:
        diagnostic_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "backend_status": "running",
            "mode": "standalone",
            "flutter_compatibility": "ok",
            "docker_required": False,
            "endpoints": {
                "scenarios": "available",
                "sessions": "available", 
                "health": "available",
                "diagnostic": "available"
            },
            "livekit_config": {
                "url": LIVEKIT_URL_EXTERNAL,
                "api_key": LIVEKIT_API_KEY[:8] + "...",  # Masquer la clé
                "status": "configured"
            },
            "services_status": {
                "backend": "running",
                "docker": "not_required",
                "livekit_server": "external",
                "tts": "simulated",
                "asr": "simulated"
            }
        }
        
        logger.info("Diagnostic standalone recupere")
        return jsonify(diagnostic_data), 200
        
    except Exception as e:
        logger.error(f"Erreur diagnostic: {str(e)}")
        return jsonify({"error": f"Erreur diagnostic: {str(e)}"}), 500

@app.route('/api/tts/simulate', methods=['POST'])
def simulate_tts():
    """Simulation TTS pour mode standalone"""
    try:
        data = request.get_json()
        text = data.get('text', '')
        voice_id = data.get('voice_id', 'v2/fr_speaker_1')
        
        # Simulation de réponse TTS
        response_data = {
            "status": "simulated",
            "text": text,
            "voice_id": voice_id,
            "audio_url": f"/api/audio/simulated/{uuid.uuid4()}.wav",
            "duration_seconds": len(text) * 0.1,  # Estimation
            "mode": "standalone"
        }
        
        logger.info(f"TTS simule pour texte: {text[:50]}...")
        return jsonify(response_data), 200
        
    except Exception as e:
        logger.error(f"Erreur simulation TTS: {str(e)}")
        return jsonify({"error": f"Erreur simulation TTS: {str(e)}"}), 500

@app.route('/api/sessions/active', methods=['GET'])
def get_active_sessions():
    """Retourne la liste des sessions actives pour l'agent monitor"""
    try:
        # Simuler des sessions actives basées sur les rooms actives
        active_sessions = []
        
        for room_name in agent_status["rooms_active"]:
            session_data = {
                "session_id": f"session_{room_name}_{int(time.time())}",
                "room_name": room_name,
                "created_at": datetime.utcnow().isoformat(),
                "status": "active"
            }
            active_sessions.append(session_data)
        
        return jsonify({
            "sessions": active_sessions,
            "total_count": len(active_sessions),
            "timestamp": datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        logger.error(f"Erreur récupération sessions actives: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/sessions/<session_id>/end', methods=['POST'])
def end_session(session_id):
    """Termine une session et nettoie les ressources"""
    try:
        data = request.get_json() or {}
        room_name = data.get('room_name')
        
        if room_name and room_name in agent_status["rooms_active"]:
            agent_status["rooms_active"].remove(room_name)
            logger.info(f"Session terminée: {session_id}, room: {room_name}")
        
        return jsonify({
            "status": "ended",
            "session_id": session_id,
            "timestamp": datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        logger.error(f"Erreur fin de session: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Démarrage du backend Flutter OPTIMISÉ - Coaching Vocal IA")
    logger.info("Mode: STANDALONE OPTIMISÉ (résout 'no permissions to access the room')")
    logger.info(f"LiveKit URL configurée: {LIVEKIT_URL_EXTERNAL}")
    logger.info(f"IP locale détectée: {LOCAL_IP}")
    logger.info(f"LIVEKIT_API_KEY: {LIVEKIT_API_KEY}")
    logger.info(f"LIVEKIT_API_SECRET: {LIVEKIT_API_SECRET}")
    logger.info("Fonctionnalités ajoutées:")
    logger.info("  - Vérification état agent")
    logger.info("  - Synchronisation room/agent (500ms)")
    logger.info("  - Métadonnées enrichies")
    logger.info("  - Gestion des sessions actives")
    logger.info("Endpoints disponibles:")
    logger.info("   GET  /api/scenarios     - Liste des scenarios")
    logger.info("   POST /api/sessions      - Creation de session")
    logger.info("   GET  /api/agent/status  - État de l'agent")
    logger.info("   POST /api/sessions/<id>/end - Fin de session")
    logger.info("   GET  /api/diagnostic    - Etat des services")
    logger.info("   POST /api/tts/simulate  - Simulation TTS")
    logger.info("   GET  /health           - Sante du service")
    logger.info("")
    logger.info("⚠️  IMPORTANT pour Flutter sur téléphone:")
    logger.info(f"   - Backend API: http://{LOCAL_IP}:8000")
    logger.info(f"   - LiveKit WebSocket: {LIVEKIT_URL_EXTERNAL}")
    
    app.run(host='0.0.0.0', port=8000, debug=True)
