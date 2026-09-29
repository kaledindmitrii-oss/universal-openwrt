# v30.2.19 — OpenWrt 24.10.8 / AmneziaWG 3.1 alignment

- Deep architecture hardening: GitHub availability preflight, source fallback, group-policy consistency, safer Telegram SOCKS5 defaults, Remote WireGuard name-only device provisioning, and release/launcher parity checks.

- Remote WireGuard получил согласованный менеджер устройств: `Название → Добавить → QR → готово`; endpoint, клиентские ключи, следующий свободный `10.66.66.x/32`, peer и `.conf` создаются автоматически. QR/SVG является основным способом выдачи конфигурации.
- Добавлены состояния устройств по handshake/RX/TX/endpoint, а также `revoke`, `regenerate` и `remove` с управлением только собственными peers.
- `qrencode` стал обязательной зависимостью пакета, чтобы QR не зависел от случайного наличия утилиты на роутере.
- Remote WireGuard не добавляет `0.0.0.0/0`/`::/0`, не включает NAT и не регистрируется в strategy/AWG/WARP routing.
- Добавлена LuCI-карточка для добавления и просмотра удалённых устройств без вмешательства в маршрутизацию Universal OpenWrt.

- Профиль AWG зафиксирован на OpenWrt 24.10.8 и AmneziaWG 3.1.
- Источник AWG-пакетов переключён на `2Grey/awg-openwrt`; выбор выполняется по полному target/subtarget, а release assets проходят SHA256-проверку.
- Импорт provider `.conf` расширен для S3/S4, I1-I5 и параметров AWG 3.1.
- Исправлен импорт списков Address/AllowedIPs/DNS и сохранение MTU/ListenPort.
- Перед установкой удаляется конфликтующий legacy `luci-app-amneziawg`.
- WARP остаётся WireGuard-compatible транспортом и не маркируется как обфусцированный AWG-профиль.
- Сохранён запрет на ложный `awg-split`: selective routing не объявляется рабочим без реального policy-routing classifier.

# v30.2.17 — Deep multidirectional audit / strategy reliability hardening

- Усилен per-module learning: cooldown теперь применяется к каждой конкретной стратегии, а не только ко всему модулю.
- Очередь кандидатов учитывает preferred-профиль, историю успешных результатов и индивидуальные cooldown.
- Качество стратегии теперь считается по согласованным повторным раундам; единичный удачный ответ не может сам по себе закрепить профиль.
- Для resource benchmark кандидат принимается только при фактическом `OK`, стабильности не ниже 75% и отсутствии проблем контрольных ресурсов.
- После выбора выполняется финальная повторная проверка уже восстановленного профиля; при провале выполняется возврат к baseline.
- Исправлена агрегация независимых модулей: AI объединяет `openai/ai`, Social — `social/tiktok`, Messaging — `discord`; добавлен модуль News.
- Исправлены оставшиеся неатомарные/stale-prone locks VPN monitor, predictive controller и Telegram controller.
- Windows Launcher теперь автоматически выбирает `opkg` для 24.10 и `apk --allow-untrusted` для 25.12, проверяет оба набора пакетов и выполняет post-install self-check.
- Убран неверный вызов `service-module-recover` для AI service IDs; guided launcher использует сервисный `--ai-apply`.
- Добавлен статический тест BAT и расширены regression-проверки runtime hardening.


## 30.2.17 — Telegram isolation / SOCKS5 1080
- Telegram вынесен в отдельный канал управления и исключён из общего AI/service benchmark.
- Telegram SOCKS5 bridge `tg-ws-proxy-go` использует порт `1080` по умолчанию, как в upstream-проекте d0mhate.
- Усилена защита от остановки чужого экземпляра `tg-ws-proxy-go`: stop теперь работает только через собственный PID-файл.
- Проверка занятого порта учитывает `ss` и `netstat`.
- В LuCI добавлена отдельная карточка Telegram с установкой, состоянием, включением и отключением SOCKS5 bridge.
# v30.2.16 — Telegram, strategy automation and synchronization hardening

