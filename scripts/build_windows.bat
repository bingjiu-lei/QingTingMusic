@echo off
setlocal

cd /d "%~dp0.."

echo [1/3] Closing QingTingMusic if it is running...
taskkill /IM qing_ting_music.exe /T /F >nul 2>&1

echo [2/3] Building Windows Release...
call flutter build windows --release --no-pub
if errorlevel 1 (
    echo.
    echo Build failed. Check the error messages above.
    pause
    exit /b 1
)

echo.
echo [3/3] Build completed:
echo %cd%\build\windows\x64\runner\Release\qing_ting_music.exe
pause
exit /b 0
