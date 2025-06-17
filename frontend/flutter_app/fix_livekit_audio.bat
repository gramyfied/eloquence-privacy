@echo off
echo ===================================
echo Fix LiveKit Audio Issues on Android
echo ===================================
echo.

echo [1/5] Nettoyage du projet Flutter...
call flutter clean
if errorlevel 1 goto error

echo.
echo [2/5] Récupération des dépendances...
call flutter pub get
if errorlevel 1 goto error

echo.
echo [3/5] Nettoyage du cache Gradle Android...
cd android
call gradlew clean
if errorlevel 1 goto error
cd ..

echo.
echo [4/5] Construction de l'APK de test...
call flutter build apk --debug
if errorlevel 1 goto error

echo.
echo [5/5] Installation et lancement de l'application de test...
call flutter run lib/test_livekit_audio_fix.dart
if errorlevel 1 goto error

echo.
echo ===================================
echo Succès! L'application de test est lancée.
echo ===================================
echo.
echo Instructions:
echo 1. Utilisez le bouton diagnostic (bug) pour vérifier le système
echo 2. Connectez-vous à LiveKit
echo 3. Testez l'enregistrement audio
echo.
goto end

:error
echo.
echo ===================================
echo ERREUR: Une étape a échoué!
echo ===================================
echo Vérifiez les messages d'erreur ci-dessus.
echo.

:end
pause