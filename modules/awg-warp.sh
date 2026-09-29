#!/bin/sh
# Universal OpenWrt AWG/WARP bootstrap.
# Supports two deliberately separate sources of tunnel configuration:
#   provider = an actual AmneziaWG .conf supplied by the user/provider
#   warp     = Cloudflare WARP's native WireGuard-compatible configuration
# WARP is NOT treated as an obfuscated AmneziaWG profile: it has no J/S/H
# parameters and therefore is a VPN transport/fallback, not an AWG DPI profile.
# No private keys are sent anywhere except the WARP registration endpoint as
# the public key; the generated private key is stored locally with mode 600.
set -eu

REPO="${UOWRT_AWG_REPO:-2Grey/awg-openwrt}"
IFACE="awg10"
LAN_ZONE="lan"
MODE="${UOWRT_AWG_MODE:-auto}"
AWG_PROFILE="${UOWRT_AWG_PROFILE:-3.1}"
CONFIG_INPUT="${UOWRT_AWG_CONFIG:-}"
BASE="https://github.com/${REPO}"
API="https://api.github.com/repos/${REPO}"
UOWRT_LIB_DIR="${UOWRT_LIB_DIR:-/usr/lib/universal-openwrt}"
[ -f "$UOWRT_LIB_DIR/source-resolver.sh" ] && . "$UOWRT_LIB_DIR/source-resolver.sh" 2>/dev/null || true
CF_API="https://api.cloudflareclient.com/v0a2158/reg"
STATE_DIR="/etc/universal-openwrt/awg"
IDENTITY="$STATE_DIR/warp-identity.json"
CONF="$STATE_DIR/awg.conf"
TMP="${TMPDIR:-/tmp}/uowrt-awg.$$"

log(){ printf '[AWG] %s\n' "$*"; }
die(){ log "ERROR: $*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
usage(){
  cat <<EOF
Usage: awg-warp.sh [--iface IFACE] [--lan-zone ZONE] [--mode auto|warp|provider] [--profile 3.1] [--config FILE]
  --mode warp      Register/reuse Cloudflare WARP and build a native WG-compatible config.
  --mode provider  Import an existing AmneziaWG provider .conf; no Cloudflare registration.
  --mode auto      Use provider config when supplied, otherwise WARP.
EOF
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --iface) shift; IFACE="${1:-}";;
    --lan-zone) shift; LAN_ZONE="${1:-}";;
    --mode) shift; MODE="${1:-}";;
    --profile) shift; AWG_PROFILE="${1:-}";;
    --config) shift; CONFIG_INPUT="${1:-}";;
    --iface=*) IFACE="${1#*=}";;
    --lan-zone=*) LAN_ZONE="${1#*=}";;
    --mode=*) MODE="${1#*=}";;
    --profile=*) AWG_PROFILE="${1#*=}";;
    --config=*) CONFIG_INPUT="${1#*=}";;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1";;
  esac
  shift
