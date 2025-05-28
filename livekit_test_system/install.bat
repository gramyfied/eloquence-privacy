@echo off
echo ========================================
echo   INSTALLATION SYSTEME TEST LIVEKIT
echo ========================================
echo.

REM Vérifier si Python est installé
python --version >nul 2>&1
if errorlevel 1 (
    echo ERREUR: Python n'est pas installé
    echo.
    echo Veuillez installer Python 3.8+ depuis:
    echo https://www.python.org/downloads/
    echo.
    echo Assurez-vous de cocher "Add Python to PATH" lors de l'installation
    pause
    exit /b 1
)

echo Python detecte:
python --version
echo.

REM Vérifier pip
pip --version >nul 2>&1
if errorlevel 1 (
    echo ERREUR: pip n'est pas disponible
    echo Veuillez reinstaller Python avec pip inclus
    pause
    exit /b 1
)

echo pip detecte:
pip --version
echo.

REM Mettre à jour pip
echo Mise a jour de pip...
python -m pip install --upgrade pip

REM Installer les dépendances
echo.
echo Installation des dependances...
echo.
pip install -r requirements.txt

if errorlevel 1 (
    echo.
    echo ERREUR: Impossible d'installer certaines dependances
    echo.
    echo Solutions possibles:
    echo 1. Verifiez votre connexion internet
    echo 2. Executez en tant qu'administrateur
    echo 3. Utilisez: pip install --user -r requirements.txt
    echo.
    pause
    exit /b 1
)

REM Créer les répertoires nécessaires
echo.
echo Creation des repertoires...
if not exist "temp_audio_test" mkdir temp_audio_test
if not exist "logs" mkdir logs
if not exist "results" mkdir results

REM Tester l'installation
echo.
echo Test de l'installation...
python -c "import livekit; import pyttsx3; import colorama; print('✅ Toutes les dependances sont installees')"

if errorlevel 1 (
    echo.
    echo ERREUR: Certaines dependances ne fonctionnent pas correctement
    echo Veuillez verifier les messages d'erreur ci-dessus
    pause
    exit /b 1
)

REM Copier la configuration exemple
if not exist "config.json" (
    echo.
    echo Creation du fichier de configuration...
    copy config_example.json config.json
    echo Fichier config.json cree depuis l'exemple
)

echo.
echo ========================================
echo   INSTALLATION TERMINEE AVEC SUCCES!
echo ========================================
echo.
echo Prochaines etapes:
echo.
echo 1. Demarrez votre serveur LiveKit:
echo    livekit-server --dev
echo.
echo 2. Ou avec Docker:
echo    docker run --rm -p 7880:7880 -p 7881:7881 -p 7882:7882/udp livekit/livekit-server --dev
echo.
echo 3. Modifiez config.json si necessaire
echo.
echo 4. Lancez les tests:
echo    test_livekit.bat
echo.
echo 5. Ou directement:
echo    python run_tests.py
echo.
pause