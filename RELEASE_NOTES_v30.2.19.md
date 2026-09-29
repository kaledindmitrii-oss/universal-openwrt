# v30.2.19 — OpenWrt 24.10.8 / AmneziaWG 3.1

## Remote WireGuard isolation

The existing Remote WireGuard implementation is packaged as a strictly isolated module.

- Interface: `wg0`
- Router address: `10.66.66.1/24`
- Listen port: `51820/UDP`
- Firewall zone: `uowrt_remote_wg`

The module is **remote-access only**. It does not participate in Universal OpenWrt traffic routing, bypasses, AWG/WARP, strategy selection, AI Access Engine, DNS routing, adaptive fallback, or Internet NAT.

The module never manages `route_allowed_ips=1`, never becomes the default route, and does not masquerade Internet traffic.

A dedicated regression test (`tests/wireguard_remote_isolation.sh`) verifies that the remote module remains outside the current routing/strategy stack.


## Deep architecture hardening

- Added startup GitHub/source availability detection with safe CDN/mirror fallback for source content.
- Removed pseudo-specialized DPI candidates that called the same backend without a real per-service implementation. Group policies now keep separate state while global backends remain transactional and protected by regression checks.
- Remote WireGuard device creation now requires only a device name; endpoint discovery uses saved settings, DDNS or public IPv4.
- WireGuard device onboarding follows the agreed flow: `Название → Добавить → QR → готово`; client keys, the next free `10.66.66.x/32`, peer, registry entry and client configuration are generated automatically.
- QR generation is now a required package dependency (`qrencode`), not a best-effort feature. The UI shows QR first and keeps `.conf` as the fallback/import option.
- Added device lifecycle controls: online/inactive/never-connected state from WireGuard handshake/transfer data, revoke, regenerate and remove; all operations are scoped to peers owned by the device registry.
- Existing `wg0`, foreign peers, routing, NAT and strategy/AWG/WARP/DNS configuration remain outside the device manager.
- Hardened Telegram SOCKS5 defaults and source acquisition.
- Added stronger release/launcher/version consistency checks and an expert-mode label in LuCI.


## Deep audit additions

- Added explicit GitHub/source preflight with trusted operator-configured mirror fallback and jsDelivr fallback for static raw content; TLS verification remains enabled.
- Added kernel ABI discovery to the capability plan and strengthened the principle that kmod installation requires the complete OpenWrt target/kernel tuple.
- Added a dedicated VPN health engine covering interface, handshake, RX/TX, route, DNS and IPv4/IPv6 reachability.
- Hardened Telegram SOCKS5 release installation: release assets without a SHA256 digest are rejected, and the local SOCKS5 path receives a real connectivity probe after startup.
- Added independent service-group ownership/conflict tracking for YouTube, social, AI, gaming, Telegram, streaming, messaging, developer and news groups.
- Fixed a profile persistence formatting bug that could store literal `\n` instead of record separators.
- Hardened the Windows test launcher against stale-version checks and added local archive validation.


## Deep integration audit — WireGuard / AWG / Telegram / LuCI

- Added an exclusive Telegram backend registry: Go `tg-ws-proxy`, Rust `Telemt`, external SOCKS5 via sing-box and legacy WS are presented as separate providers.
- Prevented controller-owned Telegram providers from being started independently by their init scripts, eliminating boot-time double ownership.
- Added optional verified Telemt Rust backend installation from official GitHub release assets with SHA256 verification and architecture gating.
- Removed duplicate runtime-module copies from `packaging/root/usr/lib/universal-openwrt`; `modules/*.sh` is now the single source of runtime truth.
- LuCI now presents Telegram backends explicitly and keeps MASTER disabled by default.
- Removed a duplicated LuCI log card and prevented backend action controls from multiplying on refresh.

### Deep Windows launcher hardening
- `Universal-OpenWrt-Launcher.bat` now defaults to the project router address `192.168.1.1`.
- The launcher reads `VERSION` before validating versioned release assets, preventing a false missing-package error on startup.
- Windows console is switched to UTF-8 (`chcp 65001`) for readable Russian text.
- The normal flow is now a persistent menu; routine actions return to the menu instead of terminating the process.
- Error paths return to the menu after showing the error code, so the window stays open for inspection.
- MASTER mode remains the only place for advanced operations.

## LuCI — контуры стратегий и Telegram drill-down

- Главный экран теперь показывает отдельные блоки YouTube, социальных сетей, AI, игр, Telegram, видео/музыки, мессенджеров, разработки и новостей.
- Для каждого блока доступен отдельный переключатель участия в автоматическом подборе.
- Нажатие на блок открывает настройки стратегии и инструменты конкретного контура.
- Telegram раскрывается в отдельной панели: Controller, Go SOCKS5, WebSocket MTProto, Rust Telemt и внешний SOCKS5/sing-box.
- Для настроенных MTProto backend-ов LuCI показывает адрес, порт, secret key и доступную `tg://` ссылку для открытия/передачи.
- Telegram остаётся изолированным от общего Strategy Engine, AWG/WARP и Remote WireGuard.
- Добавлены RPC/CLI операции управления группами: apply/enable/disable и единый `--telegram-details`.

### WireGuard tunnel modes / public IP diagnostics

- LuCI now presents WireGuard as a dedicated **WireGuard туннель** block.
- Per-device modes are named **Remote WireGuard** and **WireGuard VPN**.
- Remote WireGuard keeps the existing isolated `10.66.66.0/24`-only routing.
- WireGuard VPN is explicit per-device IPv4 full-tunnel (`0.0.0.0/0`) with isolated
  WAN forwarding + NAT; it never uses AWG/WARP or the Strategy Engine.
- Added WAN-vs-external IPv4 comparison and CGNAT/private-range detection.
- UI clearly states that direct incoming WireGuard is guaranteed only with a
  genuinely public IPv4 plus reachable UDP/51820; CGNAT is not guaranteed.
- IPv6 is not advertised by the VPN mode yet and is explicitly disclosed in LuCI.
