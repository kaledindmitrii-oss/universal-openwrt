#!/bin/sh
# Universal OpenWrt source resolver.
# Checks GitHub first, then uses configured mirrors or CDN fallbacks for
# repository/raw content. Mirrors never bypass TLS verification and downloaded
# release artifacts must still be verified by their expected SHA256.

UOWRT_SOURCE_STATE="${UOWRT_SOURCE_STATE:-/etc/universal-openwrt/source-state}"
UOWRT_GITHUB_MIRRORS="${UOWRT_GITHUB_MIRRORS:-}"
UOWRT_GITHUB_MIRROR_PREFIX="${UOWRT_GITHUB_MIRROR_PREFIX:-}"
UOWRT_SOURCE_CONF="${UOWRT_SOURCE_CONF:-/etc/universal-openwrt/source.conf}"

# Optional persistent mirror configuration. Mirrors are explicit operator choices;
# TLS verification is never disabled and no arbitrary proxy is enabled by default.
uowrt_source_load_config(){
  [ -r "$UOWRT_SOURCE_CONF" ] && . "$UOWRT_SOURCE_CONF" 2>/dev/null || true
}
uowrt_source_load_config


uowrt_source_have(){ command -v "$1" >/dev/null 2>&1; }
uowrt_source_fetch(){
  _out="$1"; _url="$2"
  if uowrt_source_have uclient-fetch; then uclient-fetch -q -T 12 -O "$_out" "$_url" && [ -s "$_out" ] && return 0; fi
  if uowrt_source_have wget; then wget -q -T 12 -O "$_out" "$_url" && [ -s "$_out" ] && return 0; fi
  if uowrt_source_have curl; then curl -fsSL --connect-timeout 6 --max-time 20 "$_url" -o "$_out" && [ -s "$_out" ] && return 0; fi
  rm -f "$_out" 2>/dev/null || true
  return 1
}

uowrt_github_status(){
  _state="unknown"; _source="none"
  if uowrt_source_fetch /tmp/uowrt-gh-check.$$ https://api.github.com/ >/dev/null 2>&1; then _state=online; _source=github-api
  elif uowrt_source_fetch /tmp/uowrt-gh-check.$$ https://github.com/ >/dev/null 2>&1; then _state=online; _source=github
  else
    _raw_ok=0
    uowrt_source_fetch /tmp/uowrt-gh-check.$$ https://raw.githubusercontent.com/ >/dev/null 2>&1 && _raw_ok=1 || true
    [ "$_raw_ok" = 1 ] && { _state=online; _source=github-raw; }
  fi
  rm -f /tmp/uowrt-gh-check.$$ 2>/dev/null || true
  if [ "$_state" != online ] && [ -n "$UOWRT_GITHUB_MIRRORS" ]; then
    OLDIFS="$IFS"; IFS='|'
    for _m in $UOWRT_GITHUB_MIRRORS; do
      [ -n "$_m" ] || continue
      case "$_m" in
        */) _probe="${_m}https://github.com/";;
        *) _probe="${_m}/https://github.com/";;
      esac
      if uowrt_source_fetch /tmp/uowrt-gh-check.$$ "$_probe" >/dev/null 2>&1; then _state=mirror; _source="$_m"; break; fi
    done
    IFS="$OLDIFS"
    rm -f /tmp/uowrt-gh-check.$$ 2>/dev/null || true
  fi
  mkdir -p "$(dirname "$UOWRT_SOURCE_STATE")" 2>/dev/null || true
  printf 'status=%s\nsource=%s\nts=%s\n' "$_state" "$_source" "$(date +%s)" >"$UOWRT_SOURCE_STATE" 2>/dev/null || true
  printf 'github_status=%s\ngithub_source=%s\n' "$_state" "$_source"
  [ "$_state" = online ] || [ "$_state" = mirror ]
}

uowrt_source_status(){
  [ -s "$UOWRT_SOURCE_STATE" ] && cat "$UOWRT_SOURCE_STATE" || uowrt_github_status
}

# Convert raw GitHub URLs to a jsDelivr CDN URL. This is used only for source
# text/static repository content; release binaries still require a SHA256.
uowrt_jsdelivr_url(){
  case "$1" in
    https://raw.githubusercontent.com/*/*/*/*)
      _p="${1#https://raw.githubusercontent.com/}"; _owner="${_p%%/*}"; _rest="${_p#*/}"; _repo="${_rest%%/*}"; _rest="${_rest#*/}"; printf 'https://cdn.jsdelivr.net/gh/%s/%s@%s\n' "$_owner" "$_repo" "$_rest";;
    *) return 1;;
  esac
}

uowrt_fetch(){
  _out="$1"; _url="$2"
  if uowrt_source_fetch "$_out" "$_url"; then return 0; fi
  _js="$(uowrt_jsdelivr_url "$_url" 2>/dev/null || true)"
  if [ -n "$_js" ] && uowrt_source_fetch "$_out" "$_js"; then return 0; fi
  if [ -n "$UOWRT_GITHUB_MIRROR_PREFIX" ]; then
    case "$UOWRT_GITHUB_MIRROR_PREFIX" in
      */) _u="${UOWRT_GITHUB_MIRROR_PREFIX}${_url}";;
      *) _u="${UOWRT_GITHUB_MIRROR_PREFIX}/${_url}";;
    esac
    if uowrt_source_fetch "$_out" "$_u"; then return 0; fi
  fi
  if [ -n "$UOWRT_GITHUB_MIRRORS" ]; then
    OLDIFS="$IFS"; IFS='|'
    for _m in $UOWRT_GITHUB_MIRRORS; do
      [ -n "$_m" ] || continue
      case "$_m" in */) _u="${_m}${_url}";; *) _u="${_m}/${_url}";; esac
      if uowrt_source_fetch "$_out" "$_u"; then IFS="$OLDIFS"; return 0; fi
    done
    IFS="$OLDIFS"
  fi
  return 1
}
