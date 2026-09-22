# Publishing Universal OpenWrt to GitHub

## Recommended flow

The repository is published from the project root with `push-to-github.ps1` (Windows) or normal Git commands. The script initializes Git when the extracted bundle has no `.git` directory, verifies the repository URL, commits the current tree, creates the version tag from `VERSION`, and pushes `main` plus the tag.

After the tag is pushed, `.github/workflows/release.yml` builds and validates IPK/APK packages, generates the source archives, `SHA256SUMS` and `release-manifest.json`, and publishes them as GitHub Release assets.

## Windows

1. Extract `universal-openwrt-v30.2.16.zip`.
2. Open PowerShell in the extracted project directory.
3. Run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\push-to-github.ps1
```

The GitHub account used by Git Credential Manager must have write access to `kaledindmitrii-oss/universal-openwrt`.

## Release assets

The workflow publishes:

- `universal-openwrt-v30.2.16.tar.gz`
- `universal-openwrt-v30.2.16.zip`
- `universal-openwrt_30.2.16-1_all.ipk`
- `luci-app-universal-openwrt_30.2.16-1_all.ipk`
- `universal-openwrt-30.2.16-r1.apk`
- `luci-app-universal-openwrt-30.2.16-r1.apk`
- `release-manifest.json`
- `SHA256SUMS`

The bootstrap installer selects IPK on OpenWrt 24.10.2+ and APK on OpenWrt 25.12.x, then verifies SHA256 before installation.

## Bootstrap

```sh
wget -qO- https://raw.githubusercontent.com/kaledindmitrii-oss/universal-openwrt/main/installer/install.sh | sh
```
