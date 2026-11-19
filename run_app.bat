@echo off
title POS Kasir Launcher
echo ==========================================
echo    Starting POS Kasir System
echo ==========================================

echo [1/2] Starting Flask Backend...
start "Flask Backend (Port 5000)" cmd /k "cd /d %~dp0backend && .\venv\Scripts\python.exe app.py"

timeout /t 2 /nobreak >nul

echo [2/2] Starting Flutter Frontend on Chrome...
start "Flutter Frontend" cmd /k "cd /d %~dp0frontend && C:\Users\ADVAN\flutter\bin\flutter.bat run -d chrome --web-port=8080"

echo.
echo Application started!
