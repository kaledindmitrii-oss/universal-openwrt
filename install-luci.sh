#!/bin/sh
set -eu
REPO="${UOW_REPO:-kaledindmitrii-oss/universal-openwrt}"
REF="${UOW_REF:-main}"
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || true)"

if [ -f "$ROOT/installer/install.sh" ] && [ -f "$ROOT/src/universal-openwrt" ]; then
  exec sh "$ROOT/installer/install.sh" "$@"
fi

TMP="${TMPDIR:-/tmp}/uow-luci-bootstrap.$$"
MIRRORS="${UOWRT_GITHUB_MIRRORS:-}"
cleanup(){ rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
mkdir -p "$TMP"
case "$REF" in
  v[0-9]*|[0-9]*.[0-9]*.[0-9]*) URL="https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz";;
  *) URL="https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz";;
esac
fetch(){
  out="$1"
  candidates="$URL"
  case "$URL" in
    https://raw.githubusercontent.com/*) candidates="$candidates\nhttps://cdn.jsdelivr.net/gh/${REPO}@${REF}/";;
  esac
  oldifs="$IFS"; IFS="\n"
  for candidate in $candidates; do
    [ -n "$candidate" ] || continue
    if command -v uclient-fetch >/dev/null 2>&1 && uclient-fetch -q -T 20 -O "$out" "$candidate" >/dev/null 2>&1; then IFS="$oldifs"; return 0; fi
    if command -v wget >/dev/null 2>&1 && wget -q -T 20 -O "$out" "$candidate" >/dev/null 2>&1; then IFS="$oldifs"; return 0; fi
    if command -v curl >/dev/null 2>&1 && curl -fL --retry 1 --connect-timeout 8 --max-time 120 -o "$out" "$candidate" >/dev/null 2>&1; then IFS="$oldifs"; return 0; fi
  done
  IFS="$oldifs"
  return 1
}
fetch "$TMP/source.tar.gz" || { echo "Universal OpenWrt: download failed: $URL" >&2; exit 1; }
tar -xzf "$TMP/source.tar.gz" -C "$TMP" || { echo "Universal OpenWrt: archive extraction failed" >&2; exit 1; }
SRC="$(find "$TMP" -type f -path '*/installer/install.sh' -print -quit 2>/dev/null || true)"
[ -n "$SRC" ] || { echo "Universal OpenWrt: installer not found in archive" >&2; exit 1; }
exec sh "$(dirname "$SRC")/install.sh" "$@"
