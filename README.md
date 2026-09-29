# Universal OpenWrt

Capability-driven OpenWrt network manager for adaptive DNS/DPI policy, VPN/WARP/AWG profiles, Telegram proxy routing, resource/service testing and LuCI management.

> **Status:** v30.2.19 — AWG/WARP deep audit and routing hardening. **Not Stable yet.** Real-router acceptance testing on OpenWrt 24.10.8 for the AWG profile is required before the stable release.

## Supported platforms

- **OpenWrt 24.10.8** — `opkg` + `fw4`/`nftables` (current AWG 3.1 profile).
- **OpenWrt 25.12.x** — `apk` + `fw4`/`nftables` (core runtime compatibility; AWG 3.1 profile is not the current target).

OpenWrt 18.06–23.05 and legacy `fw3`/iptables-only environments are outside the project scope. The release is currently validated and packaged around OpenWrt 24.10.8; 25.12 compatibility remains separate from the pinned AWG profile. OpenWrt documents `apk` for 25.12+ and `opkg` for 24.10 and older.

## Quick install

For the normal install, the bootstrap automatically downloads the matching IPK/APK packages from the latest GitHub Release, verifies SHA256 and installs the native package set:

```sh
wget -qO- https://raw.githubusercontent.com/kaledindmitrii-oss/universal-openwrt/main/installer/install.sh | sh
```

For a reproducible release install, pin the release tag:

```sh
UOW_RELEASE=v30.2.19 sh -c "$(wget -qO- https://raw.githubusercontent.com/kaledindmitrii-oss/universal-openwrt/main/installer/install.sh)"
```

The bootstrap validates the OpenWrt generation, package manager and `fw4`/`nft` before changing the system. It downloads only the package format appropriate to the router and verifies the exact SHA256 from the release manifest. Use `--source` when a source-tree installation is explicitly required.

After installation:

```sh
universal-openwrt --version
universal-openwrt --self-check
universal-openwrt --plan
```

## External backend

The optional `open-routerich` backend is **not downloaded automatically**. A moving third-party `main` archive is deliberately not trusted. If you need that backend, provide an HTTPS archive URL and its exact SHA256:

```sh
universal-openwrt --install -y \
  --backend-url 'https://example.invalid/backend.tar.gz' \
  --backend-sha256 '<exact-sha256>'
```

The backend is executed only after SHA256 verification. Without both values it remains disabled.

## AI Access Engine

The AI Access Engine diagnoses AI service access by service/domain and separates DNS, DPI, QUIC, IP/geo and authentication failures. It keeps community Zapret/Zapret2 presets as an explicit reserve registry instead of applying third-party rules blindly. See `docs/ai/AI-ACCESS.md`.

## Telegram

- **SOCKS5/TProxy** — transparent router-side Telegram routing through a dedicated sing-box procd service.
- **TG WS** — optional client-facing MTProto WebSocket endpoint using a locally installed compatible binary; the binary is not redistributed.
- **TG failover** — currently switches only between implemented Telegram paths. AWG is not advertised as a Telegram fallback until a dedicated Telegram-to-AWG routing policy exists.

## Tunnel Engine

The VLESS/sing-box Tunnel Engine currently **stores and validates profiles and generates configuration**. `--tunnel-enable` does not claim transparent router-wide traffic activation; full TUN/TProxy service integration remains a separate implementation step.

## Safety defaults

- VPN monitor disabled by default.
- Bootstrap uses the latest GitHub Release packages by default; source installation is opt-in.
- `--self-check` is non-invasive.
- LuCI exposes an allowlisted rpcd API; destructive operations require confirmation.
- Runtime state belongs under `/etc/universal-openwrt`; temporary benchmark data belongs under `/tmp/universal-openwrt`.

## Repository layout

