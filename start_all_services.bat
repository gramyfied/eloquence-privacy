@echo off
echo ========================================
echo   ELOQUENCE 2.0 - Demarrage complet
echo ========================================
echo.

:: Vérifier si Docker est en cours d'exécution
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] Docker n'est pas demarre !
    echo Veuillez demarrer Docker Desktop d'abord.
    pause
    exit /b 1
)

echo [1/4] Demarrage des services Docker...
echo.

:: Démarrer LiveKit
echo - Demarrage de LiveKit...
docker-compose up -d

:: Attendre que les services soient prêts
echo.
echo [2/4] Attente du demarrage des services...
timeout /t 10 /nobreak >nul

:: Vérifier les services
echo.
echo [3/4] Verification des services...
echo.

:: LiveKit
curl -s http://localhost:7880/health >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] LiveKit est operationnel
) else (
    echo [ERREUR] LiveKit ne repond pas
)

:: API Backend
curl -s http://localhost:8000/health >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] API Backend est operationnelle
) else (
    echo [ERREUR] API Backend ne repond pas
)

:: Whisper STT
curl -s http://localhost:8001/health >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Whisper STT est operationnel
) else (
    echo [ERREUR] Whisper STT ne repond pas
)

:: Piper TTS
curl -s http://localhost:5002/health >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Piper TTS est operationnel
) else (
    echo [ERREUR] Piper TTS ne repond pas
)

echo.
echo [4/4] Demarrage de l'agent IA...
echo.

:: Démarrer l'agent dans une nouvelle fenêtre
start "Agent IA Eloquence" cmd /k "cd backend && start_agent.bat"

echo.
echo ========================================
echo   Tous les services sont demarres !
echo ========================================
echo.
echo Vous pouvez maintenant :
echo 1. Lancer l'application Flutter
echo 2. Selectionner un scenario
echo 3. L'agent IA devrait repondre
echo.
echo Pour arreter tous les services :
echo - Fermez cette fenetre
echo - Executez: docker-compose down
echo.
pause