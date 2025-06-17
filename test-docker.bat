@echo off
echo ================================================================
echo           TEST DE L'ENVIRONNEMENT DOCKER
echo ================================================================

echo.
echo Verification de Docker...
docker --version
if errorlevel 1 (
    echo ERREUR: Docker n'est pas installe ou accessible
    pause
    exit /b 1
)

echo.
echo Verification de Docker Compose...
docker-compose --version
if errorlevel 1 (
    echo Tentative avec 'docker compose'...
    docker compose version
    if errorlevel 1 (
        echo ERREUR: Docker Compose n'est pas installe
        pause
        exit /b 1
    )
)

echo.
echo Verification du daemon Docker...
docker info >nul 2>&1
if errorlevel 1 (
    echo ERREUR: Docker daemon n'est pas en cours d'execution
    echo Veuillez demarrer Docker Desktop
    pause
    exit /b 1
)

echo.
echo Verification du fichier docker-compose.yml...
if not exist "docker-compose.yml" (
    echo ERREUR: Fichier docker-compose.yml introuvable
    pause
    exit /b 1
)

echo.
echo ================================================================
echo           ETAT ACTUEL DES CONTENEURS
echo ================================================================
docker ps -a

echo.
echo ================================================================
echo           ETAT ACTUEL DES SERVICES COMPOSE
echo ================================================================
docker-compose ps

echo.
echo ================================================================
echo           USAGE DES RESSOURCES
echo ================================================================
docker stats --no-stream

echo.
echo ================================================================
echo Tous les tests sont passes!
echo L'environnement Docker est pret pour la maintenance.
echo ================================================================

pause