@echo off
setlocal enabledelayedexpansion

REM Script de maintenance Docker robuste pour l'application Eloquence (Version Windows)
REM Automatise le diagnostic, nettoyage, rebuild et vérification des services
REM Auteur: Assistant IA - Maintenance Docker Eloquence
REM Version: 1.0

set "COMPOSE_FILE=docker-compose.yml"
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c%%a%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)
set "LOG_FILE=cleanup_%mydate%_%mytime%.log"
set "SERVICES=livekit whisper-stt piper-tts eloquence-agent api-backend"

REM Variables de comptage
set /a CONTAINERS_REMOVED=0
set /a IMAGES_REMOVED=0
set /a VOLUMES_REMOVED=0
set /a NETWORKS_REMOVED=0
set /a UNHEALTHY_COUNT=0

REM Couleurs (si supportées)
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

REM Fonction de logging améliorée
:log
set "level=%~1"
set "message=%~2"
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set "current_date=%%a %%b %%c"
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set "current_time=%%a:%%b"
set "timestamp=%current_date% %current_time%"

if "%level%"=="SUCCESS" (
    echo %GREEN%[%timestamp%] [%level%] %message%%NC%
) else if "%level%"=="ERROR" (
    echo %RED%[%timestamp%] [%level%] %message%%NC%
) else if "%level%"=="WARNING" (
    echo %YELLOW%[%timestamp%] [%level%] %message%%NC%
) else (
    echo %BLUE%[%timestamp%] [%level%] %message%%NC%
)
echo [%timestamp%] [%level%] %message% >> "%LOG_FILE%"
goto :eof

echo.
echo ================================================================
echo           MAINTENANCE DOCKER - ELOQUENCE COACHING
echo ================================================================
call :log "INFO" "Debut de la maintenance Docker"

REM VERIFICATION DES PREREQUIS
call :log "INFO" "=== VERIFICATION DES PREREQUIS ==="

docker --version >nul 2>&1
if errorlevel 1 (
    call :log "ERROR" "Docker n'est pas installe ou n'est pas dans le PATH"
    goto :error_exit
)

docker-compose --version >nul 2>&1
if errorlevel 1 (
    docker compose version >nul 2>&1
    if errorlevel 1 (
        call :log "ERROR" "Docker Compose n'est pas installe"
        goto :error_exit
    )
)

docker info >nul 2>&1
if errorlevel 1 (
    call :log "ERROR" "Docker daemon n'est pas en cours d'execution"
    call :log "ERROR" "Veuillez demarrer Docker Desktop"
    goto :error_exit
)

if not exist "%COMPOSE_FILE%" (
    call :log "ERROR" "Fichier %COMPOSE_FILE% introuvable"
    goto :error_exit
)

call :log "SUCCESS" "Tous les prerequis sont satisfaits"

REM PHASE 1: DIAGNOSTIC
call :log "INFO" "=== PHASE 1: DIAGNOSTIC ==="

call :log "INFO" "Liste de tous les conteneurs:"
echo === CONTENEURS === >> "%LOG_FILE%"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" >> "%LOG_FILE%"

call :log "INFO" "Usage des ressources systeme:"
echo === RESSOURCES === >> "%LOG_FILE%"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" >> "%LOG_FILE%"

call :log "INFO" "Recuperation des logs des services cles..."
for %%s in (%SERVICES%) do (
    docker-compose ps -q %%s >nul 2>&1
    if not errorlevel 1 (
        call :log "DEBUG" "Logs pour le service: %%s"
        echo === LOGS %%s === >> "%LOG_FILE%"
        docker-compose logs --tail=100 %%s >> "%LOG_FILE%" 2>&1
        echo === FIN LOGS %%s === >> "%LOG_FILE%"
    )
)

call :log "SUCCESS" "Diagnostic termine"

REM PHASE 2: NETTOYAGE
call :log "INFO" "=== PHASE 2: NETTOYAGE DOCKER ==="

call :log "INFO" "Arret des services en cours..."
docker-compose down --remove-orphans >> "%LOG_FILE%" 2>&1

call :log "INFO" "Nettoyage des conteneurs arretes..."
for /f "tokens=*" %%i in ('docker container prune --force 2^>^&1') do (
    echo %%i >> "%LOG_FILE%"
    echo %%i | findstr /C:"deleted" >nul && set /a CONTAINERS_REMOVED+=1
)

call :log "INFO" "Nettoyage de toutes les images non utilisees..."
for /f "tokens=*" %%i in ('docker image prune --all --force 2^>^&1') do (
    echo %%i >> "%LOG_FILE%"
    echo %%i | findstr /C:"deleted" >nul && set /a IMAGES_REMOVED+=1
)

