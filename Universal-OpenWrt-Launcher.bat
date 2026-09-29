@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
cd /d "%~dp0"
set "ROOT=%~dp0"
set "VERSION="
set "ROUTER=192.168.1.1"
set "GH_STATUS=UNKNOWN"
set "GH_MIRROR=https://cdn.jsdelivr.net/gh/kaledindmitrii-oss/universal-openwrt@main/"
title Universal OpenWrt - Launcher

:START
call :CHECK_WINDOWS || goto FAIL
call :READ_VERSION || goto FAIL
call :CHECK_PROJECT || goto FAIL
call :GITHUB_PREFLIGHT
title Universal OpenWrt v!VERSION! - Launcher

goto MENU

:MENU
call :HEADER
call :SHOW_STATUS
echo.
echo  [1] Мастер диагностики и точечного восстановления
echo [2] Диагностика отдельного сервиса
echo [3] Проверить роутер без изменений
echo [4] Установить пакеты IPK/APK + LuCI
echo [5] Скопировать проект на роутер
echo [6] Запустить полный установщик
echo [7] Открыть SSH-консоль
echo [8] MASTER / экспертный режим
echo [9] Повторить локальную проверку
echo [10] Проверить release, архив и версии
echo [0] Выход
echo.
set "MODE="
set /p "MODE=Введите номер [1]: "
if not defined MODE set "MODE=1"
if "%MODE%"=="0" goto EXIT
if "%MODE%"=="1" goto DIAGNOSE
if "%MODE%"=="2" goto SERVICE_DIAGNOSE
if "%MODE%"=="3" goto VERIFY
if "%MODE%"=="4" goto PACKAGES
if "%MODE%"=="5" goto UPLOAD_ONLY
if "%MODE%"=="6" goto INSTALL
if "%MODE%"=="7" goto SSH
if "%MODE%"=="8" goto ADVANCED
if "%MODE%"=="9" goto RECHECK
if "%MODE%"=="10" goto RELEASE_CHECK
call :ERROR "Неверный пункт меню. Введите число от 0 до 10."
goto MENU

:DIAGNOSE
call :CONNECT || goto FAIL
call :UPLOAD || goto FAIL
call :CHOOSE_SERVICE || goto FINISH
call :RUN_REMOTE "--ai-diagnose !SERVICE!"
if errorlevel 1 goto FINISH
call :INFO "Диагностика завершена."
set "RECOVER="
set /p "RECOVER=Запустить безопасный подбор с проверкой и откатом? [Y/N]: "
if /I "!RECOVER!"=="Y" call :RUN_REMOTE "--ai-apply !SERVICE!"
goto FINISH

:SERVICE_DIAGNOSE
call :CONNECT || goto FAIL
call :UPLOAD || goto FAIL
call :CHOOSE_SERVICE || goto FINISH
call :RUN_REMOTE "--ai-diagnose !SERVICE!"
goto FINISH

:VERIFY
call :CONNECT || goto FAIL
call :UPLOAD || goto FAIL
call :RUN_REMOTE "--verify"
goto FINISH

:PACKAGES
call :CONNECT || goto FAIL
call :UPLOAD || goto FAIL
call :SECTION "УСТАНОВКА ПАКЕТОВ"
echo Определяю пакетный менеджер роутера...
ssh -t -o ConnectTimeout=10 root@%ROUTER% "VERSION=!VERSION!; if command -v apk >/dev/null 2>&1; then echo [PACKAGE] OpenWrt APK; apk --allow-untrusted add /tmp/universal-openwrt/assets/apk/universal-openwrt-%VERSION%-r1.apk /tmp/universal-openwrt/assets/apk/luci-app-universal-openwrt-%VERSION%-r1.apk; elif command -v opkg >/dev/null 2>&1; then echo [PACKAGE] OpenWrt OPKG; opkg install /tmp/universal-openwrt/assets/ipk/universal-openwrt_%VERSION%-1_all.ipk /tmp/universal-openwrt/assets/ipk/luci-app-universal-openwrt_%VERSION%-1_all.ipk; else echo [ERROR] Не найден apk/opkg; exit 127; fi"
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" goto FAIL
ssh -t -o ConnectTimeout=10 root@%ROUTER% "/etc/init.d/rpcd restart 2>/dev/null || true; /etc/init.d/uhttpd restart 2>/dev/null || true; /usr/sbin/universal-openwrt --self-check"
set "RC=!ERRORLEVEL!"
echo.
echo Код проверки после установки: !RC!
if not "!RC!"=="0" goto FAIL
goto FINISH

:UPLOAD_ONLY
call :CONNECT || goto FAIL
call :UPLOAD || goto FAIL
call :INFO "Проект скопирован в /tmp/universal-openwrt."
goto FINISH

