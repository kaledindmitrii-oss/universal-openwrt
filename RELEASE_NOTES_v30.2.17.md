# Universal OpenWrt v30.2.17

## AI Access Engine + reserve DPI presets

This release adds a service-aware AI access diagnostic layer for ChatGPT/OpenAI, Claude/Anthropic, Gemini, Kimi, DeepSeek, Perplexity, Mistral, Grok, Copilot, Hugging Face, Poe, Cohere and OpenRouter.

### What changed

- Added `modules/ai-access-engine.sh`.
- Added a bundled AI service catalog and strategy catalog under `resources/ai/`.
- Added explicit diagnostics for DNS, IPv4, IPv6, HTTPS, HTTP/3 capability and authentication responses.
- Added conservative classifications: `DNS_BLOCK`, `DPI_OR_QUIC_BLOCK`, `IP_BLOCK_OR_GEO`, `AUTH_BLOCK`, `SERVICE_DOWN`, `PASS`.
- Added `--ai-catalog`, `--ai-diagnose`, `--ai-test`, `--ai-auto`, `--ai-preset-status`, and `--ai-preset-fetch`.
- Kept community Zapret/Zapret2 presets as a **reserve registry**. The project does not silently activate third-party rules.
- Distinguishes Zapret1 and Zapret2 engines; their strategy syntax is not treated as interchangeable.
- Added regression coverage for catalog structure and preset source validation.

### Preset research incorporated

The reserve registry tracks the current Universal V9/V8/V2.1 family from RixyPow's public Zapret-UNIVERSAL-preset repository, the measured `zapret2-openwrt` flat strategy, and a Zapret v1 community strategy reference. Their useful design ideas are incorporated as **strategy families and validation rules**, not blindly copied into the default runtime.

The Zapret documentation emphasizes that DPI desync is transport/protocol-specific and that UDP/QUIC requires different handling from TCP/TLS. Zapret2 uses `nfqws2` with Lua strategy calls rather than Zapret1 `--dpi-desync=*` options.

### Safety

AI diagnosis is read-only. `--ai-auto` proposes a strategy class but does not enable a proxy, VPN/WARP, firewall rule or third-party preset. IP/geo restrictions are explicitly separated from DPI problems because desync cannot change the source country/IP.

## AI / YouTube / Instagram / X hardening update

- Расширен каталог до YouTube, Instagram и X/Twitter.
- Диагностика теперь проверяет несколько endpoint-доменов и HTTP/3 там, где curl это поддерживает.
- Введена приоритетная логика: `direct → DNS → DPI → AWG/relay`; при признаках IP/регионального ограничения сначала рассматривается внешний маршрут.
- Добавлен `--ai-apply SERVICE`: стратегия применяется только после диагностики, затем проверяется именно выбранный сервис; неудачная попытка откатывается.
- Общий планировщик теперь ставит DPI перед AWG для AI/social/video, чтобы не создавать тяжёлый туннель без необходимости.
- LuCI получил действие «Применить с откатом».
- Обновлён `Universal-OpenWrt-Launcher.bat`: простой мастер для неопытного пользователя, выбор сервиса, понятные пояснения и безопасный сценарий диагностики/подбора.

### LuCI beginner mode
- По умолчанию отображаются только основные сценарии: диагностика, AI/сервисы, автонастройка и расписание.
- Единый переключатель `MASTER — расширенный режим` открывает технические инструменты и настройки.
- Выбор MASTER хранится локально в браузере и не является сетевой настройкой.

### Deep audit / per-module learning hardening

- Исправлена проверка включённости сервисных групп: алиасы `openai/ai`, `discord`, `tiktok`, `news` теперь корректно сопоставляются с пользовательскими модулями.
- Для каждого модуля добавлены `best_score`, `last_latency`, `last_stability`, `consecutive_failures`, cooldown с экспоненциальной паузой и время последней подтверждённой проверки.
- Подбор больше не считает единичный удачный HTTP-ответ достаточным: кандидат проходит повторную проверку стабильности; нестабильный кандидат отклоняется.
- Health-score учитывает доступность, качество/задержку и стабильность, а история хранит эти показатели отдельно.
- Последний успешный профиль остаётся первым кандидатом только после окончания cooldown.
- Добавлена визуализация health-score и сохранённого профиля каждого независимого модуля в LuCI.
- Добавлены RPC/ACL для health и очередей сервисных модулей.
- Исправлен локальный Windows Launcher: удалены дублирующиеся labels/меню, добавлены проверки новых модулей и команды health/queue/benchmark.
- Удалены вложенные release-архивы и Python `__pycache__` из исходного дерева, чтобы релиз не содержал собственные архивы и временные хвосты.
