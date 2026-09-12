# Universal OpenWrt

Universal, capability-driven OpenWrt network manager for adaptive DNS, DPI mitigation, VPN/WARP/AWG profiles, resource/service testing, Telegram proxy routing, device-aware policies and LuCI management.

> **Status:** v30.0.0 — public release candidate. Test on your own hardware before enabling automatic VPN/DPI policies.

## Highlights

- Automatic OpenWrt/device/architecture/package-manager/firewall detection.
- OpenWrt `opkg` and `apk` awareness.
- Capability-based installation instead of model-specific assumptions.
- Resource → service → device strategy layers.
- Adaptive strategy benchmarking with regression checks.
- AWG/WARP and VPN profile management.
- Telegram SOCKS5/TProxy integration.
- LuCI interface with allowlisted RPC actions and ACLs.
- procd integration with monitor disabled by default.
- Persistent state under `/etc/universal-openwrt` and bundled resources under `/usr/lib/universal-openwrt`.
- Self-check and controlled self-update support.

## Quick install

For a GitHub release archive:

```sh
wget -qO- https://raw.githubusercontent.com/OWNER/universal-openwrt/main/installer/install.sh | sh
```

For a local archive:

```sh
sh installer/install.sh universal-openwrt-v30.0.0.tar.gz
```

After installation:

```sh
universal-openwrt --version
universal-openwrt --self-check
universal-openwrt --plan
```

A full installation is intentionally explicit:

```sh
universal-openwrt --install -y
```

## Repository layout

```text
src/                         runtime
installer/                   OpenWrt bootstrap installer
luci-app-universal-openwrt/  LuCI application
packaging/                   init/procd files
resources/                   bundled test/resource data
docs/                        documentation
tests/                       static/smoke tests
.github/                     CI, release and issue templates
```

## Configuration and secrets

Never commit VPN private keys, SOCKS5 passwords, AWG credentials, tokens, generated runtime state or `/etc/universal-openwrt` into Git. Use local configuration or environment/secret storage.

## Architecture note

Router-side tests cannot perfectly emulate an endpoint's iOS/Android/Windows/TV TCP/IP stack. Device-aware policies are therefore an additional signal, not proof of exact client behavior.

## Sources

The project uses public strategy/resource research from `itdoginfo/allow-domains`, `StressOzz/Zapret-Manager`, and OpenWrt documentation. Their licenses and upstream terms remain applicable to their respective content.

## License

See [LICENSE](LICENSE).