call :log "INFO" "Nettoyage des volumes non utilises..."
for /f "tokens=*" %%i in ('docker volume prune --force 2^>^&1') do (
    echo %%i >> "%LOG_FILE%"
    echo %%i | findstr /C:"deleted" >nul && set /a VOLUMES_REMOVED+=1
)

call :log "INFO" "Nettoyage des reseaux non utilises..."
for /f "tokens=*" %%i in ('docker network prune --force 2^>^&1') do (
    echo %%i >> "%LOG_FILE%"
    echo %%i | findstr /C:"deleted" >nul && set /a NETWORKS_REMOVED+=1
)

call :log "SUCCESS" "Nettoyage Docker termine"

REM PHASE 3: REBUILD
call :log "INFO" "=== PHASE 3: RECONSTRUCTION DES IMAGES ==="

call :log "INFO" "Reconstruction des images sans cache..."
docker-compose build --no-cache >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :log "ERROR" "Echec de la reconstruction des images"
    goto :error_exit
)
call :log "SUCCESS" "Reconstruction des images terminee avec succes"

REM PHASE 4: REDEMARRAGE
call :log "INFO" "=== PHASE 4: REDEMARRAGE DES SERVICES ==="

call :log "INFO" "Demarrage des services en mode detache..."
docker-compose up -d >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :log "ERROR" "Echec du demarrage des services"
    goto :error_exit
)
call :log "SUCCESS" "Services demarres avec succes"

call :log "INFO" "Attente de 10 secondes pour la stabilisation des services..."
timeout /t 10 /nobreak >nul

REM PHASE 5: VERIFICATION DE SANTE
call :log "INFO" "=== PHASE 5: VERIFICATION DE LA SANTE DES SERVICES ==="

for %%s in (%SERVICES%) do (
    call :log "INFO" "Verification du service: %%s"
    
    docker-compose ps %%s | findstr "Up" >nul
    if errorlevel 1 (
        call :log "ERROR" "Service %%s n'est pas en cours d'execution"
        set /a UNHEALTHY_COUNT+=1
        echo === LOGS ERREUR %%s === >> "%LOG_FILE%"
        docker-compose logs --tail=20 %%s >> "%LOG_FILE%" 2>&1
        echo === FIN LOGS ERREUR %%s === >> "%LOG_FILE%"
    ) else (
        call :log "SUCCESS" "Service %%s: SAIN"
    )
)

if !UNHEALTHY_COUNT! gtr 0 (
    call :log "ERROR" "!UNHEALTHY_COUNT! service(s) en etat non sain - Echec de la maintenance"
    goto :error_exit
)

REM PHASE 6: RAPPORT FINAL
call :log "INFO" "=== RAPPORT FINAL ==="

echo.
echo ================================================================
echo                    RAPPORT DE MAINTENANCE DOCKER
echo ================================================================
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set "report_date=%%a %%b %%c"
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set "report_time=%%a:%%b"
echo Heure de fin: %report_date% %report_time%
echo.
echo NETTOYAGE EFFECTUE:
echo • Conteneurs supprimes: %CONTAINERS_REMOVED%
echo • Images supprimees: %IMAGES_REMOVED%
echo • Volumes supprimes: %VOLUMES_REMOVED%
echo • Reseaux supprimes: %NETWORKS_REMOVED%
echo.
echo SERVICES:
for %%s in (%SERVICES%) do (
    docker-compose ps %%s | findstr "Up" >nul
    if errorlevel 1 (
        echo • %%s: %RED%ARRETE%NC%
    ) else (
        echo • %%s: %GREEN%ACTIF%NC%
    )
)
echo.
echo REBUILD: %GREEN%TERMINE%NC%
echo REDEMARRAGE: %GREEN%TERMINE%NC%
echo.
echo Log detaille: %LOG_FILE%
echo ================================================================

call :log "SUCCESS" "Maintenance Docker terminee avec succes!"
call :log "INFO" "Services disponibles:"
call :log "INFO" "  • LiveKit Server: http://localhost:7880"
call :log "INFO" "  • Whisper STT: http://localhost:8001"
call :log "INFO" "  • Piper TTS: http://localhost:5002"
call :log "INFO" "  • API Backend: http://localhost:8000"

echo.
echo %GREEN%Maintenance terminee avec succes!%NC%
echo Appuyez sur une touche pour continuer...
pause >nul
exit /b 0

:error_exit
call :log "ERROR" "Maintenance echouee - Consultez le fichier de log: %LOG_FILE%"
echo.
echo %RED%Maintenance echouee!%NC%
echo Consultez le fichier de log: %LOG_FILE%
echo Appuyez sur une touche pour continuer...
pause >nul
exit /b 1