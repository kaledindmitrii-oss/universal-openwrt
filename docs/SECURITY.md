# Security model

Do not store credentials or private VPN material in Git.

The LuCI backend uses an allowlist of supported commands and validates user-controlled profile names and modes before invoking the runtime. It does not expose an arbitrary shell command endpoint.

Release archives can be verified with SHA256. Cryptographic signatures should be added when a signing key and release policy are established.


## External backend trust

The optional open-routerich backend is not downloaded from a moving branch. Production use must provide an HTTPS archive URL and an exact SHA256 via `--backend-url` + `--backend-sha256` or `UOW_BACKEND_URL` + `UOW_BACKEND_SHA256`. Without both values the external backend is disabled.

## Telegram routing

The Telegram SOCKS5/TProxy path uses a dedicated procd-managed sing-box service. TG WS is a client-facing MTProto endpoint. Telegram AWG failover is intentionally not advertised until a dedicated Telegram-to-AWG routing policy exists.
