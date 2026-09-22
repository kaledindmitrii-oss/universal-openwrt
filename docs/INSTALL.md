# Installation

## Supported platforms

- OpenWrt **24.10.2+** — `opkg` + `fw4`/`nftables` (legacy-supported).
- OpenWrt **25.12.x** — `apk` + `fw4`/`nftables` (primary target).

OpenWrt 18.06–23.05, fw3 and iptables-only environments are outside the project scope and are rejected by the installer.

## Supported installation modes

1. GitHub release archive.
2. Local tar.gz/zip archive.
3. Unpacked release directory.

The installer validates shell syntax before replacing the runtime. Existing user configuration is preserved.

## Safety defaults

- VPN monitor disabled.
- No automatic full installation during bootstrap.
- `--self-check` is non-invasive.
- LuCI exposes allowlisted backend actions through rpcd ACLs.

## Recommended sequence

```sh
universal-openwrt --version
universal-openwrt --self-check
universal-openwrt --diagnose
universal-openwrt --plan
```

Only after reviewing the plan:

```sh
universal-openwrt --install -y \
  --backend-url 'https://example.invalid/backend.tar.gz' \
  --backend-sha256 '<exact-sha256>'
```


## Direct GitHub installation

The bootstrap installer can be executed directly from GitHub without downloading the repository manually:

```sh
wget -qO- https://raw.githubusercontent.com/kaledindmitrii-oss/universal-openwrt/main/installer/install.sh | sh
```

The bootstrap downloads the selected branch archive, detects the source tree, validates shell syntax, installs the runtime/LuCI files, and runs a post-install self-check. For reproducible installs use `UOW_REF=v30.2.9`; branch installs remain development installs. The external open-routerich backend is disabled by default; enabling it requires both `UOW_BACKEND_URL` and `UOW_BACKEND_SHA256`.

## Native packages

`assets/ipk/` contains architecture-independent IPK packages for opkg-based OpenWrt.
`assets/apk/` contains unsigned APK packages for apk-based OpenWrt 25.12+.

Examples:

```sh
opkg install ./assets/ipk/universal-openwrt_30.2.9-1_all.ipk
opkg install ./assets/ipk/luci-app-universal-openwrt_30.2.9-1_all.ipk
```

```sh
apk add --allow-untrusted ./assets/apk/universal-openwrt-30.2.9-r1.apk
apk add --allow-untrusted ./assets/apk/luci-app-universal-openwrt-30.2.9-r1.apk
```

The bundled APK/IPK files are test assets. OpenWrt recommends producing binary packages with the SDK/Buildroot rather than manually assembling them; for a production feed, replace these unsigned assets with SDK-built packages.
