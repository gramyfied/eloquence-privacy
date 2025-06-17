@echo off
setlocal enabledelayedexpansion

REM Script de maintenance Docker robuste pour l'application Eloquence (Version Windows)
REM Automatise le diagnostic, nettoyage, rebuild et vérification des services
REM Auteur: Assistant IA - Maintenance Docker Eloquence
REM Version: 1.0

set "COMPOSE_FILE=docker-compose.yml"
set "LOG_FILE=cleanup_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
set "SERVICES=livekit whisper-stt piper-tts eloquence-agent api-backend"

REM Variables de comptage
set /a CONTAINERS_REMOVED=0
set /a IMAGES_REMOVED=0
set /a VOLUMES_REMOVED=0
set /a NETWORKS_REMOVED=0

REM Fonction de logging - Declaration deplacee a la fin du script

echo ================================================================
echo           MAINTENANCE DOCKER - ELOQUENCE COACHING
echo                    Debut: %date% %time%
echo ================================================================

REM Vérification des prérequis
call :log "INFO" "Verification des prerequis Docker et Docker-Compose."

docker --version >nul 2>&1
if errorlevel 1 (
    call :log "ERROR" "Docker n'est pas installe ou n'est pas dans le PATH"
    exit /b 1
)

docker-compose --version >nul 2>&1
if errorlevel 1 (
    docker compose version >nul 2>&1
    if errorlevel 1 (
        call :log "ERROR" "Docker Compose n'est pas installe"
        exit /b 1
    )
)

docker info >nul 2>&1
if errorlevel 1 (
    call :log "ERROR" "Docker daemon n'est pas en cours d'execution"
    exit /b 1
)

if not exist "%COMPOSE_FILE%" (
    call :log "ERROR" "Fichier %COMPOSE_FILE% introuvable"
    exit /b 1
)

call :log "SUCCESS" "Tous les prerequis sont satisfaits"

REM PHASE 1: DIAGNOSTIC
call :log "INFO" "=== PHASE 1: DIAGNOSTIC ==="

call :log "INFO" "Liste de tous les conteneurs:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" >> "%LOG_FILE%"

call :log "INFO" "Usage des ressources systeme:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" >> "%LOG_FILE%"

call :log "INFO" "Recuperation des logs des services cles..."
for %%s in (%SERVICES%) do (
    docker-compose ps -q %%s >nul 2>&1
    if not errorlevel 1 (
        call :log "DEBUG" "Logs pour le service: %%s"
        echo === LOGS %%s ===
        docker-compose logs --tail=100 %%s
        echo === FIN LOGS %%s ===
        echo === LOGS %%s === >> "%LOG_FILE%"
        docker-compose logs --tail=100 %%s >> "%LOG_FILE%" 2>&1
        echo === FIN LOGS %%s === >> "%LOG_FILE%"
    )
)

call :log "SUCCESS" "Diagnostic termine"

REM PHASE 2: NETTOYAGE
call :log "INFO" "=== PHASE 2: NETTOYAGE DOCKER ==="

call :log "INFO" "Arret des services en cours..."
docker-compose down --remove-orphans

call :log "INFO" "Nettoyage des conteneurs arretes..."
for /f "tokens=*" %%a in ('docker container prune --force ^| findstr /i "Total reclaimed space:"') do (
    set "CONTAINERS_PRUNED=%%a"
)
call :log "INFO" "Nettoyage des conteneurs arretes: !CONTAINERS_PRUNED!"

call :log "INFO" "Nettoyage de toutes les images non utilisees..."
for /f "tokens=*" %%a in ('docker image prune --all --force ^| findstr /i "Total reclaimed space:"') do (
    set "IMAGES_PRUNED=%%a"
)
call :log "INFO" "Nettoyage des images: !IMAGES_PRUNED!"

call :log "INFO" "Nettoyage des volumes non utilises..."
for /f "tokens=*" %%a in ('docker volume prune --force ^| findstr /i "Total reclaimed space:"') do (
    set "VOLUMES_PRUNED=%%a"
)
call :log "INFO" "Nettoyage des volumes: !VOLUMES_PRUNED!"

call :log "INFO" "Nettoyage des reseaux non utilises..."
for /f "tokens=*" %%a in ('docker network prune --force ^| findstr /i "Total reclaimed space:"') do (
    set "NETWORKS_PRUNED=%%a"
)
call :log "INFO" "Nettoyage des reseaux: !NETWORKS_PRUNED!"

call :log "SUCCESS" "Nettoyage Docker termine"

REM PHASE 3: REBUILD
call :log "INFO" "=== PHASE 3: RECONSTRUCTION DES IMAGES ==="

