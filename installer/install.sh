#!/bin/sh
# Universal OpenWrt bootstrap installer v30.2.16
# Works when executed from a checkout, a release archive, or directly via:
#   wget -qO- https://raw.githubusercontent.com/kaledindmitrii-oss/universal-openwrt/main/installer/install.sh | sh
set -eu

REPO="${UOW_REPO:-kaledindmitrii-oss/universal-openwrt}"
REF="${UOW_REF:-main}"
TMP="${TMPDIR:-/tmp}/uow-bootstrap.$$"
SRC=""
URL=""
SHA256=""
UNATTENDED=0
PACKAGE_ONLY=0
PACKAGE_DIR=""
RELEASE="${UOW_RELEASE:-}"
USE_SOURCE=0

log(){ printf '[Universal OpenWrt installer] %s\n' "$*"; }
die(){ log "ERROR: $*"; rm -rf "$TMP" 2>/dev/null || true; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
cleanup(){ rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

usage(){
  cat <<USAGE
Universal OpenWrt installer v30.2.16

Direct bootstrap:
  wget -qO- https://raw.githubusercontent.com/${REPO}/main/installer/install.sh | sh
  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/installer/install.sh | sh

Options:
  --url URL            release/source archive URL
  --sha256 HASH        SHA256 for --url archive
  --ref REF            Git branch/tag used by the bootstrap
  --repo OWNER/REPO    GitHub repository
  --dir DIR            unpacked project directory
  FILE                 local .tar.gz/.tgz/.zip archive
  --release TAG        install packages from GitHub Release (default: latest)
  --source             install from source archive/checkout instead of release packages
  --package-dir DIR    install matching .ipk/.apk assets from DIR
  --package-only       install packages only
  -y                   unattended
  -h, --help           help
USAGE
}

fetch(){
  out="$1"; url="$2"
  log "Downloading: $url"
  if have uclient-fetch; then
    uclient-fetch -O "$out" "$url" || return 1
  elif have wget; then
    wget -O "$out" "$url" || return 1
  elif have curl; then
    curl -fL --retry 2 --connect-timeout 10 -o "$out" "$url" || return 1
  else
    return 1
  fi
  [ -s "$out" ]
}

sha256_verify(){
  file="$1"; expected="$2"
  [ -n "$expected" ] || return 0
  have sha256sum || die "sha256sum is required for SHA256 verification"
  printf '%s  %s\n' "$expected" "$file" | sha256sum -c - >/dev/null 2>&1 ||
    die "SHA256 verification failed"
}

extract_archive(){
  archive="$1"; out="$2"; name="$3"
  mkdir -p "$out"
  case "$name" in
    *.zip)
      have unzip || die "unzip is required for ZIP archives"
      unzip -q "$archive" -d "$out" || die "ZIP extraction failed"
      ;;
    *)
      have tar || die "tar is required for tar archives"
      tar -xzf "$archive" -C "$out" || die "tar extraction failed"
      ;;
  esac
}

find_project_root(){
  root="$1"
  if [ -f "$root/src/universal-openwrt" ]; then printf '%s\n' "$root"; return 0; fi
  found="$(find "$root" -type f -path '*/src/universal-openwrt' -print -quit 2>/dev/null || true)"
  [ -n "$found" ] || return 1
  dirname "$(dirname "$found")"
}

install_local_package(){
  pkg="$1"
  case "$pkg" in
    *.ipk)
      have opkg || die "opkg is not available"
      log "Installing IPK: $(basename "$pkg")"
      opkg install "$pkg" || die "opkg installation failed: $(basename "$pkg")"
      ;;
    *.apk)
      have apk || die "apk is not available"
      log "Installing APK: $(basename "$pkg")"
      apk --allow-untrusted add "$pkg" || die "apk installation failed: $(basename "$pkg")"
      ;;
    *) die "unsupported package: $pkg";;
  esac
}