done
case "$MODE" in auto|warp|provider) ;; *) die "Invalid AWG mode: $MODE";; esac
case "$AWG_PROFILE" in 3.1) ;; *) die "Only AWG 3.1 is supported for the OpenWrt 24.10.8 profile";; esac
[ -n "$IFACE" ] || die 'Interface name is required'
[ -n "$LAN_ZONE" ] || die 'LAN firewall zone is required'
cleanup(){ rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

fetch(){
  out="$1"; url="$2"
  # Never disable TLS verification. GitHub metadata/assets use the shared source resolver.
  if command -v uowrt_fetch >/dev/null 2>&1; then uowrt_fetch "$out" "$url"; return $?; fi
  if have uclient-fetch; then uclient-fetch -q -O "$out" "$url"; return $?; fi
  if have wget; then wget -q -O "$out" "$url"; return $?; fi
  if have curl; then curl -fsSL --connect-timeout 15 --max-time 180 -o "$out" "$url"; return $?; fi
  return 127
}

post_json(){
  out="$1"; url="$2"; body="$3"
  if have curl; then
    curl -fsSL --connect-timeout 15 --max-time 60 \
      -H 'User-Agent: Universal-OpenWrt' \
      -H 'Content-Type: application/json' \
      -H 'CF-Client-Version: a-6.10-2158' \
      --data "$body" -o "$out" "$url"
  else
    # BusyBox wget/uclient-fetch cannot reliably express the required headers
    # on all supported builds; require curl for the registration transaction.
    return 127
  fi
}

patch_json(){
  out="$1"; url="$2"; token="$3"; body="$4"
  curl -fsSL --connect-timeout 15 --max-time 60 \
    -H 'User-Agent: Universal-OpenWrt' \
    -H 'CF-Client-Version: a-6.10-2158' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $token" \
    -X PATCH --data "$body" -o "$out" "$url"
}

get_json(){
  out="$1"; url="$2"; token="${3:-}"
  if have curl; then
    if [ -n "$token" ]; then
      curl -fsSL --connect-timeout 15 --max-time 60 \
        -H 'User-Agent: Universal-OpenWrt' \
        -H 'CF-Client-Version: a-6.10-2158' \
        -H "Authorization: Bearer $token" -o "$out" "$url"
    else
      curl -fsSL --connect-timeout 15 --max-time 60 \
        -H 'User-Agent: Universal-OpenWrt' \
        -H 'CF-Client-Version: a-6.10-2158' -o "$out" "$url"
    fi
  else
    return 127
  fi
}

json(){
  file="$1"; expr="$2"
  have jsonfilter || die 'jsonfilter is required for automatic AWG configuration'
  jsonfilter -q -i "$file" -e "$expr" 2>/dev/null || true
}

ensure_http_client(){
  if have curl; then return 0; fi
  log 'curl is required for WARP registration; installing it automatically.'
  if have opkg; then
    opkg update >/dev/null 2>&1 || true
    opkg install curl ca-bundle >/dev/null 2>&1 || true
  elif have apk; then
    apk add curl ca-certificates >/dev/null 2>&1 || true
  fi
  have curl || die 'curl could not be installed automatically; WARP registration cannot continue'
}

openwrt_release(){
  . /etc/openwrt_release 2>/dev/null || true
  OWVER="${DISTRIB_RELEASE:-unknown}"
  case "$OWVER" in
    24.10.8) ;;
    *) die "Unsupported OpenWrt $OWVER: this AWG profile is pinned to OpenWrt 24.10.8";;
  esac
  TARGET="${DISTRIB_TARGET:-}"
  SUBTARGET="$(printf '%s' "$TARGET" | awk -F/ '{print $2}')"
  [ -n "$SUBTARGET" ] || die 'Cannot determine OpenWrt subtarget'
  ARCH="${DISTRIB_ARCH:-}"
  [ -n "$ARCH" ] || ARCH="$(opkg print-architecture 2>/dev/null | awk 'NR>1{print $2}' | tail -n1)"
  [ -n "$ARCH" ] || die 'Cannot determine OpenWrt architecture'
  KERNEL="$(uname -r)"
  PM=none; have apk && PM=apk; have opkg && PM=opkg
  [ "$PM" != none ] || die 'No supported package manager (opkg/apk)'
  log "Detected OpenWrt=$OWVER target=$TARGET arch=$ARCH kernel=$KERNEL pm=$PM"
}

release_tag(){ printf 'v%s\n' "$OWVER"; }

asset_names(){
  api_json="$TMP/release.json"
  fetch "$api_json" "$API/releases/tags/$(release_tag)" || die "Cannot query AWG release $(release_tag)"
  json "$api_json" '@.assets[*].name' > "$TMP/assets.names"
  json "$api_json" '@.assets[*].digest' > "$TMP/assets.digests"
  [ -s "$TMP/assets.names" ] || die 'AWG release has no assets'
}

