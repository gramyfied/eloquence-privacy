@echo off
echo ========================================
echo   DIAGNOSTIC SYSTEME TEST LIVEKIT
echo ========================================
echo.

REM Vérifier Python
echo 1. VERIFICATION PYTHON
echo ------------------------
python --version 2>nul
if errorlevel 1 (
    echo ❌ Python non trouvé
    echo.
    echo SOLUTION: Installez Python depuis https://python.org
    echo Assurez-vous de cocher "Add Python to PATH"
    goto end
) else (
    echo ✅ Python trouvé:
    python --version
)
echo.

REM Vérifier pip
echo 2. VERIFICATION PIP
echo -------------------
pip --version 2>nul
if errorlevel 1 (
    echo ❌ pip non trouvé
    echo.
    echo SOLUTION: Réinstallez Python avec pip inclus
    goto end
) else (
    echo ✅ pip trouvé:
    pip --version
)
echo.

REM Vérifier les dépendances
echo 3. VERIFICATION DEPENDANCES
echo ---------------------------
python -c "import sys; print('Python path:', sys.executable)" 2>nul

echo Vérification livekit...
python -c "import livekit; print('✅ livekit OK')" 2>nul
if errorlevel 1 (
    echo ❌ livekit manquant
    echo Installation...
    pip install livekit-server-sdk-python
)

echo Vérification pyttsx3...
python -c "import pyttsx3; print('✅ pyttsx3 OK')" 2>nul
if errorlevel 1 (
    echo ❌ pyttsx3 manquant
    echo Installation...
    pip install pyttsx3
)

echo Vérification colorama...
python -c "import colorama; print('✅ colorama OK')" 2>nul
if errorlevel 1 (
    echo ❌ colorama manquant
    echo Installation...
    pip install colorama
)
echo.

REM Test simple
echo 4. TEST SIMPLE
echo --------------
echo Lancement du test de diagnostic...
python test_simple.py
echo.

REM Vérifier LiveKit server
echo 5. VERIFICATION SERVEUR LIVEKIT
echo -------------------------------
echo Test de connexion au serveur LiveKit...
curl -s http://localhost:7880 >nul 2>&1
if errorlevel 1 (
    echo ❌ Serveur LiveKit non accessible sur localhost:7880
    echo.
    echo SOLUTIONS:
    echo 1. Démarrer LiveKit server:
    echo    livekit-server --dev
    echo.
    echo 2. Ou avec Docker:
    echo    docker run --rm -p 7880:7880 -p 7881:7881 -p 7882:7882/udp livekit/livekit-server --dev
    echo.
    echo 3. Vérifier que le port 7880 n'est pas bloqué
) else (
    echo ✅ Serveur LiveKit accessible
)
echo.

:end
echo ========================================
echo   DIAGNOSTIC TERMINE
echo ========================================
echo.
echo Si tous les tests passent, vous pouvez lancer:
echo   python test_simple.py
echo   python run_tests.py
echo   test_livekit.bat
echo.
pause