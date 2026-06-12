@echo off
chcp 65001 >nul
title Mobile Flutter Chat - Start All Services

echo ========================================
echo   Mobile Flutter Chat - Khoi dong
echo ========================================
echo.

echo [1/2] Dang khoi dong Backend (port 3000)...
start "Backend - Node.js" cmd /k "cd /d %~dp0backend && npm run dev"

echo [2/2] Dang khoi dong STT Service (port 5000)...
start "STT - Python AI" cmd /k "cd /d %~dp0speech_to_text && python app.py"

echo.
echo ========================================
echo   Tat ca service da khoi dong!
echo   - Backend:  http://localhost:3000
echo   - STT AI:   http://localhost:5000
echo ========================================
echo.
echo Dong cua so nay khong anh huong cac service.
echo Nhan phim bat ky de dong...
pause >nul
