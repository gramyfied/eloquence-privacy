@echo off
echo ========================================
echo   SYSTEME DE TEST LIVEKIT - ELOQUENCE
echo ========================================
echo.

REM Vérifier si Python est installé
python --version >nul 2>&1
if errorlevel 1 (
    echo ERREUR: Python n'est pas installé ou pas dans le PATH
    echo Veuillez installer Python 3.8+ depuis https://python.org
    pause
    exit /b 1
)

REM Afficher la version de Python
echo Python detecte:
python --version
echo.

REM Vérifier si les dépendances sont installées
echo Verification des dependances...
python -c "import livekit" >nul 2>&1
if errorlevel 1 (
    echo Installation des dependances...
    pip install -r requirements.txt
    if errorlevel 1 (
        echo ERREUR: Impossible d'installer les dependances
        pause
        exit /b 1
    )
) else (
    echo Dependances OK
)
echo.

REM Créer le répertoire temporaire
if not exist "temp_audio_test" mkdir temp_audio_test

REM Vérifier la configuration LiveKit
echo Verification de la configuration LiveKit...
if defined LIVEKIT_URL (
    echo URL LiveKit: %LIVEKIT_URL%
) else (
    echo URL LiveKit: ws://localhost:7880 (par defaut)
)

if defined LIVEKIT_API_KEY (
    echo API Key: Definie
) else (
    echo API Key: devkey (par defaut)
)

if defined LIVEKIT_API_SECRET (
    echo API Secret: Definie
) else (
    echo API Secret: secret (par defaut)
)
echo.

REM Menu de sélection
:menu
echo Choisissez un test:
echo 1. Test rapide (20 secondes)
echo 2. Test de base (30 secondes)
echo 3. Test de stress (50 paquets)
echo 4. Test de latence (20 paquets)
echo 5. Suite complete de tests
echo 6. Lancement interactif
echo 7. Quitter
echo.
set /p choice="Votre choix (1-7): "

if "%choice%"=="1" goto quick_test
if "%choice%"=="2" goto basic_test
if "%choice%"=="3" goto stress_test
if "%choice%"=="4" goto latency_test
if "%choice%"=="5" goto full_suite
if "%choice%"=="6" goto interactive
if "%choice%"=="7" goto end
echo Choix invalide, veuillez reessayer.
goto menu

:quick_test
echo.
echo ========================================
echo   TEST RAPIDE (20 secondes)
echo ========================================
python main.py --test basic --duration 20
goto end_test

:basic_test
echo.
echo ========================================
echo   TEST DE BASE (30 secondes)
echo ========================================
python main.py --test basic --duration 30
goto end_test

:stress_test
echo.
echo ========================================
echo   TEST DE STRESS (50 paquets)
echo ========================================
python main.py --test stress --packets 50 --interval 500
goto end_test

:latency_test
echo.
echo ========================================
echo   TEST DE LATENCE (20 paquets)
echo ========================================
python main.py --test latency --packets 20
goto end_test

:full_suite
echo.
echo ========================================
echo   SUITE COMPLETE DE TESTS
echo ========================================
python main.py --all --output livekit_test_results.json
goto end_test

:interactive
echo.
echo ========================================
echo   MODE INTERACTIF
echo ========================================
python run_tests.py
goto end_test

:end_test
echo.
echo ========================================
echo   TEST TERMINE
echo ========================================
echo.
set /p restart="Voulez-vous lancer un autre test? (o/n): "
if /i "%restart%"=="o" goto menu
if /i "%restart%"=="oui" goto menu
if /i "%restart%"=="y" goto menu
if /i "%restart%"=="yes" goto menu

:end
echo.
echo Merci d'avoir utilise le systeme de test LiveKit!
echo Les resultats sont sauvegardes dans le repertoire courant.
echo.
pause