- Reworked Telegram SOCKS5 around the local `tg-ws-proxy-go` bridge with architecture-aware release selection and SHA256 verification when upstream metadata provides a digest.
- Separated Telegram SOCKS5, Telegram WS and external SOCKS5/TProxy semantics in runtime state, failover and LuCI.
- Added deterministic Telegram installed/configured/running/active states and corrected failover ordering.
- Added AWG/WARP package acquisition with target/kernel compatibility checks and transactional health-check rollback.
- Removed TLS certificate bypasses from AWG downloads and HTTPS probes.
- Added a strategy capability registry and unified strategy application path.
- Added a global strategy-change lock to prevent concurrent AWG/DPI/Proxy/Tunnel configuration mutations.
- Hardened rollback so generated AWG/Telegram/failover state is restored or removed when a candidate fails.
- Improved learned per-resource policy selection and strategy scoring; simpler successful strategies are preferred when heavier alternatives provide no meaningful benefit.
- Fixed DNS strategy success reporting so failed candidates cannot be reported as successful.
- Improved backend error propagation and adaptive-controller lock cleanup.
- Simplified LuCI around five primary actions with advanced controls kept in expandable sections.
- Added/updated regression checks for interface, strategy contracts, Telegram state, release assets, RPC/ACL parity and platform scope.
- Removed generated Python cache files and added repository ignore rules for runtime/secrets/build artifacts.
- See `RELEASE_NOTES_v30.2.16.md` for the complete audit and release summary.

# v30.2.15

- Reworked Telegram SOCKS5 path to use a local `tg-ws-proxy-go` WebSocket bridge, matching the architecture used by StressOzz/Zapret-Manager instead of treating an external SOCKS5 server as the primary Telegram backend.
- Automatic architecture-aware TG SOCKS5 binary installation from the upstream release channel.
- Automatic Telegram failover now prefers local TG SOCKS5/WS, then Rust WS, then the legacy external-SOCKS5 routing policy. The old external SOCKS5/TProxy implementation remains available under its own policy and is no longer conflated with the local Telegram SOCKS5 bridge.
- Added explicit TG SOCKS5 status/install/enable/disable CLI and LuCI controls.
- Strategy/resource policy now distinguishes local TG SOCKS5 availability from external SOCKS5 configuration.

# v30.2.14

- Automatic AmneziaWG/WARP package acquisition for OpenWrt 24.10.x and 25.12.x.
- Selects `amneziawg-tools`, kernel-matched `kmod-amneziawg`, and `luci-proto-amneziawg` from the detected release/target/architecture.
- Automatically installs `curl`/CA certificates when needed, registers a WARP device, enables WARP, retrieves addresses/endpoint/peer key, and stores the generated private key/config with mode 600.
- Added `--awg-auto` and richer AWG status reporting.
- AWG remains transactional: the main engine can roll back configuration if health checks fail.

# Changelog

## 30.2.17
- Added AI Access Engine diagnostics and reserve Zapret/Zapret2 preset registry.


## 30.2.13
- Hardening release after real RAX3000M/OpenWrt 24.10.6 acceptance testing.
- Telegram WS/failover state now distinguishes configured, process-running, enabled/running and active; disabled/unconfigured WS can no longer be reported as the active transport.
- Strategy Engine reports explicit idle/active state and owner/state counts.
- Tunnel Engine reports profile count and explicit empty state.
- LuCI rpcd wrapper now propagates backend exit codes instead of returning `ok=true` for failed shell commands.
- Added safe read-only RPC smoke test (`--rpc-smoke` and `tests/rpc_smoke.sh`).
- Release manifest now carries size/SHA256 for packaged assets and release archives; checksum file remains outside the manifest to avoid circular hashing.
- Release workflow rebuilds the manifest after archives are created and verifies every manifest asset before publication.

## v30.2.12 — GitHub bootstrap, LuCI auto-install and release hardening

- Fixed direct `wget | sh` bootstrap: it now installs from the GitHub Release by default instead of trying to locate a local source directory.
- Native package-manager selection is tied to the supported OpenWrt generation: 24.10.x → `opkg`/IPK; 25.12.x → `apk`/APK.
- Release package URLs, byte counts and SHA256 values are verified before installation.
- The Universal OpenWrt LuCI package now depends on the full `luci` collection as well as `luci-base`, so a minimal supported image receives the LuCI web shell automatically when repository dependencies are available.
- Added post-install LuCI verification: `luci`, `luci-base`, web root, menu entry, RPC ACL/ucode module, Universal OpenWrt view and a supported webserver are checked before installation is reported successful.
- Missing LuCI release assets are now treated as a hard installation error instead of silently producing a core-only installation.
- Added regression coverage for automatic LuCI installation and verification.
- Kept source/archive installation available through explicit `--source`, `--url`, `--dir` or local archive arguments.

## v30.2.11 — GitHub release delivery + intuitive control

- GitHub Release manifest with deterministic package URLs and SHA256 hashes.
- Bootstrap installer can automatically download the matching IPK/APK from the latest GitHub Release.
- Release workflow publishes source archives, IPK/APK packages, manifest and checksums together.
- Added runtime module self-check for Strategy/Tunnel/Telegram WS components.
- Fixed LuCI ucode import for OpenWrt 24.10.x.
- Grouped dashboard actions around user tasks instead of internal engine names.

