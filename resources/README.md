# Resource Test Matrix

Источник кандидатов: itdoginfo/allow-domains, прежде всего `Russia/inside-raw.lst` и сервисные списки YouTube/Twitter/Meta/Telegram/Discord/TikTok.

Локальные списки используются как fallback, если роутер временно не может скачать актуальный список. `--resource-update` обновляет `russia-inside.lst` с GitHub.

Уровни:
- quick: critical + control
- standard: critical + video/social/messenger/AI/developer/streaming + control
- deep: все тематические списки + Russia inside + control

Telegram имеет отдельную политику: `telegram.org`, `t.me`, `telegra.ph`, `telegram.me` -> пользовательский SOCKS5 proxy. Учетные данные не хранятся в репозитории.