call :log "INFO" "Reconstruction des images sans cache..."
docker-compose build --no-cache || (
    call :log "ERROR" "Echec de la reconstruction des images. Veuillez consulter les logs ci-dessus pour le detail."
    exit /b 1
)
call :log "SUCCESS" "Reconstruction des images terminee avec succes"

REM PHASE 4: REDEMARRAGE
call :log "INFO" "=== PHASE 4: REDEMARRAGE DES SERVICES ==="

call :log "INFO" "Verification que chaque service a 'restart: on-failure:5'..."
call :check_restart_policy

call :log "INFO" "Demarrage des services en mode detache..."
docker-compose up -d
if errorlevel 1 (
    call :log "ERROR" "Echec du demarrage des services"
    exit /b 1
)
call :log "SUCCESS" "Services demarres avec succes"

call :log "INFO" "Attente de 10 secondes pour la stabilisation des services..."
timeout /t 10 /nobreak >nul

REM PHASE 5: VERIFICATION DE SANTE
call :log "INFO" "=== PHASE 5: VERIFICATION DE LA SANTE DES SERVICES ==="

set "UNHEALTHY_SERVICES_LIST="
for /f "tokens=*" %%x in ('docker-compose ps --services --filter "status=unhealthy"') do (
    set "UNHEALTHY_SERVICES_LIST=!UNHEALTHY_SERVICES-LIST! %%x"
)

if defined UNHEALTHY_SERVICES_LIST (
    call :log "ERROR" "Les services suivants sont unhealthy:!UNHEALTHY_SERVICES_LIST!"
    exit /b 1
) else (
    call :log "SUCCESS" "Tous les services sont sains."
)

REM RAPPORT FINAL
call :log "INFO" "=== RAPPORT FINAL ==="

echo.
echo ================================================================
echo                    RAPPORT DE MAINTENANCE DOCKER
echo ================================================================
echo Heure de fin: %date% %time%
echo.
echo NETTOYAGE EFFECTUE:
echo • Conteneurs: !CONTAINERS_PRUNED!
echo • Images: !IMAGES_PRUNED!
echo • Volumes: !VOLUMES_PRUNED!
echo • Reseaux: !NETWORKS_PRUNED!
echo.
echo SERVICES:
for %%s in (%SERVICES%) do (
    set "service_status=ARRETE"
    for /f "tokens=*" %%x in ('docker-compose ps %%s --format "{{.State}}" 2^>nul') do (
        if "%%x"=="running" set "service_status=ACTIF"
    )
    echo • %%s: !service_status!
)
echo.
echo REBUILD: TERMINE
echo REDEMARRAGE: TERMINE
echo.
echo Log detaille: %LOG_FILE%
echo ================================================================

call :log "SUCCESS" "Maintenance Docker terminee avec succes!"
call :log "INFO" "Services disponibles:"
call :log "INFO" "  • LiveKit Server: http://localhost:7880"
call :log "INFO" "  • Whisper STT: http://localhost:8001"
call :log "INFO" "  • Piper TTS: http://localhost:5002"
call :log "INFO" "  • API Backend: http://localhost:8000"

:check_restart_policy
    set "ALL_SERVICES_HAVE_RESTART=true"
    for %%s in (%SERVICES%) do (
        set "SERVICE_HAS_RESTART=false"
        set "current_service=%%s"
        
        call :log "DEBUG" "Verification de 'restart: on-failure:5' pour service '!current_service!'."

        rem Simple check: look for the service name and restart policy in the same file
        rem This is not perfect YAML parsing but it's the best that can be done with simple Batch
        findstr /C:"%current_service%:" "%COMPOSE_FILE%" >nul && (
            findstr /C:"restart: on-failure:5" "%COMPOSE_FILE%" >nul && (
                set "SERVICE_HAS_RESTART=true"
            )
        )
        
        if "!SERVICE_HAS_RESTART!"=="false" (
            call :log "WARNING" "Service '!current_service!' n'a PAS 'restart: on-failure:5'. Veuillez l'ajouter."
            set "ALL_SERVICES_HAVE_RESTART=false"
        ) else (
            call :log "INFO" "Service '!current_service!' a 'restart: on-failure:5'."
        )
    )
    if /i "!ALL_SERVICES_HAVE_RESTART!"=="false" (
        call :log "WARNING" "Certains services n'ont pas 'restart: on-failure:5'. La robustesse du redemarrage est reduite."
    ) else (
        call :log "SUCCESS" "Tous les services ont 'restart: on-failure:5'."
    )
goto :eof

REM Fonction de logging
:log
set "timestamp=%date% %time%"
echo [%timestamp%] [%1] %2
echo [%timestamp%] [%1] %2 >> "%LOG_FILE%"
goto :eof

echo.
pause
exit /b 0