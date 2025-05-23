"""
Point d'entrée principal de l'application Eloquence Backend.
"""

import logging
import os
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

# Charger les variables d'environnement depuis le fichier .env
load_dotenv()

from app.routes.chat import router as chat_router
from app.routes.coaching import router as coaching_router
from app.routes.session import router as session_router
from app.routes.audio import router as audio_router
from app.routes.monitoring import router as monitoring_router
from app.routes.scenarios import router as scenarios_router
from app.routes.websocket import router as websocket_router
from app.routes.tts_cache import router as tts_cache_router
from app.routes.livekit import router as livekit_router
from core.database import init_db
from core.config import settings

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
)

logger = logging.getLogger(__name__)

# Création de l'application FastAPI
app = FastAPI(
    title="Eloquence Backend",
    description="Backend pour l'application Eloquence de coaching vocal",
    version="1.0.0",
)

# Configuration CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En production, spécifier les origines autorisées
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Événement de démarrage
@app.on_event("startup")
async def startup_event():
    """
    Événement exécuté au démarrage de l'application.
    """
    logger.info(f"Démarrage de l'application Eloquence Backend en mode DEBUG: {settings.DEBUG}")
    logger.info(f"Configuration LiveKit - Host: {settings.LIVEKIT_HOST}, API Key: {settings.LIVEKIT_API_KEY}")
    
    # Initialisation de la base de données
    try:
        await init_db()
        logger.info("Base de données initialisée avec succès")
    except Exception as e:
        logger.error(f"Erreur lors de l'initialisation de la base de données: {e}")
        # Ne pas faire échouer le démarrage pour les problèmes de DB en mode test
        if not settings.IS_TESTING:
            raise

# Événement d'arrêt
@app.on_event("shutdown")
async def shutdown_event():
    """
    Événement exécuté à l'arrêt de l'application.
    """
    logger.info("Arrêt de l'application Eloquence Backend")

# Gestionnaire d'exceptions global
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Gestionnaire d'exceptions global pour capturer toutes les exceptions non gérées.
    """
    logger.error(f"Exception non gérée: {exc}")
    return JSONResponse(
        status_code=500,
        content={"detail": "Une erreur interne est survenue"},
    )

# Route de base
@app.get("/")
async def root():
    """
    Route de base pour vérifier que l'application fonctionne.
    """
    return {
        "message": "Bienvenue sur l'API Eloquence Backend",
        "version": "1.0.0",
        "status": "running"
    }

# Route de santé
@app.get("/health")
async def health():
    """
    Route de santé pour vérifier que l'application fonctionne correctement.
    """
    return {
        "status": "ok",
        "version": "1.0.0",
        "mode": "debug" if settings.DEBUG else "production",
        "livekit_configured": bool(settings.LIVEKIT_HOST and settings.LIVEKIT_API_KEY),
        "database": "connected" if not settings.IS_TESTING else "test_mode"
    }

# Inclusion des routers
app.include_router(chat_router, prefix="/chat", tags=["chat"])
app.include_router(coaching_router, prefix="/coaching", tags=["coaching"])
app.include_router(session_router, prefix="/api", tags=["session"])
app.include_router(audio_router, prefix="/api", tags=["audio"])
app.include_router(monitoring_router, prefix="/api", tags=["monitoring"])
app.include_router(scenarios_router, prefix="/api", tags=["scenarios"])
app.include_router(websocket_router, tags=["websocket"])
app.include_router(tts_cache_router, tags=["tts_cache"])
app.include_router(livekit_router, prefix="/livekit", tags=["livekit"])