find_asset(){
  pattern="$1"
  grep -E "$pattern" "$TMP/assets.names" | head -n1 || true
}
asset_digest(){
  name="$1"
  line="$(grep -n -F -x "$name" "$TMP/assets.names" | head -n1 | cut -d: -f1)"
  [ -n "$line" ] || return 1
  sed -n "${line}p" "$TMP/assets.digests" 2>/dev/null || true
}

asset_url(){
  name="$1"
  [ -n "$name" ] || return 1
  # Asset names are resolved from the official release index first; the
  # browser_download_url is equivalent to the deterministic release URL.
  printf '%s/releases/download/%s/%s\n' "$BASE" "$(release_tag)" "$name"
}

install_pkg(){
  pkg="$1"
  case "$pkg" in
    *.ipk) opkg install "$pkg" >/dev/null || return 1;;
    *.apk) apk --allow-untrusted add "$pkg" >/dev/null || return 1;;
    *) return 1;;
  esac
}

remove_conflicting_luci(){
  if [ "$PM" = "opkg" ] && opkg list-installed 2>/dev/null | grep -q "^luci-app-amneziawg[[:space:]]"; then
    log "Removing conflicting legacy luci-app-amneziawg package before installing luci-proto-amneziawg."
    opkg remove luci-app-amneziawg >/dev/null 2>&1 || die "Cannot remove conflicting luci-app-amneziawg package"
  fi
}

verify_awg31_tools(){
  have awg || die 'amneziawg-tools did not install /usr/bin/awg'
  version="$(awg --version 2>/dev/null || true)"
  printf '%s\n' "$version" | grep -Eq 'v?3\.1\.' || die "Installed awg-tools is not AWG 3.1: $version"
}

verify_kmod_kernel_abi(){
  [ "$PM" = opkg ] || return 0
  command -v tar >/dev/null 2>&1 || die 'tar is required to inspect kmod package ABI'
  installed_kernel="$(opkg status kernel 2>/dev/null | sed -n 's/^Version: //p' | head -n1)"
  [ -n "$installed_kernel" ] || die 'Cannot determine installed kernel package ABI'
  file="$1"
  control="$(tar -xzOf "$file" ./control.tar.gz 2>/dev/null | tar -xzOf - ./control 2>/dev/null || true)"
  [ -n "$control" ] || die "Cannot inspect kernel dependency in $file"
  required_kernel="$(printf '%s\n' "$control" | sed -n 's/^Depends: .*kernel[[:space:]]*(=[[:space:]]*\([^)]*\)).*/\1/p' | head -n1)"
  [ -n "$required_kernel" ] || die "kmod package $file does not declare an exact kernel dependency"
  [ "$required_kernel" = "$installed_kernel" ] || die "Kernel ABI mismatch: installed=$installed_kernel required=$required_kernel"
  log "Kernel ABI verified: $required_kernel"
}

