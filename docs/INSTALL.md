# Installation

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
universal-openwrt --install -y
```
