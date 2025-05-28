@echo off
title Test LiveKit - Demarrage Rapide
color 0A

echo.
echo  ██╗     ██╗██╗   ██╗███████╗██╗  ██╗██╗████████╗
echo  ██║     ██║██║   ██║██╔════╝██║ ██╔╝██║╚══██╔══╝
echo  ██║     ██║██║   ██║█████╗  █████╔╝ ██║   ██║   
echo  ██║     ██║╚██╗ ██╔╝██╔══╝  ██╔═██╗ ██║   ██║   
echo  ███████╗██║ ╚████╔╝ ███████╗██║  ██╗██║   ██║   
echo  ╚══════╝╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝   ╚═╝   
echo.
echo           TEST SYSTEME - COACHING VOCAL
echo.
echo ========================================

REM Aller dans le bon répertoire
cd /d "%~dp0"

echo 🔍 Verification rapide...
echo.

REM Test Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ PROBLEME: Python non trouvé
    echo.
    echo 💡 SOLUTION:
    echo 1. Installez Python depuis https://python.org
    echo 2. Cochez "Add Python to PATH" lors de l'installation
    echo 3. Redémarrez ce script
    echo.
    pause
    exit /b 1
)

echo ✅ Python trouvé
python --version

REM Installation express des dépendances
echo.
echo 📦 Installation des dépendances...
pip install livekit-server-sdk-python pyttsx3 colorama --quiet --disable-pip-version-check

echo.
echo 🧪 Lancement du test de diagnostic...
echo.
python test_simple.py

echo.
echo ========================================
echo.
if errorlevel 0 (
    echo ✅ Test terminé!
    echo.
    echo 🚀 Prochaines étapes:
    echo.
    echo 1. Pour un test rapide:
    echo    python test_simple.py
    echo.
    echo 2. Pour des tests complets:
    echo    python run_tests.py
    echo.
    echo 3. Pour le menu complet:
    echo    test_livekit.bat
    echo.
) else (
    echo ❌ Des problèmes ont été détectés
    echo.
    echo 🔧 Consultez DEPANNAGE.md pour les solutions
    echo.
    echo 🛠️ Ou lancez diagnostic.bat pour plus d'infos
    echo.
)

echo Appuyez sur une touche pour fermer...
pause >nul