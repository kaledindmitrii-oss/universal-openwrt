# Changelog

## 30.1.0 — 2026-09-12

### Security
- Self-update requires a SHA-256 digest and verifies the downloaded runtime before replacement.
- Telegram SOCKS5 credentials are JSON-escaped before being written to sing-box configuration.
- Telegram nftables LAN interface is detected and validated instead of being hard-coded to `br-lan`.

### LuCI / RPC
- Added missing `benchmark` and `test` RPC methods.
- Added validated `device_profile` RPC method.
- Synchronized rpcd ACL read/write permissions with the actual RPC methods.
- Fixed undefined LuCI callbacks for resource and Telegram controls.
- Fixed the connection-test button calling the VPN-profile test function by name collision.

### Resource engine
- Fixed automatic discovery wiping the resource-matrix candidate list after building it.

### CI
- Secret-pattern scan now fails the workflow when a match is found.
- Added LuCI JavaScript syntax validation when Node.js is available.

### Verification
- `sh -n` passes for all shell scripts/runtime files.
- `tests/smoke.sh` passes.