:INSTALL
call :CONNECT || goto FAIL
call :UPLOAD || goto FAIL
call :SECTION "ПОЛНЫЙ УСТАНОВЩИК"
echo Запускаю установщик на роутере...
ssh -t -o ConnectTimeout=10 root@%ROUTER% "cd /tmp/universal-openwrt && chmod +x installer/install.sh && ./installer/install.sh"
set "RC=!ERRORLEVEL!"
echo.
echo Код установщика: !RC!
if not "!RC!"=="0" goto FAIL
goto FINISH

:SSH
call :CONNECT || goto FAIL
call :SECTION "SSH-КОНСОЛЬ"
echo Подключение к root@%ROUTER%.
echo Для выхода из SSH выполните: exit
echo.
ssh -t root@%ROUTER%
goto FINISH

:RECHECK
call :CHECK_WINDOWS || goto FAIL
call :CHECK_PROJECT || goto FAIL
call :READ_VERSION || goto FAIL
call :GITHUB_PREFLIGHT
call :INFO "Локальная проверка завершена."
goto FINISH

:RELEASE_CHECK
call :CHECK_WINDOWS || goto FAIL
call :CHECK_PROJECT || goto FAIL
call :READ_VERSION || goto FAIL
call :GITHUB_PREFLIGHT
call :SECTION "ПРОВЕРКА RELEASE"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$v=(Get-Content -LiteralPath '%ROOT%VERSION' -Raw).Trim(); Write-Host '[CHECK] Version:' $v; $files=Get-ChildItem -LiteralPath '%ROOT%' -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\' -and $_.Extension -notin '.ipk','.apk','.zip','.gz','.tar','.png','.jpg','.jpeg','.webp','.gif' }; $bad=$files | Select-String -Pattern '30\.2\.(?:[0-9]|1[0-8])\b' -AllMatches; if($bad){$bad | ForEach-Object { Write-Host ('STALE: ' + $_.Path + ':' + $_.LineNumber + ': ' + $_.Line.Trim()) }; exit 1}; $z=Get-ChildItem -LiteralPath '%ROOT%' -Filter 'universal-openwrt-*.zip' -File | Select-Object -First 1; if(-not $z){Write-Host '[WARN] Локальный ZIP рядом с проектом не найден — это не ошибка исходников.'} else {Write-Host '[OK] ZIP:' $z.Name '(' $z.Length 'bytes)'}; Write-Host '[OK] Release check completed.'"
if errorlevel 1 goto FAIL
goto FINISH

:ADVANCED
call :CONNECT || goto FAIL
:ADVANCED_MENU
call :HEADER
call :SECTION "MASTER / ЭКСПЕРТНЫЙ РЕЖИМ"
echo Здесь доступны технические операции. Обычный режим их не показывает.
echo.
echo  [1] Состояние модулей и health-score
echo [2] Очереди стратегий модулей
echo [3] Полный benchmark сервисных групп
echo [4] Адаптивная автонастройка
echo [5] Предиктивный анализ
echo [6] Обновить ресурсы
echo [7] Откатить последнее изменение
echo [8] Полная диагностика AI
echo [9] GitHub / source status
echo [10] Диагностика WireGuard и белого IP
echo [11] Состояние независимых групп стратегий
echo [12] Telegram: состояние отдельных backends
echo [0] Назад
 echo.
set "A="
set /p "A=Введите номер [0]: "
if not defined A set "A=0"
if "%A%"=="0" goto MENU
if "%A%"=="1" call :RUN_REMOTE "--service-modules-health" & goto ADVANCED_FINISH
if "%A%"=="2" call :RUN_REMOTE "--service-modules-queues" & goto ADVANCED_FINISH
if "%A%"=="3" call :RUN_REMOTE "--service-benchmark --speed deep" & goto ADVANCED_FINISH
if "%A%"=="4" call :RUN_REMOTE "--adaptive-auto" & goto ADVANCED_FINISH
if "%A%"=="5" call :RUN_REMOTE "--predictive-auto" & goto ADVANCED_FINISH
if "%A%"=="6" call :RUN_REMOTE "--resource-update" & goto ADVANCED_FINISH
if "%A%"=="7" call :RUN_REMOTE "--rollback --confirm" & goto ADVANCED_FINISH
if "%A%"=="8" call :RUN_REMOTE "--ai-diagnose all" & goto ADVANCED_FINISH
if "%A%"=="9" call :RUN_REMOTE "--github-status" & goto ADVANCED_FINISH
if "%A%"=="10" call :RUN_REMOTE "--remote-wg-diagnose" & goto ADVANCED_FINISH
if "%A%"=="11" call :RUN_REMOTE "--strategy-group-status" & goto ADVANCED_FINISH
if "%A%"=="12" call :RUN_REMOTE "--telegram-backends-status" & goto ADVANCED_FINISH
call :ERROR "Неверный пункт MASTER-режима."
goto ADVANCED_MENU

