@echo off
setlocal enabledelayedexpansion

:: Script de démarrage robuste pour Docker Compose sur Windows
:: Ce script gère le démarrage, l'arrêt et la surveillance des services

title Docker Eloquence - Gestion Robuste

:: Couleurs pour les messages (approximatives avec echo)
set "INFO=[INFO]"
set "SUCCESS=[SUCCESS]"
set "WARNING=[WARNING]"
set "ERROR=[ERROR]"

:: Fonction pour vérifier si Docker est en cours d'exécution
:check_docker
echo %INFO% Vérification de Docker...
docker info >nul 2>&1
if errorlevel 1 (
    echo %ERROR% Docker n'est pas en cours d'exécution. Veuillez démarrer Docker Desktop.
    pause
    exit /b 1
)
echo %SUCCESS% Docker est en cours d'exécution
goto :eof

:: Fonction pour nettoyer les anciens conteneurs
:cleanup
echo %INFO% Nettoyage des anciens conteneurs...
docker-compose -f docker-compose.robust.yml down --remove-orphans
docker system prune -f
echo %SUCCESS% Nettoyage terminé
goto :eof

:: Fonction pour construire les images
:build_images
echo %INFO% Construction des images Docker...
docker-compose -f docker-compose.robust.yml build --no-cache
if errorlevel 1 (
    echo %ERROR% Échec de la construction des images
    pause
    exit /b 1
)
echo %SUCCESS% Images construites avec succès
goto :eof

:: Fonction pour démarrer les services
:start_services
echo %INFO% Démarrage des services...
docker-compose -f docker-compose.robust.yml up -d
if errorlevel 1 (
    echo %ERROR% Échec du démarrage des services
    pause
    exit /b 1
)

echo %INFO% Attente que les services soient prêts...
timeout /t 30 /nobreak >nul

call :check_services_health
goto :eof

:: Fonction pour vérifier la santé des services
:check_services_health
echo %INFO% Vérification de la santé des services...

docker-compose -f docker-compose.robust.yml ps | findstr "redis.*Up" >nul
if errorlevel 1 (
    echo %ERROR% Service redis: ÉCHEC
) else (
    echo %SUCCESS% Service redis: OK
)

docker-compose -f docker-compose.robust.yml ps | findstr "livekit.*Up" >nul
if errorlevel 1 (
    echo %ERROR% Service livekit: ÉCHEC
) else (
    echo %SUCCESS% Service livekit: OK
)

docker-compose -f docker-compose.robust.yml ps | findstr "asr-service.*Up" >nul
if errorlevel 1 (
    echo %ERROR% Service asr-service: ÉCHEC
) else (
    echo %SUCCESS% Service asr-service: OK
)

docker-compose -f docker-compose.robust.yml ps | findstr "tts-service.*Up" >nul
if errorlevel 1 (
    echo %ERROR% Service tts-service: ÉCHEC
) else (
    echo %SUCCESS% Service tts-service: OK
)

docker-compose -f docker-compose.robust.yml ps | findstr "api.*Up" >nul
if errorlevel 1 (
    echo %ERROR% Service api: ÉCHEC
) else (
    echo %SUCCESS% Service api: OK
)

goto :eof

:: Fonction pour afficher les logs
:show_logs
echo %INFO% Affichage des logs en temps réel...
docker-compose -f docker-compose.robust.yml logs -f
goto :eof

:: Fonction pour arrêter les services
:stop_services
echo %INFO% Arrêt des services...
docker-compose -f docker-compose.robust.yml down
echo %SUCCESS% Services arrêtés
goto :eof

:: Fonction pour redémarrer les services
:restart_services
echo %INFO% Redémarrage des services...
call :stop_services
call :start_services
goto :eof

:: Fonction pour afficher l'aide
:show_help
echo Usage: %~nx0 [OPTION]
echo.
echo Options:
echo   start     Démarrer tous les services
echo   stop      Arrêter tous les services
echo   restart   Redémarrer tous les services
echo   build     Construire les images Docker
echo   cleanup   Nettoyer les anciens conteneurs
echo   logs      Afficher les logs en temps réel
echo   status    Vérifier l'état des services
echo   help      Afficher cette aide
echo.
pause
goto :eof

:: Menu principal
set "action=%~1"
if "%action%"=="" set "action=start"

if "%action%"=="start" (
    call :check_docker
    call :cleanup
    call :build_images
    call :start_services
    echo %SUCCESS% Tous les services sont démarrés!
    echo %INFO% API disponible sur: http://localhost:8000
    echo %INFO% LiveKit disponible sur: http://localhost:7880
    echo %INFO% Redis disponible sur: localhost:6380
    pause
) else if "%action%"=="stop" (
    call :stop_services
    pause
) else if "%action%"=="restart" (
    call :check_docker
    call :restart_services
    pause
) else if "%action%"=="build" (
    call :check_docker
    call :build_images
    pause
) else if "%action%"=="cleanup" (
    call :cleanup
    pause
) else if "%action%"=="logs" (
    call :show_logs
) else if "%action%"=="status" (
    call :check_services_health
    pause
) else if "%action%"=="help" (
    call :show_help
) else (
    echo %ERROR% Option inconnue: %action%
    call :show_help
)

endlocal