verify_luci(){
  # The luci-app package is not the LuCI shell itself. Require the LuCI
  # collection/core to be installed as well, then verify the actual runtime
  # files that make the Universal OpenWrt menu/RPC page usable.
  . /etc/openwrt_release 2>/dev/null || true
  rel="${DISTRIB_RELEASE:-}"
  case "$rel" in
    24.10.*)
      have opkg || die "LuCI verification requires opkg on OpenWrt $rel"
      opkg status luci >/tmp/uowrt-luci-status.$$ 2>/dev/null || true
      grep -q '^Status:.* installed' /tmp/uowrt-luci-status.$$ || die "LuCI shell package 'luci' is not installed"
      rm -f /tmp/uowrt-luci-status.$$
      opkg status luci-base 2>/dev/null | grep -q '^Status:.* installed' || die "LuCI core package 'luci-base' is not installed"
      ;;
    25.12.*)
      have apk || die "LuCI verification requires apk on OpenWrt $rel"
      apk info -e luci >/dev/null 2>&1 || die "LuCI shell package 'luci' is not installed"
      apk info -e luci-base >/dev/null 2>&1 || die "LuCI core package 'luci-base' is not installed"
      ;;
    *) die "LuCI verification cannot determine OpenWrt release: ${rel:-unknown}";;
  esac

  [ -d /www/luci-static ] || die "LuCI web root is missing: /www/luci-static"
  [ -d /usr/share/luci ] || die "LuCI runtime directory is missing: /usr/share/luci"
  [ -f /usr/share/luci/menu.d/luci-app-universal-openwrt.json ] || die "Universal OpenWrt LuCI menu is missing"
  [ -f /usr/share/rpcd/acl.d/luci-app-universal-openwrt.json ] || die "Universal OpenWrt LuCI ACL is missing"
  [ -f /usr/share/rpcd/ucode/luci.universal_openwrt ] || die "Universal OpenWrt LuCI RPC module is missing"
  [ -f /www/luci-static/resources/view/universal-openwrt/overview.js ] || die "Universal OpenWrt LuCI view is missing"

  # LuCI normally uses uhttpd; tolerate another configured webserver, but
  # never claim the web shell is ready when no webserver is present.
  if [ -x /etc/init.d/uhttpd ] || have uhttpd || [ -x /etc/init.d/nginx ] || have nginx; then
    log "LuCI shell: verified (core, web root, menu, RPC and webserver)"
  else
    die "LuCI files are installed but no supported LuCI webserver (uhttpd/nginx) was detected"
  fi
}

install_luci_package(){
  pkg="$1"
  [ -n "$pkg" ] || die "LuCI package path is empty"
  log "Installing LuCI integration: $(basename "$pkg")"
  install_local_package "$pkg"
  verify_luci
}

release_manifest_url(){
  if [ -n "$RELEASE" ]; then
    printf 'https://github.com/%s/releases/download/%s/release-manifest.json\n' "$REPO" "$RELEASE"
  else
    printf 'https://github.com/%s/releases/latest/download/release-manifest.json\n' "$REPO"
  fi
}

install_release_packages(){
  manifest="$TMP/release-manifest.json"
  url="$(release_manifest_url)"
  mkdir -p "$TMP/release"
  fetch "$manifest" "$url" || die "GitHub release manifest download failed: $url"
  have jsonfilter || die "jsonfilter is required for automatic GitHub release installation"
  rel="$(jsonfilter -q -i "$manifest" -e '@.tag' 2>/dev/null || true)"
  ver="$(jsonfilter -q -i "$manifest" -e '@.version' 2>/dev/null || true)"
  [ -n "$rel" ] || die "release manifest has no tag"
  [ -n "$ver" ] || die "release manifest has no version"
  case "$rel" in v*) ;; *) die "invalid release tag in manifest: $rel";; esac
  case "$ver" in 24.*|25.*|[0-9]*) ;; *) die "invalid release version in manifest: $ver";; esac
  . /etc/openwrt_release
  target_rel="${DISTRIB_RELEASE:-}"
  case "$target_rel" in
    24.10.*) pm=opkg;;
    25.12.*) pm=apk;;
    *) die "Unsupported OpenWrt ${target_rel:-unknown}";;
  esac
  have "$pm" || die "OpenWrt $target_rel requires $pm, but it is not available"
  if [ "$pm" = opkg ]; then
    core="$(jsonfilter -q -i "$manifest" -e '@.packages.opkg.url' 2>/dev/null || true)"
    luci="$(jsonfilter -q -i "$manifest" -e '@.packages.opkg_luci.url' 2>/dev/null || true)"
    core_sha="$(jsonfilter -q -i "$manifest" -e '@.packages.opkg.sha256' 2>/dev/null || true)"
    luci_sha="$(jsonfilter -q -i "$manifest" -e '@.packages.opkg_luci.sha256' 2>/dev/null || true)"
  else
    core="$(jsonfilter -q -i "$manifest" -e '@.packages.apk.url' 2>/dev/null || true)"
    luci="$(jsonfilter -q -i "$manifest" -e '@.packages.apk_luci.url' 2>/dev/null || true)"
    core_sha="$(jsonfilter -q -i "$manifest" -e '@.packages.apk.sha256' 2>/dev/null || true)"
    luci_sha="$(jsonfilter -q -i "$manifest" -e '@.packages.apk_luci.sha256' 2>/dev/null || true)"
  fi
  [ -n "$core" ] || die "No core package URL for $pm in release $rel"
  core_file="$TMP/release/$(basename "$core")"
  fetch "$core_file" "$core" || die "core package download failed"
  sha256_verify "$core_file" "$core_sha"
  install_local_package "$core_file"
  if [ -n "$luci" ]; then
    luci_file="$TMP/release/$(basename "$luci")"
    fetch "$luci_file" "$luci" || die "LuCI package download failed"
    sha256_verify "$luci_file" "$luci_sha"
    install_luci_package "$luci_file"
  else
    die "Release manifest does not contain a LuCI package for $pm"
  fi
  [ -x /usr/sbin/universal-openwrt ] && /usr/sbin/universal-openwrt --self-check || die "post-release self-check failed"
  for f in strategy-engine.sh tunnel-engine.sh tg-ws-proxy.sh; do
    [ -f "/usr/lib/universal-openwrt/$f" ] || die "release package missing runtime module: $f"
  done
  log "GitHub release $rel installed successfully."
}

