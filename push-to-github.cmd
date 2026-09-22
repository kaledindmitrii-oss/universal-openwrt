@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-to-github.ps1"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo.
    echo Publish failed. Exit code: %RC%
    echo Check Git installation, GitHub login, and repository permissions.
)
echo.
pause
exit /b %RC%