```text
src/                         runtime
installer/                   bootstrap installer
modules/                     local runtime modules
luci-app-universal-openwrt/  LuCI application
packaging/                   init/procd services
resources/                   bundled resource data
tests/                       CI/release tests
tools/                       local asset builder
.github/                     CI/release workflows
docs/                        architecture/install/security docs
```

## Packages

The repository contains unsigned architecture-independent IPK/APK **release assets**. Every release also publishes source archives, `release-manifest.json` and `SHA256SUMS` together on GitHub so the bootstrap can select and verify the correct files automatically. OpenWrt recommends producing production binary packages through the OpenWrt Buildroot or SDK rather than manually assembling package archives.

For OpenWrt 24.10:

```sh
opkg install ./universal-openwrt_30.2.19-1_all.ipk
opkg install ./luci-app-universal-openwrt_30.2.19-1_all.ipk
```

For OpenWrt 25.12:

```sh
apk --allow-untrusted add ./universal-openwrt-30.2.19-r1.apk
apk --allow-untrusted add ./luci-app-universal-openwrt-30.2.19-r1.apk
```

OpenWrt documents the local unsigned APK form above.

## Release notes

- [v30.2.19 release notes](RELEASE_NOTES_v30.2.19.md)
- [Full changelog](CHANGELOG.md)

## Security

Never commit VPN private keys, SOCKS5 passwords, AWG credentials, tokens or generated runtime state. See [`docs/SECURITY.md`](docs/SECURITY.md).

## License

MIT — see [`LICENSE`](LICENSE).


## Telegram SOCKS5 Go

Universal OpenWrt integrates the lightweight `tg-ws-proxy-go` local Telegram bridge used by StressOzz/Zapret-Manager. It exposes a LAN-only SOCKS5 listener (default: the router LAN address on port `1080`; it falls back to `127.0.0.1` if LAN address discovery is unavailable) and sends the Telegram connection onward over WebSocket/TLS, with optional built-in Cloudflare fallback. The binary is downloaded for the detected OpenWrt architecture from the upstream release channel rather than bundled into the architecture-independent package.

## AI / YouTube / Instagram / X access

The access engine uses a service-level decision chain instead of applying one global workaround blindly:

1. direct path;
2. DNS remediation when DNS failure is confirmed;
3. TCP/DPI strategy for transport-level interference;
4. AWG/relay only when the previous class cannot solve the service;
5. for IP/region-style failures, relay/AWG is considered before DPI.

Supported guided targets include ChatGPT/OpenAI, Claude, Gemini, Kimi, DeepSeek, Perplexity, Mistral, Grok, Copilot, Hugging Face, Poe, Cohere, OpenRouter, YouTube, Instagram and X/Twitter.

Read-only diagnosis:

```sh
/usr/sbin/universal-openwrt --ai-diagnose youtube
```

Guarded automatic application with service-level verification and rollback:

```sh
/usr/sbin/universal-openwrt --ai-apply openai
```

Community Zapret/Zapret2 presets remain a reserve source. Zapret1 and Zapret2 strategies are treated as different engines and are never mixed automatically.

## Network source availability

Universal OpenWrt checks GitHub availability at startup. If GitHub is unavailable, existing local resource lists remain usable; raw repository text may fall back to jsDelivr. For restricted networks, release/API mirrors can be supplied with `UOWRT_GITHUB_MIRRORS` (pipe-separated prefixes). Release binaries are still accepted only after SHA256 verification.

## Service groups

The automatic policy is grouped into YouTube, social networks, AI, games, Telegram, messaging, streaming, developer services and news. Each group keeps separate state, cooldown and learned preference. Global backends such as a full-tunnel AWG are applied transactionally and are accepted only when healthy protected groups remain healthy; the project does not pretend that one global tunnel can be independently active for multiple groups.

## Remote WireGuard

Remote WireGuard is remote-access only and is not part of the routing/bypass engine. Adding a device requires only its name. The endpoint, keys and address are generated/discovered automatically; the result is a text configuration and an optional QR code.