:ADVANCED_FINISH
call :WAIT
if not errorlevel 1 goto ADVANCED_MENU
goto FAIL

:CHOOSE_SERVICE
set "SERVICE="
call :SECTION "ВЫБОР СЕРВИСА"
echo  [1] ChatGPT / OpenAI
echo [2] Claude
echo [3] Gemini / Google
echo [4] Kimi
echo [5] DeepSeek
echo [6] Perplexity
echo [7] Mistral
echo [8] Grok / xAI
echo [9] Copilot
echo [10] YouTube
echo [11] Instagram
echo [12] X / Twitter
echo [0] Отмена
 echo.
set "N="
set /p "N=Введите номер [1]: "
if not defined N set "N=1"
if "%N%"=="0" exit /b 1
if "%N%"=="1" set "SERVICE=openai"&exit /b 0
if "%N%"=="2" set "SERVICE=anthropic"&exit /b 0
if "%N%"=="3" set "SERVICE=google-gemini"&exit /b 0
if "%N%"=="4" set "SERVICE=kimi"&exit /b 0
if "%N%"=="5" set "SERVICE=deepseek"&exit /b 0
if "%N%"=="6" set "SERVICE=perplexity"&exit /b 0
if "%N%"=="7" set "SERVICE=mistral"&exit /b 0
if "%N%"=="8" set "SERVICE=grok"&exit /b 0
if "%N%"=="9" set "SERVICE=copilot"&exit /b 0
if "%N%"=="10" set "SERVICE=youtube"&exit /b 0
if "%N%"=="11" set "SERVICE=instagram"&exit /b 0
if "%N%"=="12" set "SERVICE=x"&exit /b 0
call :ERROR "Неверный номер сервиса."
exit /b 1

:RUN_REMOTE
set "CMD=%~1"
call :SECTION "ВЫПОЛНЕНИЕ НА РОУТЕРЕ"
echo Команда: %CMD%
echo Адрес:   root@%ROUTER%
echo.
ssh -t -o ConnectTimeout=15 root@%ROUTER% "chmod +x /tmp/universal-openwrt/src/universal-openwrt && /tmp/universal-openwrt/src/universal-openwrt %CMD%"
set "RC=%ERRORLEVEL%"
echo.
echo Код выполнения: %RC%
exit /b %RC%

:CONNECT
call :SECTION "ПОДКЛЮЧЕНИЕ"
echo Роутер: %ROUTER%
echo Проверяю SSH и базовую файловую систему...
ssh -o ConnectTimeout=8 root@%ROUTER% "echo UOWRT_SSH_OK && test -x /bin/sh && test -d /tmp"
if errorlevel 1 (
  call :ERROR "SSH недоступен. Проверьте адрес 192.168.1.1, сеть, пароль root и SSH."
  exit /b 1
)
echo [OK] SSH доступен.
exit /b 0

:UPLOAD
set "REMOTE=/tmp/universal-openwrt"
call :SECTION "ПЕРЕДАЧА ПРОЕКТА"
echo Удаляю старую временную копию: %REMOTE%
ssh -o ConnectTimeout=10 root@%ROUTER% "rm -rf %REMOTE% && mkdir -p %REMOTE%"
if errorlevel 1 (
  call :ERROR "Не удалось подготовить каталог %REMOTE%."
  exit /b 1
)
echo Копирую файлы проекта. Это может занять некоторое время...
scp -r "%ROOT%." root@%ROUTER%:%REMOTE%/
if errorlevel 1 (
  call :ERROR "Не удалось передать проект через SCP."
  exit /b 1
)
ssh -o ConnectTimeout=10 root@%ROUTER% "test -s %REMOTE%/src/universal-openwrt && test -s %REMOTE%/installer/install.sh && test -s %REMOTE%/modules/service-modules.sh && test -s %REMOTE%/modules/source-resolver.sh && test -s %REMOTE%/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
if errorlevel 1 (
  call :ERROR "Передача завершилась, но контрольная проверка проекта не прошла."
  exit /b 1
)
echo [OK] Проект передан и проверен.
exit /b 0

:CHECK_WINDOWS
where ssh.exe >nul 2>&1 || (call :ERROR "Не найден ssh.exe. Установите OpenSSH Client в Windows."&exit /b 1)
where scp.exe >nul 2>&1 || (call :ERROR "Не найден scp.exe. Установите OpenSSH Client в Windows."&exit /b 1)
if /I "%ROOT:~0,2%"=="\\" (call :ERROR "Проект находится на UNC-пути. Скопируйте его на локальный диск."&exit /b 1)
exit /b 0

