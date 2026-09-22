# Architecture

The project is organized as a capability-driven runtime with three policy layers:

1. **Resource** — individual domains/resources.
2. **Service** — groups such as YouTube, Telegram, Discord, AI and developer services.
3. **Device** — inferred client profiles used as an additional policy signal.

Persistent state belongs in `/etc/universal-openwrt`. Bundled read-only resources belong in `/usr/lib/universal-openwrt/test-resources`. Temporary benchmark state belongs in `/tmp/universal-openwrt`.

The runtime deliberately separates detection, planning, installation and activation. Future releases can split the current shell runtime into smaller libraries without changing the public CLI.


## Explicit boundaries

- The VLESS Tunnel Engine currently stores and validates profiles; `--tunnel-enable` does not claim transparent router traffic activation.
- Telegram SOCKS5/TProxy is a router-transparent path and is managed by its own procd service.
- TG WS is a local/client-facing MTProto endpoint, not a router-wide transparent fallback.
- External open-routerich integration is optional and content-addressed by SHA256.