## v30.2.11 — OpenWrt 24.10.2+ support floor

- Raised the OpenWrt 24.10 support floor from 24.10.0 to **24.10.2+**.
- Added strict numeric patch validation for 24.10 releases.
- Kept OpenWrt 25.12.x as the primary target.
- Updated installer, runtime platform detection, documentation and release tests.


## v30.2.11 — pre-release audit hardening
- Added dedicated procd service for Telegram SOCKS5/TProxy so the generated sing-box config is actually executed and survives reboot.
- Removed the empty Telegram failover marker module; failover logic remains in the core controller where it can share runtime state.
- Added optional procd service for Telegram MTProto WebSocket integration.
- Removed the unverified AWG claim from Telegram failover; AWG is not selected without a dedicated Telegram routing policy.
- External open-routerich backend is now opt-in and requires URL + SHA256; mutable `main` downloads are no longer trusted by default.
- Clarified that the current VLESS Tunnel Engine prepares/validates profiles but does not transparently activate router traffic.
- Fixed GitHub publish helper to derive version/tag from VERSION.
- Excluded Python cache files from releases.

## v30.2.5 — deep release audit

- Fixed a critical CLI dispatch ordering bug: device-aware commands are now defined before dispatch and are executable.
- Fixed missing `--verify` runtime dispatch.
- Added service benchmark/policy entries to CLI help.
- Fixed 25.12 local APK installation invocation to the documented `apk --allow-untrusted add ...` form.
- Fixed GitHub release packaging to include `modules/`, `install-luci.sh`, `CHANGELOG.md`, and release helper files.
- Added release-integrity checks for function definition order versus runtime dispatch.
- Updated version/docs to 30.2.5.

## v30.2.11
- Fixed direct source installer validation referencing a non-existent init script.
- Package-only installation now selects only the native package format: IPK on 24.10 and APK on 25.12.
- Removed duplicate Strategy/Tunnel fast-dispatch branches.
- Removed TLS certificate bypasses from HTTPS probes.
- Reduced default resource scanning from 40 to 12 domains; deep scans remain opt-in.
- OONI candidate discovery is now deep-scan-only to reduce router load and external network traffic during normal installation.
- Added release integrity coverage for installer file references.

## v30.2.4 — OpenWrt 24.10/25.12 hardening

- Development scope narrowed to OpenWrt 24.10.x and 25.12.x only.
- OpenWrt 24.10 requires `opkg`; OpenWrt 25.12 requires `apk`.
- `fw4`/`nftables` are mandatory; legacy fw3/iptables-only paths removed from runtime detection.
- Installer now rejects unsupported OpenWrt generations and incompatible package/firewall backends before modifying the system.
- Removed duplicate always-on VPN monitor init service; the conditional monitor service remains disabled by default.
- Asset builder removes stale IPK/APK files before rebuilding for deterministic releases.
- Added platform-scope CI test.

## v30.2.3
- Fixed direct GitHub/source installation: runtime modules are installed to `/usr/lib/universal-openwrt`.
- Added post-install verification for required runtime modules.
- Removed duplicate LuCI strategy/tunnel RPC definitions.
- Corrected Telegram WS/failover RPC ACL placement.
- Added Telegram failover runtime-state detection and mutually exclusive backend switching.
- Cleaned the VPN monitor init script.
- Hardened release workflow paths and added release integrity checks.

## v30.2.2
- Added unified Telegram failover controller.

## v30.2.1
- Added optional Telegram MTProto WebSocket backend integration.

## v30.2.0
- Added Strategy Engine and open VLESS/sing-box tunnel engine.
- Proprietary ZeroBlock binaries are not redistributed.

## v30.1.1
- Fixed direct GitHub bootstrap installation and added IPK/APK assets.

## v30.1.0
- Audit hardening for LuCI/RPC, resource discovery, Telegram SOCKS5 and self-update verification.
## 30.2.17 — Guided diagnostics

- Добавлен «Мастер диагностики»: выбор AI-сервиса, последовательная проверка сети и сервиса, определение вероятного типа проблемы и объяснение следующего шага.
- Диагностика по умолчанию не изменяет конфигурацию; применение автоматической стратегии вынесено в отдельное подтверждаемое действие.
- Добавлены понятные этапы и индикатор прогресса без показа технических деталей на первом экране.

## 30.2.17 — UX / LuCI redesign

