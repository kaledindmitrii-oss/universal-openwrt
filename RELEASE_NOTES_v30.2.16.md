# Universal OpenWrt v30.2.16 — Release Notes

## Summary

v30.2.16 is a hardening and usability release focused on Telegram, AWG/WARP, automatic strategy selection, synchronization safety, rollback integrity and a simpler LuCI experience.

> **Status:** Release candidate. Real-router acceptance testing is still required on OpenWrt 24.10.2+ and 25.12.x before calling the release stable.

## What changed after the deep project audit

### Telegram

- Reworked the local Telegram SOCKS5 path around the `tg-ws-proxy-go` bridge.
- Added architecture-aware binary selection for supported OpenWrt architectures.
- Added SHA256 verification when the upstream GitHub release metadata provides a digest.
- Separated local TG SOCKS5, TG WS and external SOCKS5/TProxy concepts in the runtime and UI.
- Corrected failover ordering so the system does not advertise AWG as a Telegram fallback without a dedicated Telegram routing policy.
- Added deterministic installed/configured/running/active state handling.
- Prevented disabled or unconfigured Telegram WS from being reported as the active transport.

### AWG / WARP

- Added automatic acquisition of `amneziawg-tools`, a kernel-matched `kmod-amneziawg`, and `luci-proto-amneziawg` for supported OpenWrt releases.
- Added strict target, subtarget, architecture and kernel compatibility checks before installing the kernel module.
- Removed TLS certificate bypasses from AWG downloads and HTTPS probes.
- Added checksum verification for downloaded artifacts when a trusted digest is available.
- Improved local backend discovery so AWG can operate from the installed Universal OpenWrt module tree without relying on an unrelated external backend path.
- Kept AWG changes transactional with health-check rollback.

### Automatic strategy selection

- Added a capability registry so strategy names remain tied to real backend implementations.
- Added a single strategy-application path.
- Added a global strategy-change lock so concurrent AWG/DPI/Proxy/Tunnel mutations cannot modify the same network state simultaneously.
- Improved rollback to restore AWG, Telegram, failover and generated module state.
- Improved per-resource policy lookup so learned resource results can influence future candidate selection.
- Strategy scoring prefers the simplest successful strategy when the performance/stability gain of a heavier backend is not significant.
- Failed DNS strategy candidates are no longer reported as successful when all required paths fail.
- The system avoids pretending that a policy table alone provides true per-domain routing when the active backend cannot enforce it.

### Synchronization and state safety

- Serialized network strategy mutations through a lock.
- Ensured adaptive-controller locks are released on completion.
- Propagated backend failures instead of masking them as successful operations.
- Improved status reporting for strategy, tunnel and Telegram engines.
- Kept runtime state under `/etc/universal-openwrt` and temporary benchmark state under `/tmp/universal-openwrt`.

### LuCI / interface

The interface was simplified rather than adding more top-level buttons.

Primary actions are now centered around:

- **Автонастройка** — diagnose and select a suitable strategy automatically.
- **Проверить** — run a non-destructive health check.
- **Обновить ресурсы** — refresh resource lists/policies.
- **Обновить экран** — refresh current state.
- **Откатить** — restore the last safe configuration.

Advanced backend-specific operations remain available in expandable sections instead of being exposed as a large button wall.

The UI also distinguishes between:

- Telegram client proxy vs router-wide routing;
- AWG/WARP vs Telegram transport;
- strategy selection vs diagnostics;
- profile generation vs actual traffic activation.

### Installer and release delivery

- Installer selects IPK for OpenWrt 24.10.2+ and APK for OpenWrt 25.12.x.
- Release package selection is tied to the detected native package manager.
- Package and release archive checksums are validated.
- Missing LuCI release assets are treated as installation failures rather than silently producing an incomplete UI installation.
- External third-party backends require an explicit HTTPS URL and exact SHA256.
- Release helpers derive the version/tag from `VERSION`.
- Python cache files and runtime secrets are excluded from the repository.

### Validation added/updated

The release tree includes checks for:

- shell syntax;
- LuCI JavaScript syntax;
- OpenWrt platform scope;
- release asset integrity;
- package contents;
- RPC method/ACL parity;
- CLI help/dispatch parity;
- strategy/backend contract parity;
- Telegram strategy ordering and state handling;
- interface/strategy regression;
- read-only RPC smoke testing on a real OpenWrt runtime.

## Important limitations

- `rpc_smoke` cannot be fully executed on a non-OpenWrt build host; it must be run on a real supported router after installation.
- AWG kernel modules must match the router's exact OpenWrt/kernel build.
- The current VLESS/sing-box Tunnel Engine validates and generates profiles but does not claim transparent router-wide TUN/TProxy activation.
- Resource-level strategy learning is implemented, but true simultaneous per-domain routing requires a backend that can enforce those policies; the project does not falsely advertise policy-table entries as active routing.

## Upgrade recommendation

For a production router, take a configuration backup first, install the matching release package, run `universal-openwrt --self-check`, then run the non-destructive health check before enabling automatic strategy changes.
