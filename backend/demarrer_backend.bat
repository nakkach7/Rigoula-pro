@echo off
title Rigoula Backend Python
color 0A
echo.
echo  ================================
echo   RIGOULA - Backend Python
echo  ================================
echo.

:: Aller dans le dossier du script
cd /d "%~dp0"

:: Vérifier que Python est installé
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] Python n'est pas installe ou pas dans le PATH
    echo Installe Python depuis https://python.org
    pause
    exit /b
)

:: Vérifier que serviceAccountKey.json existe
if not exist "serviceAccountKey.json" (
    echo [ERREUR] Fichier serviceAccountKey.json introuvable !
    echo Place-le dans le meme dossier que ce script.
    pause
    exit /b
)

:: Installer les dépendances si besoin
echo Installation des dependances...
pip install firebase-admin --quiet

echo.
echo  Backend demarre... (Ctrl+C pour arreter)
echo  Les alertes seront envoyees via FCM
echo.
echo  ================================
echo.

python main.py

:: Si le script se termine (erreur ou Ctrl+C)
echo.
echo Backend arrete.
pause