install_packages(){
  dir="$1"
  pm=""
  if have apk; then pm=apk; elif have opkg; then pm=opkg; else die "No supported package manager (apk/opkg) found"; fi
  log "Detected package manager: $pm"
  # Select only the native package format for the detected OpenWrt generation.
  core=""; luci=""; ext=""
  case "$pm" in opkg) ext=ipk;; apk) ext=apk;; esac
  for p in "$dir"/*.$ext; do
    [ -f "$p" ] || continue
    case "$p" in
      *luci-app-universal-openwrt*.$ext) luci="$p";;
      *universal-openwrt*.$ext) [ -z "$core" ] && core="$p";;
    esac
  done
  [ -n "$core" ] || die "Core package not found in $dir"
  install_local_package "$core"
  [ -n "$luci" ] || die "LuCI package not found in $dir"
  install_luci_package "$luci"
  if [ -x /usr/sbin/universal-openwrt ]; then /usr/sbin/universal-openwrt --self-check || die "post-package self-check failed"; fi
  log "Package installation completed."
}

# Parse arguments before touching the network.
while [ $# -gt 0 ]; do
  case "$1" in
    --url) shift; URL="${1:-}";;
    --sha256) shift; SHA256="${1:-}";;
    --ref) shift; REF="${1:-}";;
    --repo) shift; REPO="${1:-}";;
    --dir) shift; SRC="${1:-}";;
    --release) shift; RELEASE="${1:-}";;
    --source) USE_SOURCE=1;;
    --package-dir) shift; PACKAGE_DIR="${1:-}";;
    --package-only) PACKAGE_ONLY=1;;
    -y) UNATTENDED=1;;
    -h|--help) usage; exit 0;;
    -*) die "unknown option: $1";;
    *) [ -z "$SRC" ] && SRC="$1" || die "multiple source archives/directories supplied";;
  esac
  shift
done

[ "$(id -u 2>/dev/null || echo 1)" = 0 ] || die "root required"

check_target(){
  [ -r /etc/openwrt_release ] || die "This installer requires OpenWrt 24.10.2+ or 25.12.x"
  . /etc/openwrt_release
  rel="${DISTRIB_RELEASE:-}"
  case "$rel" in
    24.10.*)
      patch="${rel#24.10.}"
      case "$patch" in ''|*[!0-9]*) die "Unsupported OpenWrt $rel; minimum supported 24.10.2";; esac
      patch="$(printf '%s' "$patch" | sed 's/^0*//')"; patch="${patch:-0}"
      [ "$patch" -ge 2 ] 2>/dev/null || die "OpenWrt $rel is below minimum supported 24.10.2"
      have opkg || die "OpenWrt $rel detected but opkg is missing"
      ;;
    25.12.*)
      patch="${rel#25.12.}"
      case "$patch" in ''|*[!0-9]*) die "Unsupported OpenWrt $rel";; esac
      have apk || die "OpenWrt $rel detected but apk is missing"
      ;;
    *) die "Unsupported OpenWrt ${rel:-unknown}; supported: OpenWrt 24.10.2+ and 25.12.x";;
  esac
  have fw4 || die "fw4 is required; legacy firewall backends are not supported"
  have nft || die "nft is required; legacy iptables-only environments are not supported"
}

check_target

mkdir -p "$TMP"

if [ "$PACKAGE_ONLY" = 1 ] && [ -z "$PACKAGE_DIR" ]; then
  install_release_packages
  exit 0
fi

if [ "$PACKAGE_ONLY" = 1 ]; then
  [ -n "$PACKAGE_DIR" ] || die "--package-dir is required with --package-only"
  install_packages "$PACKAGE_DIR"
  exit 0
fi

# A plain `wget ... | sh` invocation has no local project files. Prefer the
# signed-off GitHub Release assets unless the caller explicitly requested a
# source checkout/archive. This is the critical bootstrap path.
if [ -z "$SRC" ] && [ -z "$URL" ] && [ "$USE_SOURCE" = 0 ]; then
  install_release_packages
  exit 0
fi