:CHECK_PROJECT
call :REQUIRED "%ROOT%VERSION" "VERSION" || exit /b 1
call :REQUIRED "%ROOT%src\universal-openwrt" "src/universal-openwrt" || exit /b 1
call :REQUIRED "%ROOT%installer\install.sh" "installer/install.sh" || exit /b 1
call :REQUIRED "%ROOT%modules\source-resolver.sh" "source-resolver.sh" || exit /b 1
call :REQUIRED "%ROOT%modules\service-modules.sh" "service-modules.sh" || exit /b 1
call :REQUIRED "%ROOT%modules\strategy-engine.sh" "strategy-engine.sh" || exit /b 1
call :REQUIRED "%ROOT%modules\ai-access-engine.sh" "ai-access-engine.sh" || exit /b 1
call :REQUIRED "%ROOT%modules\resource-monitor.sh" "resource-monitor.sh" || exit /b 1
call :REQUIRED "%ROOT%luci-app-universal-openwrt\htdocs\luci-static\resources\view\universal-openwrt\overview.js" "LuCI overview.js" || exit /b 1
call :REQUIRED "%ROOT%assets\ipk\universal-openwrt_!VERSION!-1_all.ipk" "core IPK" || exit /b 1
call :REQUIRED "%ROOT%assets\ipk\luci-app-universal-openwrt_!VERSION!-1_all.ipk" "LuCI IPK" || exit /b 1
call :REQUIRED "%ROOT%assets\apk\universal-openwrt-!VERSION!-r1.apk" "core APK" || exit /b 1
call :REQUIRED "%ROOT%assets\apk\luci-app-universal-openwrt-!VERSION!-r1.apk" "LuCI APK" || exit /b 1
exit /b 0

:REQUIRED
if not exist "%~1" (call :ERROR "Не найден обязательный файл: %~2"&exit /b 1)
exit /b 0

:READ_VERSION
set "VERSION="
set /p VERSION=<"%ROOT%VERSION"
if not defined VERSION (call :ERROR "Файл VERSION пуст."&exit /b 1)
exit /b 0

:GITHUB_PREFLIGHT
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -UseBasicParsing -Uri 'https://api.github.com/' -TimeoutSec 5 | Out-Null; exit 0 } catch { try { Invoke-WebRequest -UseBasicParsing -Uri '%GH_MIRROR%' -TimeoutSec 5 | Out-Null; exit 2 } catch { exit 1 } }"
set "RC=%ERRORLEVEL%"
if "%RC%"=="0" (set "GH_STATUS=ONLINE") else if "%RC%"=="2" (set "GH_STATUS=MIRROR") else (set "GH_STATUS=OFFLINE")
exit /b 0

:SHOW_STATUS
if /I "%GH_STATUS%"=="ONLINE" (echo GitHub:   доступен) else if /I "%GH_STATUS%"=="MIRROR" (echo GitHub:   основной недоступен, CDN доступен) else (echo GitHub:   недоступен, локальная работа возможна)
echo Роутер:   %ROUTER%
echo Версия:   !VERSION!
exit /b 0

:HEADER
cls
echo ============================================================
echo                 UNIVERSAL OPENWRT
echo                    v%VERSION%
echo ============================================================
echo Простой режим. Технические настройки находятся в MASTER.
echo.
exit /b 0

:SECTION
echo.
echo ------------------------------------------------------------
echo %~1
echo ------------------------------------------------------------
exit /b 0

:INFO
echo.
echo [OK] %~1
exit /b 0

:ERROR
echo.
echo [ОШИБКА] %~1
exit /b 0

:WAIT
call :INFO "Операция завершена. Нажмите любую клавишу для возврата в MASTER."
pause >nul
exit /b 0

:FINISH
call :INFO "Операция завершена. Нажмите любую клавишу для возврата в главное меню."
pause >nul
goto MENU

:FAIL
set "RC=%ERRORLEVEL%"
echo.
echo ============================================================
echo ОПЕРАЦИЯ ОСТАНОВЛЕНА
if not defined RC set "RC=1"
echo Код ошибки: %RC%
echo Окно НЕ закрывается. Вы можете прочитать диагностику выше.
echo ============================================================
echo.
pause
goto MENU

:EXIT
call :SECTION "ЗАВЕРШЕНИЕ"
echo Launcher завершает работу.
echo Если окно было открыто двойным щелчком, оно останется открытым.
echo Нажмите любую клавишу, чтобы закрыть launcher.
pause >nul
exit /b 0
