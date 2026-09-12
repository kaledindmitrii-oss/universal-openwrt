@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-to-github.ps1"
if errorlevel 1 (
  echo.
  echo Ошибка публикации. Проверьте GitHub авторизацию и права на репозиторий.
  pause
  exit /b 1
)
pause
