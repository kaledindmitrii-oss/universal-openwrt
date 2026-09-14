# v30.2.16

- Telegram SOCKS5 now uses the same local Go `tg-ws-proxy-go` architecture as current StressOzz/Zapret-Manager, with architecture-aware release selection and SHA256 verification when GitHub release metadata provides a digest.
- Telegram failover keeps local TG SOCKS5 as the first route, then Rust/Python WS, then external SOCKS5 policy.
- Strategy Engine now exposes a capability registry and a single strategy application path, preventing strategy names from becoming detached from backend implementations.
- Strategy plan now shows preferred strategy availability.

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
