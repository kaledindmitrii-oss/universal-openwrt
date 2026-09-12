#!/bin/sh
# Universal OpenWrt installer v30
set -u
PREFIX=/usr
APP=/usr/lib/universal-openwrt
ETC=/etc/universal-openwrt
TMP=/tmp/uow-install.$$
SRC=""
URL=""
SHA256=""

log(){ printf '[Universal OpenWrt] %s\n' "$*"; }
die(){ log "ERROR: $*"; rm -rf "$TMP"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
root_check(){ [ "$(id -u 2>/dev/null || echo 1)" = 0 ] || die 'root required'; }
fetch(){ out="$1"; url="$2"; if have uclient-fetch; then uclient-fetch -q -O "$out" "$url"; elif have wget; then wget -q -O "$out" "$url"; elif have curl; then curl -fsSL -o "$out" "$url"; else return 1; fi; }
usage(){ cat <<USAGE
Universal OpenWrt v30 installer
  --url URL          download release archive
  --sha256 HASH      verify archive SHA256
  --dir DIR          install from unpacked release directory
  FILE               local .tar.gz/.tgz/.zip archive
  -y                 unattended
USAGE
}
while [ $# -gt 0 ]; do case "$1" in
  --url) shift; URL="${1:-}";;
  --sha256) shift; SHA256="${1:-}";;
  --dir) shift; SRC="${1:-}";;
  -y) :;;
  -h|--help) usage; exit 0;;
  *) [ -z "$SRC" ] && SRC="$1" || die "unknown argument: $1";;
esac; shift; done
root_check
mkdir -p "$TMP" "$ETC" "$APP" || die 'cannot create directories'

if [ -n "$URL" ]; then
  log 'Downloading release archive...'
  fetch "$TMP/release" "$URL" || die 'download failed'
  if [ -n "$SHA256" ]; then
    have sha256sum || die 'sha256sum required for --sha256'
    printf '%s  %s\n' "$SHA256" "$TMP/release" | sha256sum -c - >/dev/null 2>&1 || die 'SHA256 verification failed'
  fi
  SRC="$TMP/src"; mkdir -p "$SRC"
  case "$URL" in *.zip) have unzip || die 'unzip required'; unzip -q "$TMP/release" -d "$SRC" || die 'unzip failed';; *) have tar || die 'tar required'; tar -xzf "$TMP/release" -C "$SRC" || die 'tar extraction failed';; esac
elif [ -n "$SRC" ] && [ -f "$SRC" ]; then
  ARCHIVE="$SRC"; SRC="$TMP/src"; mkdir -p "$SRC"
  case "$ARCHIVE" in *.zip) have unzip || die 'unzip required'; unzip -q "$ARCHIVE" -d "$SRC" || die 'unzip failed';; *) tar -xzf "$ARCHIVE" -C "$SRC" || die 'tar extraction failed';; esac
fi
[ -d "$SRC" ] || die 'source directory not found'
MAIN="$(find "$SRC" -type f -name universal-openwrt -print -quit 2>/dev/null)"
[ -n "$MAIN" ] || MAIN="$(find "$SRC" -type f -name 'run_universal_openwrt_v*.sh' -print -quit 2>/dev/null)"
[ -n "$MAIN" ] || die 'main runtime not found'
sh -n "$MAIN" || die 'runtime syntax check failed'
ROOTDIR="$(dirname "$MAIN")/.."; [ -d "$ROOTDIR" ] || ROOTDIR="$(dirname "$MAIN")"

# Install runtime and immutable bundled resources.
mkdir -p /usr/sbin "$APP" /etc/init.d
cp -f "$MAIN" /usr/sbin/universal-openwrt || die 'runtime install failed'
chmod 0755 /usr/sbin/universal-openwrt
BUNDLE="$(dirname "$MAIN")/../resources"; [ -d "$BUNDLE" ] || BUNDLE="$(dirname "$MAIN")/../test-resources"
if [ -d "$BUNDLE" ]; then rm -rf "$APP/test-resources"; cp -R "$BUNDLE" "$APP/test-resources"; fi
INITROOT="$(dirname "$MAIN")/../packaging/root/etc/init.d"; [ -d "$INITROOT" ] || INITROOT="$(dirname "$MAIN")/../root/etc/init.d"
[ -d "$INITROOT" ] && cp -f "$INITROOT"/* /etc/init.d/ 2>/dev/null || true

# Preserve user config.
[ -f "$ETC/install.conf" ] || cat > "$ETC/install.conf" <<CFG
UOW_VERSION=30
AUTO_UPDATE=0
MONITOR_ENABLED=0
CFG
[ -f "$ETC/install.conf" ] && sed -i 's/^UOW_VERSION=.*/UOW_VERSION=30/' "$ETC/install.conf" 2>/dev/null || true
if [ -x /etc/init.d/universal-openwrt ]; then /etc/init.d/universal-openwrt disable >/dev/null 2>&1 || true; fi
if [ -x /etc/init.d/universal-openwrt-vpn-monitor ]; then /etc/init.d/universal-openwrt-vpn-monitor disable >/dev/null 2>&1 || true; fi

/usr/sbin/universal-openwrt --self-check >/tmp/uow-self-check.$$.log 2>&1 || { cat /tmp/uow-self-check.$$.log; die 'post-install self-check failed'; }
cat /tmp/uow-self-check.$$.log
rm -f /tmp/uow-self-check.$$.log
rm -rf "$TMP"
log 'Installation completed.'
log 'Run: universal-openwrt --plan'
log 'Full setup: universal-openwrt --install -y'
log 'Network/VPN monitor remains disabled by default.'
