@echo off
setlocal EnableExtensions

rem A double-click build launches the fresh executable after a successful
rem build and then exits. AI/CI callers can pass --no-pause to get a
rem non-interactive build-only command with a reliable exit code.
set "NO_PAUSE=0"
set "OPEN_AFTER_BUILD=1"
if /I "%~1"=="--no-pause" (
    set "NO_PAUSE=1"
    set "OPEN_AFTER_BUILD=0"
)

cd /d "%~dp0.."
if errorlevel 1 (
    echo [QINGTING_BUILD] STATUS=failed STEP=project_root EXIT_CODE=1
    goto :failure
)

set "ARTIFACT=%cd%\build\windows\x64\runner\Release\qing_ting_music.exe"
echo [QINGTING_BUILD] STATUS=started PROJECT=%cd%

echo [1/3] Closing QingTingMusic if it is running...
taskkill /IM qing_ting_music.exe /T /F >nul 2>&1

echo [2/3] Building Windows Release...
call flutter build windows --release --no-pub
set "BUILD_EXIT=%ERRORLEVEL%"
if not "%BUILD_EXIT%"=="0" (
    echo [QINGTING_BUILD] STATUS=failed STEP=flutter_build EXIT_CODE=%BUILD_EXIT%
    goto :failure
)

if not exist "%ARTIFACT%" (
    echo [QINGTING_BUILD] STATUS=failed STEP=artifact_check EXIT_CODE=2 ARTIFACT=%ARTIFACT%
    goto :failure
)

echo.
echo [3/3] Build completed:
echo %ARTIFACT%
echo [QINGTING_BUILD] STATUS=success EXIT_CODE=0 ARTIFACT=%ARTIFACT%
if "%OPEN_AFTER_BUILD%"=="1" (
    echo [QINGTING_BUILD] STATUS=launching ARTIFACT=%ARTIFACT%
    start "" "%ARTIFACT%"
)
exit /b 0

:failure
if "%NO_PAUSE%"=="0" pause
exit /b 1
