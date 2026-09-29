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


## Изоляция туннелей и Telegram

- Remote WireGuard (`wg0` по умолчанию) — отдельный модуль удалённого доступа. Он не участвует в Strategy Engine, AWG/WARP, DNS/failover и не получает default route/NAT.
- AWG/WARP использует отдельный интерфейс (`awg10` по умолчанию) и зону `uowrt_awg`; WARP создаётся как обычный WireGuard-compatible transport, а provider с J/S/H/I — как настоящий AmneziaWG.
- Telegram имеет собственный Controller и backend registry. Одновременно управляющим является только один backend: Go `tg-ws-proxy`, Rust `Telemt`, внешний SOCKS5 через sing-box или legacy WS. Telegram не меняет стратегии YouTube/AI/social/gaming.
- `MASTER` в LuCI выключен по умолчанию. В обычном режиме показываются только безопасные автоматические операции; расширенные настройки находятся за одним тумблером.

## WireGuard modes and public IPv4 diagnostics

The LuCI **WireGuard туннель** block exposes two explicit per-device modes:

### Remote WireGuard

- Client `AllowedIPs`: `10.66.66.0/24`.
- Only the WireGuard tunnel network is routed through the tunnel.
- The client's ordinary Internet connection is unchanged.
- No WAN forwarding and no NAT are enabled by this mode.
- Intended for remote access to the router/tunnel network and internal resources.

### WireGuard VPN

- Client `AllowedIPs`: `0.0.0.0/0` for IPv4.
- IPv4 Internet traffic from that selected device is forwarded from the isolated
  WireGuard zone to WAN and masqueraded by the router.
- The mode is opt-in per device; creating a normal Remote WireGuard peer does not
  enable Internet VPN.
- AWG/WARP, Strategy Engine, Telegram and AI routing are not involved.
- IPv6 is intentionally not advertised in the current implementation. A client
  with independent IPv6 connectivity can therefore still use IPv6 outside this
  IPv4 VPN; the UI explicitly warns about this limitation.

### Public IPv4 / white-IP check

The module compares the WAN IPv4 reported by the router with the externally
observed IPv4 and rejects private/special ranges including RFC1918 and the
RFC6598 CGNAT range `100.64.0.0/10`. A match is reported as **white_ip=yes**.

This is a reachability prerequisite, not proof that UDP/51820 is permitted by
an upstream firewall. Direct incoming WireGuard operation is therefore stated
as guaranteed only when a genuinely public IPv4 is present **and** UDP/51820 is
reachable. If the router is behind CGNAT, direct incoming operation is not
considered guaranteed without an external relay/VPS architecture.
