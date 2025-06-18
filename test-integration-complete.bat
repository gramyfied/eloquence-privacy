@echo off
echo ========================================
echo    TEST D'INTEGRATION ELOQUENCE COMPLET
echo ========================================
echo.

echo [1/6] Nettoyage des conteneurs existants...
docker-compose down --remove-orphans
docker system prune -f

echo.
echo [2/6] Construction des images Docker...
docker-compose build --no-cache

echo.
echo [3/6] Demarrage des services backend...
docker-compose up -d redis livekit asr-service tts-service

echo.
echo [4/6] Attente de l'initialisation des services (30s)...
timeout /t 30 /nobreak

echo.
echo [5/6] Verification de l'etat des services...
echo.
echo === REDIS ===
docker-compose exec redis redis-cli ping
echo.
echo === LIVEKIT ===
curl -f http://localhost:7880/ || echo "LiveKit non accessible"
echo.
echo === ASR SERVICE ===
curl -f http://localhost:8001/health || echo "ASR Service non accessible"
echo.
echo === TTS SERVICE ===
curl -f http://localhost:5002/health || echo "TTS Service non accessible"

echo.
echo [6/6] Demarrage du backend API et de l'agent...
docker-compose up -d api-backend eloquence-agent

echo.
echo ========================================
echo    INTEGRATION TEST COMPLETE
echo ========================================
echo.
echo Services disponibles:
echo - Redis: localhost:6379
echo - LiveKit: localhost:7880
echo - ASR Service: localhost:8001
echo - TTS Service: localhost:5002
echo - API Backend: localhost:8000
echo.
echo Pour tester le frontend Flutter:
echo 1. Ouvrir un terminal dans frontend/flutter_app/
echo 2. Executer: flutter run
echo.
echo Pour voir les logs:
echo docker-compose logs -f
echo.
echo Pour arreter tous les services:
echo docker-compose down