- Полностью переработан главный экран LuCI: вместо технической «стены» статусов используются понятные сценарии и карточки.
- Основные действия вынесены на первый экран: Проверить, Автонастройка, Обновить.
- Опасные и сложные функции перенесены в отдельный блок «Расширенные инструменты».
- Добавлен отдельный AI-раздел с выбором сервиса, диагностикой и резервными community-пресетами.
- Добавлены понятные состояния PASS / предупреждение / ошибка и пояснение следующего шага.
- Интерфейс адаптирован для узких экранов и мобильного браузера.
- AI RPC-методы добавлены в LuCI ACL.


## 30.2.17 — Ежедневная автоматическая проверка стратегии

- Добавлена ежедневная автоматизация подбора стратегии на 04:00 по локальному времени роутера.
- Перед подбором обновляются ресурсные списки и резервные Zapret-источники; при недоступности обновления используются кэшированные данные.
- Используется существующий adaptive controller: кандидаты сравниваются по доступности, ошибкам HTTPS, задержке, стабильности и стоимости стратегии.
- Неудачные кандидаты откатываются, рабочий вариант сохраняется.
- Добавлены команды `--automation-status`, `--automation-enable`, `--automation-disable`, `--automation-run`.
- Добавлен LuCI-блок «Ежедневный подбор стратегии» с включением, отключением, ручным запуском и просмотром состояния.
- Добавлена защита от параллельных ежедневных запусков и stale PID-lock.
- Добавлен отдельный regression test `tests/automation.sh`.

## 30.2.17 — Deep strategy audit / automation hardening

- Проведён дополнительный аудит adaptive controller, rollback, locks и автоматизации.
- Автоматический подбор больше не включается установщиком: по умолчанию инструмент выключен, как и задано в UX.
- Усилен PID-lock adaptive controller с обработкой stale lock.
- Rollback теперь удаляет созданные кандидатом конфигурации и каталоги, отсутствовавшие в исходном snapshot.
- Убраны дублирующиеся pseudo-DPI кандидаты из автоматического benchmark: `dpi-youtube-auto`, `dpi-discord` и `dpi-game` ранее использовали один и тот же backend вызов.
- Исправлена инверсия DNS-классификации AI Access Engine и недостижимая ветка QUIC-диагностики.
- Усилен Windows launcher: preflight архива, структуры проекта, версии, SSH, удалённых файлов и обязательных IPK; окно не закрывается при ошибке.

## 30.2.17 — AI / YouTube / Instagram / X access hardening
- Расширен каталог проверяемых сервисов: AI + YouTube + Instagram + X/Twitter.
- Диагностика теперь учитывает несколько endpoint-доменов и HTTP/3, а не один URL.
- Добавлена явная приоритетная цепочка: direct → DNS → DPI → AWG/relay; для IP/region-признаков relay/AWG проверяются раньше DPI.
- Добавлен `--ai-apply SERVICE`: кандидаты применяются по одному, после каждого выполняется сервисный тест, неудачный вариант откатывается.
- AI/social/video больше не получают AWG как безусловный первый кандидат в общем планировщике: DPI проверяется раньше, что снижает лишнюю нагрузку.
- В LuCI добавлена кнопка «Применить с откатом» для выбранного сервиса.

## 30.2.17 — Dedicated Telegram controller
- Добавлен отдельный Telegram Controller: SOCKS5/WebSocket health-check, recovery и fallback без участия AI/adaptive controller.
- Telegram по умолчанию использует SOCKS5 `0.0.0.0:1080`; контрольный контур не изменяет стратегии других сервисов.
- Добавлен procd-сервис с безопасным мониторингом состояния и настраиваемым интервалом.
- Исправлено определение procd-managed `tg-ws-proxy-go`: используется PID-файл или проверка реального `/proc/<pid>/exe`, без остановки чужого процесса с тем же именем.
- LuCI получил отдельный блок Telegram Controller; автоконтроль включается пользователем и выключен по умолчанию.

## 30.2.17 — Full audit / launcher hardening

- Убрана лишняя сетевая загрузка из `resource_matrix_init()`: инициализация ресурсного кэша больше не делает скрытый повторный HTTP-запрос.
- Усилена атомарность lock-механизмов автоматизации и изменения стратегии через `mkdir`-locks с PID ownership.
- Убрана вложенная `trap` из ежедневной автоматизации, которая могла перезаписать глобальный cleanup trap основного скрипта.
- Удалён неиспользуемый installer helper, который мог вводить в заблуждение относительно включения автоматизации по умолчанию.
- Удалён дублирующий Windows launcher из `tools/`; основной launcher теперь находится в корне проекта.
- Добавлен `Universal-OpenWrt-Launcher.bat`: запускается непосредственно после распаковки проекта, проверяет окружение, структуру, версию и подключение к роутеру перед выполнением действий.

