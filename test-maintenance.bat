@echo off
setlocal enabledelayedexpansion

echo ================================================================
echo           TEST DU SCRIPT DE MAINTENANCE (MODE SIMULATION)
echo ================================================================

echo.
echo Ce script teste les fonctionnalites de maintenance sans modifications destructives
echo.

REM Test des prerequis
echo [TEST] Verification des prerequis...
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ECHEC] Docker non disponible
    goto :end
) else (
    echo [OK] Docker disponible
)

docker-compose --version >nul 2>&1
if errorlevel 1 (
    docker compose version >nul 2>&1
    if errorlevel 1 (
        echo [ECHEC] Docker Compose non disponible
        goto :end
    ) else (
        echo [OK] Docker Compose disponible (nouvelle version)
    )
) else (
    echo [OK] Docker Compose disponible
)

docker info >nul 2>&1
if errorlevel 1 (
    echo [ECHEC] Docker daemon non actif
    goto :end
) else (
    echo [OK] Docker daemon actif
)

if not exist "docker-compose.yml" (
    echo [ECHEC] Fichier docker-compose.yml manquant
    goto :end
) else (
    echo [OK] Fichier docker-compose.yml present
)

echo.
echo [TEST] Etat actuel des services...
docker-compose ps

echo.
echo [TEST] Verification des services individuels...
set "SERVICES=livekit whisper-stt piper-tts eloquence-agent api-backend"
for %%s in (%SERVICES%) do (
    docker-compose ps %%s | findstr "Up" >nul
    if errorlevel 1 (
        echo [INFO] Service %%s: ARRETE
    ) else (
        echo [OK] Service %%s: ACTIF
    )
)

echo.
echo [TEST] Simulation du nettoyage (dry-run)...
echo [SIMULATION] docker container prune --force
echo [SIMULATION] docker image prune --all --force  
echo [SIMULATION] docker volume prune --force
echo [SIMULATION] docker network prune --force

echo.
echo [TEST] Simulation du rebuild...
echo [SIMULATION] docker-compose build --no-cache

echo.
echo [TEST] Simulation du redemarrage...
echo [SIMULATION] docker-compose up -d

echo.
echo ================================================================
echo           RESULTAT DU TEST
echo ================================================================
echo [SUCCESS] Tous les tests de prerequis sont passes!
echo [INFO] Le script de maintenance est pret a etre execute
echo [WARNING] Pour executer la maintenance complete, utilisez: cleanup-final.bat
echo ================================================================

:end
echo.
pause