install_awg_packages(){
  remove_conflicting_luci
  asset_names
  suffix="${ARCH}_${TARGET#*/}_${SUBTARGET}"
  [ "$OWVER" = "24.10.8" ] || die "AWG package source is pinned to OpenWrt 24.10.8"
  # amneziawg-tools is architecture/target independent of the kernel ABI.
  # kmod-amneziawg is selected from the release asset set and then installed;
  # this prevents an incompatible kernel module from being guessed by CPU arch.
  if [ "$PM" = opkg ]; then ext='ipk'; else ext='apk'; fi
  tools="$(find_asset "^amneziawg-tools_v${OWVER}_${ARCH}_${TARGET#*/}_${SUBTARGET}\\.${ext}$")"
  [ -n "$tools" ] || tools="$(find_asset "^amneziawg-tools_.*_${ARCH}_${TARGET#*/}_${SUBTARGET}\\.${ext}$")"
  proto="$(find_asset "^luci-proto-amneziawg_v${OWVER}_${ARCH}_${TARGET#*/}_${SUBTARGET}\\.${ext}$")"
  kmod="$(find_asset "^kmod-amneziawg_.*_${ARCH}_${TARGET#*/}_${SUBTARGET}\\.${ext}$")"
  [ -n "$tools" ] || die "No amneziawg-tools asset for $ARCH/$TARGET/$SUBTARGET/$OWVER"
  [ -n "$kmod" ] || die "No kernel-matched kmod-amneziawg asset for $ARCH/$TARGET/$SUBTARGET/$OWVER"
  [ -n "$proto" ] || die "No target-matched luci-proto-amneziawg asset for $ARCH/$TARGET/$SUBTARGET/$OWVER"

  mkdir -p "$TMP/pkg"
  for name in "$tools" "$kmod" "$proto"; do
    url="$(asset_url "$name")"
    file="$TMP/pkg/$name"
    log "Downloading $(basename "$name")"
    fetch "$file" "$url" || die "Download failed: $name"
    digest="$(asset_digest "$name")"
    case "$digest" in
      sha256:*) expected="${digest#sha256:}";;
      *) die "Release asset has no SHA256 digest: $name";;
    esac
    actual="$(sha256sum "$file" 2>/dev/null | awk '{print $1}')"
    [ -n "$actual" ] && [ "$actual" = "$expected" ] || die "SHA256 verification failed: $name"
    case "$name" in
      kmod-amneziawg_*) verify_kmod_kernel_abi "$file";;
    esac
    install_pkg "$file" || die "Package installation failed: $name"
  done
  verify_awg31_tools
  log 'AmneziaWG 3.1 packages installed from the OpenWrt 24.10.8 device-matched release.'
}

random_id(){
  tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 22 || date +%s
}

gen_private_key(){
  if have awg; then awg genkey; elif have wg; then wg genkey; else die 'awg/wg key generator missing after package installation'; fi
}
gen_public_key(){
  key="$1"
  if have awg; then printf '%s\n' "$key" | awg pubkey; elif have wg; then printf '%s\n' "$key" | wg pubkey; else die 'awg/wg public-key generator missing'; fi
}

register_warp(){
  mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"
  if [ -s "$IDENTITY" ] && [ -s "$CONF" ]; then
    log 'Existing WARP identity and config found; reusing them.'
    return 0
  fi
  private_key="$(gen_private_key)"
  public_key="$(gen_public_key "$private_key")"
  [ -n "$private_key" ] && [ -n "$public_key" ] || die 'Failed to generate WireGuard keypair'
  install_id="$(random_id)"
  tos="$(date -u '+%Y-%m-%dT%H:%M:%S.000Z')"
  body="{\"key\":\"$public_key\",\"install_id\":\"$install_id\",\"fcm_token\":\"\",\"tos\":\"$tos\",\"model\":\"OpenWrt\",\"serial_number\":\"$install_id\",\"locale\":\"en_US\"}"
  response="$TMP/register.json"
  log 'Registering a new Cloudflare WARP device and retrieving its configuration.'
  post_json "$response" "$CF_API" "$body" || die 'Cloudflare WARP registration failed'
  id="$(json "$response" '@.result.id')"
  token="$(json "$response" '@.result.token')"
  [ -n "$id" ] && [ -n "$token" ] || die 'WARP registration response did not contain result.id/result.token'

  patch_json "$TMP/warp-enable.json" "$CF_API/$id" "$token" '{"warp_enabled":true}' || die 'Cannot enable WARP on the registered device'
  get_json "$TMP/device.json" "$CF_API/$id" "$token" || die 'Cannot retrieve WARP device configuration'
  v4="$(json "$TMP/device.json" '@.result.config.interface.addresses.v4')"
  v6="$(json "$TMP/device.json" '@.result.config.interface.addresses.v6')"
  peer_key="$(json "$TMP/device.json" '@.result.config.peers[0].public_key')"
  endpoint="$(json "$TMP/device.json" '@.result.config.peers[0].endpoint.host')"
  [ -n "$v4" ] && [ -n "$peer_key" ] && [ -n "$endpoint" ] || die 'WARP configuration response is incomplete'
  [ "${v4#*/}" != "$v4" ] || v4="$v4/32"
  [ -z "$v6" ] || [ "${v6#*/}" != "$v6" ] || v6="$v6/128"
  cat > "$CONF" <<CFG
[Interface]
PrivateKey = $private_key
Address = $v4
${v6:+Address = $v6}
DNS = 1.1.1.1

[Peer]
PublicKey = $peer_key
AllowedIPs = 0.0.0.0/0
${v6:+AllowedIPs = ::/0}
Endpoint = $endpoint
PersistentKeepalive = 25
CFG
  chmod 600 "$CONF"
  cat > "$IDENTITY" <<JSON
{
  "provider": "cloudflare-warp",
  "transport": "wireguard-compatible",
  "device_id": "$id",
  "access_token": "$token",
  "private_key": "$private_key",
  "public_key": "$public_key",
  "endpoint": "$endpoint"
}
JSON
  chmod 600 "$IDENTITY"
  log 'WARP identity, keys and endpoint/address configuration saved locally.'
}

validate_conf(){
  file="$1"
  [ -s "$file" ] || die "Configuration file is empty: $file"
  chmod 600 "$file" 2>/dev/null || true
  PRIVATE_KEY="$(sed -n 's/^[[:space:]]*PrivateKey[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  ADDRESS_LINES="$(sed -n 's/^[[:space:]]*Address[[:space:]]*=[[:space:]]*//p' "$file" | tr ',' ' ')"
  PEER_KEY="$(sed -n 's/^[[:space:]]*PublicKey[[:space:]]*=[[:space:]]*//p' "$file" | tail -n1)"
  ENDPOINT="$(sed -n 's/^[[:space:]]*Endpoint[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  ALLOWED="$(sed -n 's/^[[:space:]]*AllowedIPs[[:space:]]*=[[:space:]]*//p' "$file" | tr ',' ' ')"
  DNS_LINES="$(sed -n 's/^[[:space:]]*DNS[[:space:]]*=[[:space:]]*//p' "$file" | tr ',' ' ')"
  LISTEN_PORT="$(sed -n 's/^[[:space:]]*ListenPort[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  MTU="$(sed -n 's/^[[:space:]]*MTU[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  [ -n "$PRIVATE_KEY" ] && [ -n "$ADDRESS_LINES" ] && [ -n "$PEER_KEY" ] && [ -n "$ENDPOINT" ] && [ -n "$ALLOWED" ] || die 'AmneziaWG config is missing PrivateKey/Address/Peer PublicKey/Endpoint/AllowedIPs'
  # AWG 2.x/3.x parameters are read exactly as exported by the provider.
  AWG_JC="$(sed -n 's/^[[:space:]]*Jc[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_JMIN="$(sed -n 's/^[[:space:]]*Jmin[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_JMAX="$(sed -n 's/^[[:space:]]*Jmax[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_S1="$(sed -n 's/^[[:space:]]*S1[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_S2="$(sed -n 's/^[[:space:]]*S2[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_H1="$(sed -n 's/^[[:space:]]*H1[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_H2="$(sed -n 's/^[[:space:]]*H2[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_H3="$(sed -n 's/^[[:space:]]*H3[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_H4="$(sed -n 's/^[[:space:]]*H4[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_S3="$(sed -n 's/^[[:space:]]*S3[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_S4="$(sed -n 's/^[[:space:]]*S4[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_I1="$(sed -n 's/^[[:space:]]*I1[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_I2="$(sed -n 's/^[[:space:]]*I2[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_I3="$(sed -n 's/^[[:space:]]*I3[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_I4="$(sed -n 's/^[[:space:]]*I4[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_I5="$(sed -n 's/^[[:space:]]*I5[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_HEADER_PROTECTION_KEY="$(sed -n 's/^[[:space:]]*HeaderProtectionKey[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_CONTENT_PADDING_ADDITION="$(sed -n 's/^[[:space:]]*ContentPaddingAddition[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_REKEY_AFTER_TIME="$(sed -n 's/^[[:space:]]*RekeyAfterTime[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_REKEY_TIMEOUT="$(sed -n 's/^[[:space:]]*RekeyTimeout[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_REJECT_AFTER_TIME="$(sed -n 's/^[[:space:]]*RejectAfterTime[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_KEEPALIVE_TIMEOUT="$(sed -n 's/^[[:space:]]*KeepaliveTimeout[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_MAX_HANDSHAKE_ATTEMPTS="$(sed -n 's/^[[:space:]]*MaxHandshakeAttempts[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_RANDOM_TRAILERS="$(sed -n 's/^[[:space:]]*RandomTrailers[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  AWG_DISABLE_COOKIES="$(sed -n 's/^[[:space:]]*DisableCookies[[:space:]]*=[[:space:]]*//p' "$file" | head -n1)"
  if [ -n "$AWG_JC$AWG_JMIN$AWG_JMAX$AWG_S1$AWG_S2$AWG_H1$AWG_H2$AWG_H3$AWG_H4$AWG_S3$AWG_S4$AWG_I1$AWG_I2$AWG_I3$AWG_I4$AWG_I5$AWG_HEADER_PROTECTION_KEY$AWG_CONTENT_PADDING_ADDITION$AWG_REKEY_AFTER_TIME$AWG_REKEY_TIMEOUT$AWG_REJECT_AFTER_TIME$AWG_KEEPALIVE_TIMEOUT$AWG_MAX_HANDSHAKE_ATTEMPTS$AWG_RANDOM_TRAILERS$AWG_DISABLE_COOKIES" ]; then
    [ -n "$AWG_JC" ] && [ -n "$AWG_JMIN" ] && [ -n "$AWG_JMAX" ] && [ -n "$AWG_S1" ] && [ -n "$AWG_S2" ] && [ -n "$AWG_H1" ] && [ -n "$AWG_H2" ] && [ -n "$AWG_H3" ] && [ -n "$AWG_H4" ] || die 'AWG obfuscation parameters are incomplete; refusing a partial profile'
    TUNNEL_KIND='amneziawg-obfuscated'
  else
    TUNNEL_KIND='wireguard-compatible'
  fi
}

import_provider_config(){
  [ -n "$CONFIG_INPUT" ] || die 'Provider mode requires --config FILE or UOWRT_AWG_CONFIG'
  [ -f "$CONFIG_INPUT" ] || die "Config file not found: $CONFIG_INPUT"
  validate_conf "$CONFIG_INPUT"
  mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"
  cp -p "$CONFIG_INPUT" "$CONF"
  chmod 600 "$CONF"
  rm -f "$IDENTITY"
  log "Imported provider configuration: $TUNNEL_KIND"
}

apply_uci(){
  validate_conf "$CONF"
  if [ "$TUNNEL_KIND" = amneziawg-obfuscated ]; then PEER_TYPE=amneziawg; TUNNEL_PROTO=amneziawg; else PEER_TYPE=wireguard; TUNNEL_PROTO=wireguard; fi
  uci -q delete "network.$IFACE" || true
  # Remove only the peer objects belonging to this interface; do not touch unrelated WireGuard/AWG peers.
  while IFS= read -r section; do
    [ -n "$section" ] || continue
    uci -q delete "network.$section" || true
  done <<EOF
$(uci show network 2>/dev/null | sed -n "s/^network\.\([^.=]*\)=amneziawg_${IFACE}$/\1/p")
$(uci show network 2>/dev/null | sed -n "s/^network\.\([^.=]*\)=wireguard_${IFACE}$/\1/p")
EOF
  uci set "network.$IFACE=interface"
  if [ "$TUNNEL_KIND" = amneziawg-obfuscated ]; then
    TUNNEL_PROTO=amneziawg
    PEER_TYPE=amneziawg
  else
    TUNNEL_PROTO=wireguard
    PEER_TYPE=wireguard
  fi
  uci set "network.$IFACE.proto=$TUNNEL_PROTO"
  uci set "network.$IFACE.private_key=$PRIVATE_KEY"
  [ -n "${LISTEN_PORT:-}" ] && uci set "network.$IFACE.listen_port=$LISTEN_PORT" || true
  [ -n "${MTU:-}" ] && uci set "network.$IFACE.mtu=$MTU" || true
  for address in $ADDRESS_LINES; do uci add_list "network.$IFACE.addresses=$address"; done
  uci set "network.$IFACE.peerdns=0"
  for dns in $DNS_LINES; do [ -n "$dns" ] && uci add_list "network.$IFACE.dns=$dns" || true; done
  peer="$(uci add network "${PEER_TYPE}_${IFACE}")"
  uci set "network.$peer.description=Universal OpenWrt AWG/WARP peer"
  uci set "network.$peer.public_key=$PEER_KEY"
  # Preserve PSK if supplied by the provider config.
  PSK="$(sed -n 's/^[[:space:]]*PresharedKey[[:space:]]*=[[:space:]]*//p' "$CONF" | head -n1)"
  [ -n "$PSK" ] && uci set "network.$peer.preshared_key=$PSK" || true
  for allowed in $ALLOWED; do uci add_list "network.$peer.allowed_ips=$allowed"; done
  case "$ENDPOINT" in
    \[*\]:*) HOST="${ENDPOINT#\[}"; HOST="${HOST%%\]:*}"; PORT="${ENDPOINT##*]:}";;
    *:*) HOST="${ENDPOINT%:*}"; PORT="${ENDPOINT##*:}";;
    *) HOST="$ENDPOINT"; PORT='';;
  esac
  uci set "network.$peer.endpoint_host=$HOST"
  [ -n "$PORT" ] && uci set "network.$peer.endpoint_port=$PORT" || true
  KEEPALIVE="$(sed -n 's/^[[:space:]]*PersistentKeepalive[[:space:]]*=[[:space:]]*//p' "$CONF" | head -n1)"
  [ -n "$KEEPALIVE" ] && uci set "network.$peer.persistent_keepalive=$KEEPALIVE" || true
  uci set "network.$peer.route_allowed_ips=0"
  [ -n "$AWG_JC" ] && uci set "network.$IFACE.awg_jc=$AWG_JC" || true
  [ -n "$AWG_JMIN" ] && uci set "network.$IFACE.awg_jmin=$AWG_JMIN" || true
  [ -n "$AWG_JMAX" ] && uci set "network.$IFACE.awg_jmax=$AWG_JMAX" || true
  [ -n "$AWG_S1" ] && uci set "network.$IFACE.awg_s1=$AWG_S1" || true
  [ -n "$AWG_S2" ] && uci set "network.$IFACE.awg_s2=$AWG_S2" || true
  [ -n "$AWG_H1" ] && uci set "network.$IFACE.awg_h1=$AWG_H1" || true
  [ -n "$AWG_H2" ] && uci set "network.$IFACE.awg_h2=$AWG_H2" || true
  [ -n "$AWG_H3" ] && uci set "network.$IFACE.awg_h3=$AWG_H3" || true
  [ -n "$AWG_H4" ] && uci set "network.$IFACE.awg_h4=$AWG_H4" || true
  [ -n "$AWG_S3" ] && uci set "network.$IFACE.awg_s3=$AWG_S3" || true
  [ -n "$AWG_S4" ] && uci set "network.$IFACE.awg_s4=$AWG_S4" || true
  [ -n "$AWG_I1" ] && uci set "network.$IFACE.awg_i1=$AWG_I1" || true
  [ -n "$AWG_I2" ] && uci set "network.$IFACE.awg_i2=$AWG_I2" || true
  [ -n "$AWG_I3" ] && uci set "network.$IFACE.awg_i3=$AWG_I3" || true
  [ -n "$AWG_I4" ] && uci set "network.$IFACE.awg_i4=$AWG_I4" || true
  [ -n "$AWG_I5" ] && uci set "network.$IFACE.awg_i5=$AWG_I5" || true
  [ -n "$AWG_HEADER_PROTECTION_KEY" ] && uci set "network.$IFACE.awg_header_protection_key=$AWG_HEADER_PROTECTION_KEY" || true
  [ -n "$AWG_CONTENT_PADDING_ADDITION" ] && uci set "network.$IFACE.awg_content_padding_addition=$AWG_CONTENT_PADDING_ADDITION" || true
  [ -n "$AWG_REKEY_AFTER_TIME" ] && uci set "network.$IFACE.awg_rekey_after_time=$AWG_REKEY_AFTER_TIME" || true
  [ -n "$AWG_REKEY_TIMEOUT" ] && uci set "network.$IFACE.awg_rekey_timeout=$AWG_REKEY_TIMEOUT" || true
  [ -n "$AWG_REJECT_AFTER_TIME" ] && uci set "network.$IFACE.awg_reject_after_time=$AWG_REJECT_AFTER_TIME" || true
  [ -n "$AWG_KEEPALIVE_TIMEOUT" ] && uci set "network.$IFACE.awg_keepalive_timeout=$AWG_KEEPALIVE_TIMEOUT" || true
  [ -n "$AWG_MAX_HANDSHAKE_ATTEMPTS" ] && uci set "network.$IFACE.awg_max_handshake_attempts=$AWG_MAX_HANDSHAKE_ATTEMPTS" || true
  [ -n "$AWG_RANDOM_TRAILERS" ] && uci set "network.$IFACE.awg_random_trailers=$AWG_RANDOM_TRAILERS" || true
  [ -n "$AWG_DISABLE_COOKIES" ] && uci set "network.$IFACE.awg_disable_cookies=$AWG_DISABLE_COOKIES" || true
  uci commit network
  /etc/init.d/network reload >/dev/null 2>&1 || true
  log "UCI interface $IFACE prepared: tunnel=$TUNNEL_KIND route_allowed_ips=0"
}

firewall_setup(){
  ZONE="uowrt_awg"
  # Idempotent client-VPN zone: LAN may forward into it; the tunnel may NAT out.
  if ! uci -q get "firewall.$ZONE.name" >/dev/null 2>&1; then
    uci set "firewall.$ZONE=zone"
    uci set "firewall.$ZONE.name=$ZONE"
    uci add_list "firewall.$ZONE.network=$IFACE"
    uci set "firewall.$ZONE.input=REJECT"
    uci set "firewall.$ZONE.output=ACCEPT"
    uci set "firewall.$ZONE.forward=REJECT"
    uci set "firewall.$ZONE.masq=1"
    uci set "firewall.$ZONE.masq6=1"
    uci set "firewall.$ZONE.mtu_fix=1"
  else
    uci del_list "firewall.$ZONE.network=$IFACE" 2>/dev/null || true
    uci add_list "firewall.$ZONE.network=$IFACE"
  fi
  FORWARD="${LAN_ZONE}_to_uowrt_awg"
  if ! uci -q get "firewall.$FORWARD" >/dev/null 2>&1; then
    uci set "firewall.$FORWARD=forwarding"
    uci set "firewall.$FORWARD.src=$LAN_ZONE"
    uci set "firewall.$FORWARD.dest=$ZONE"
  fi
  uci commit firewall
  /etc/init.d/firewall reload >/dev/null 2>&1 || true
  log "Firewall zone $ZONE prepared for $IFACE"
}

openwrt_release
if [ "$MODE" != provider ] || [ -z "$CONFIG_INPUT" ]; then ensure_http_client; fi
install_awg_packages
case "$MODE" in
  provider) import_provider_config;;
  warp) register_warp;;
  auto) if [ -n "$CONFIG_INPUT" ]; then import_provider_config; else register_warp; fi;;
esac
apply_uci
firewall_setup
log "AWG/WARP setup complete: interface=$IFACE tunnel=$TUNNEL_KIND config=$CONF"