## 30.2.17 — LuCI / beginner UX hardening
- LuCI переведён на режим «простое по умолчанию»: технические карточки и ручные операции скрыты до включения единого переключателя `MASTER — расширенный режим`.
- `MASTER` сохраняет выбор только в браузере и не меняет сетевую конфигурацию.
- AI-каталог LuCI расширен до полного набора сервисов из AI registry, включая Copilot, Hugging Face, Poe, Cohere и OpenRouter.
- Расширенные операции сгруппированы в отдельный блок: резервные пресеты, AWG/WARP, Telegram, ресурсы, ручной/адаптивный/предиктивный подбор и журнал.
- Удалён устаревший дублирующий Windows launcher; в релизном архиве остаётся один понятный `Universal-OpenWrt-Launcher.bat`.
- Удалены вложенные локальные release-архивы из исходного проекта, чтобы исключить рекурсивные «хвосты» и лишний объём.

## 30.2.17 — Live resource monitor / targeted recovery
- Добавлен единый монитор состояния AI/YouTube/Instagram/X и других ключевых ресурсов.
- Автоподбор сначала восстанавливает только ресурсы со статусом FAIL/блокировка; рабочие ресурсы не становятся целями подбора.
- После каждого изменения выполняется повторный скан: если одна глобальная стратегия восстановила несколько ресурсов, они автоматически исключаются из очереди.
- Уже рабочие ресурсы используются как guard: кандидат, который ломает их, откатывается целиком.
- Добавлены LuCI RPC/UI действия «Проверить сейчас» и «Восстановить только неработающие».
- Добавлен `--resource-monitor` и `--resource-recovery`.
- Новый монитор не создаёт отдельный lock и использует существующий контроллер стратегий/rollback.

## 30.2.17 — Per-module learning layer
- Добавлена отдельная история успехов/ошибок для каждого включённого модуля.
- Добавлена персональная очередь стратегий: последний успешный профиль проверяется первым, затем резервные кандидаты.
- Добавлен health-score 0–100 для каждого модуля на основе доступности ресурсов и стоимости проверки.
- Добавлены persistent state/queue/history файлы в `/etc/universal-openwrt/adaptive/service-modules/`.
- Неудачные стратегии получают отдельную запись и не становятся приоритетом до нового успешного теста.
- Защита работающих модулей сохранена: кандидат отклоняется при регрессии уже работающего соседнего модуля.
- Telegram остаётся отдельным контроллером и не смешивается с общей очередью стратегий.
- Добавлены CLI: `--service-modules-health` и `--service-modules-queues`.

## 30.2.17 — Deep audit / service learning hardening
- Исправлено сопоставление групп сервисов с пользовательскими модулями.
- Усилен per-module learning: last-known-good, best score, cooldown, consecutive failures, latency и stability.
- Кандидаты проходят повторную проверку стабильности перед принятием.
- Health-score стал учитывать доступность, задержку и стабильность.
- В LuCI добавлены health-карточки независимых модулей и RPC состояния очередей.
- Исправлен Windows Launcher: устранены дублирующиеся labels и расширен набор безопасных диагностических команд.
- Удалены вложенные release-архивы и временный `__pycache__` из исходного дерева.

## v30.2.19 — Remote WireGuard isolation hardening

- Добавлен изолированный `wireguard-remote.sh` для существующей remote-access реализации WireGuard (`wg0`, `10.66.66.1/24`, UDP 51820).
- Remote WireGuard не регистрируется как стратегия Universal OpenWrt и не участвует в AWG/WARP, обходах, AI Access Engine, DNS или adaptive/fallback routing.
- Remote WireGuard не получает `route_allowed_ips`, не становится default route и не выполняет Internet masquerade.
- Для него выделена отдельная firewall zone `uowrt_remote_wg` с доступом только к самому роутеру; forwarding по умолчанию запрещён.
- Добавлен regression test `wireguard_remote_isolation.sh`, проверяющий отсутствие связей с текущим routing/strategy stack.

## v30.2.19 — Windows launcher hardening
- Fixed router default in `Universal-OpenWrt-Launcher.bat` to `192.168.1.1`.
- Fixed startup validation order: `VERSION` is loaded before versioned IPK/APK assets are checked.
- Added UTF-8 console initialization for readable Russian output.
- Simplified menu/status output and kept the launcher alive after operations and errors.