# Explicit source mode keeps checkout/archive installation available.
if [ -z "$SRC" ] && [ -z "$URL" ]; then
  case "$REF" in
    v[0-9]*|[0-9]*.[0-9]*.[0-9]*) URL="https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz";;
    *) URL="https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz";;
  esac
fi

if [ -n "$URL" ]; then
  archive="$TMP/source"
  fetch "$archive" "$URL" || die "download failed; verify internet access, URL and TLS certificates"
  sha256_verify "$archive" "$SHA256"
  mkdir -p "$TMP/src"
  extract_archive "$archive" "$TMP/src" "$URL"
  SRC="$(find_project_root "$TMP/src")" || die "downloaded archive does not contain a valid Universal OpenWrt source tree"
elif [ -f "$SRC" ]; then
  archive="$SRC"
  mkdir -p "$TMP/src"
  extract_archive "$archive" "$TMP/src" "$SRC"
  SRC="$(find_project_root "$TMP/src")" || die "archive does not contain a valid Universal OpenWrt source tree"
fi

[ -d "$SRC" ] || die "source directory not found: $SRC"
[ -f "$SRC/src/universal-openwrt" ] || die "backend missing: $SRC/src/universal-openwrt"
[ -f "$SRC/luci-app-universal-openwrt/Makefile" ] || die "LuCI package source missing"

# If a matching package set is explicitly requested, use the native package manager.
if [ -n "$PACKAGE_DIR" ]; then
  install_packages "$PACKAGE_DIR"
  exit 0
fi

# Direct source installation is architecture independent because the core is shell/ucode/JS.
log "Installing source tree: $SRC"
sh -n "$SRC/src/universal-openwrt" || die "backend syntax check failed"
sh -n "$SRC/packaging/root/etc/init.d/universal-openwrt-vpn-monitor" || die "monitor init syntax check failed"

mkdir -p /usr/sbin /usr/lib/universal-openwrt /etc/init.d
cp -f "$SRC/src/universal-openwrt" /usr/sbin/universal-openwrt
chmod 0755 /usr/sbin/universal-openwrt
if [ -d "$SRC/modules" ]; then
  rm -f /usr/lib/universal-openwrt/*.sh 2>/dev/null || true
  for f in "$SRC"/modules/*.sh; do [ -f "$f" ] || continue; cp -f "$f" /usr/lib/universal-openwrt/; chmod 0755 "/usr/lib/universal-openwrt/$(basename "$f")"; done
else
  die "runtime modules directory missing: $SRC/modules"
fi
if [ -d "$SRC/resources" ]; then
  rm -rf /usr/lib/universal-openwrt/test-resources
  cp -R "$SRC/resources" /usr/lib/universal-openwrt/test-resources
fi
for f in "$SRC"/packaging/root/etc/init.d/*; do
  [ -f "$f" ] || continue
  cp -f "$f" /etc/init.d/
  chmod 0755 "/etc/init.d/$(basename "$f")"
done

# Source mode is only valid when the actual LuCI shell is already present.
# The release/package path installs the full `luci` collection automatically.
if [ -d "$SRC/luci-app-universal-openwrt" ] && [ -d /usr/share/rpcd ]; then
  APP="$SRC/luci-app-universal-openwrt"
  verify_luci
  mkdir -p /usr/share/luci/menu.d /usr/share/rpcd/acl.d /usr/share/rpcd/ucode \
    /www/luci-static/resources/view/universal-openwrt
  cp -f "$APP/root/usr/share/luci/menu.d/luci-app-universal-openwrt.json" /usr/share/luci/menu.d/
  cp -f "$APP/root/usr/share/rpcd/acl.d/luci-app-universal-openwrt.json" /usr/share/rpcd/acl.d/
  cp -f "$APP/root/usr/share/rpcd/ucode/luci.universal_openwrt" /usr/share/rpcd/ucode/
  chmod 0755 /usr/share/rpcd/ucode/luci.universal_openwrt
  cp -f "$APP/htdocs/luci-static/resources/view/universal-openwrt/overview.js" /www/luci-static/resources/view/universal-openwrt/
  /etc/init.d/rpcd reload >/dev/null 2>&1 || true
else
  die "LuCI runtime is unavailable; install the full LuCI shell before source installation"
fi
verify_luci

/usr/sbin/universal-openwrt --self-check || die "post-install self-check failed"
for f in strategy-engine.sh tunnel-engine.sh tg-ws-proxy.sh ; do [ -f "/usr/lib/universal-openwrt/$f" ] || die "post-install module missing: $f"; done
# Only install init scripts that actually exist in the release tree.
for f in "$SRC"/packaging/root/etc/init.d/*; do [ -f "$f" ] || continue; sh -n "$f" || die "init script syntax check failed: $(basename "$f")"; done
log "Installation completed successfully."
log "Run: universal-openwrt --plan"
log "Full setup: universal-openwrt --install -y"
log "VPN monitor remains disabled by default."
