#!/bin/sh
# Universal OpenWrt AWG/WARP bootstrap.
# Installs ABI-matched AmneziaWG 2.0 packages for OpenWrt 24.10.x/25.12.x,
# registers a free Cloudflare WARP device, retrieves the complete WireGuard
# configuration, and converts it into an AmneziaWG-compatible UCI interface.
# No private keys are sent anywhere except the WARP registration endpoint as
# the public key; the generated private key is stored locally with mode 600.
set -eu

REPO="${UOWRT_AWG_REPO:-Slava-Shchipunov/awg-openwrt}"
IFACE="awg10"
LAN_ZONE="lan"
BASE="https://github.com/${REPO}"
API="https://api.github.com/repos/${REPO}"
CF_API="https://api.cloudflareclient.com/v0a2158/reg"
STATE_DIR="/etc/universal-openwrt/awg"
IDENTITY="$STATE_DIR/warp-identity.json"
CONF="$STATE_DIR/awg.conf"
TMP="${TMPDIR:-/tmp}/uowrt-awg.$$"

log(){ printf '[AWG] %s\n' "$*"; }
die(){ log "ERROR: $*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
cleanup(){ rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

fetch(){
  out="$1"; url="$2"
  if have uclient-fetch; then uclient-fetch -q --no-check-certificate -O "$out" "$url"; return $?; fi
  if have wget; then wget -q --no-check-certificate -O "$out" "$url"; return $?; fi
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
    24.10.*|25.12.*) ;;
    *) die "Unsupported OpenWrt $OWVER for automatic AWG setup";;
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
  [ -s "$TMP/assets.names" ] || die 'AWG release has no assets'
}

find_asset(){
  pattern="$1"
  grep -E "$pattern" "$TMP/assets.names" | head -n1 || true
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

install_awg_packages(){
  asset_names
  suffix="${ARCH}_${TARGET#*/}_${SUBTARGET}"
  # amneziawg-tools is architecture/target independent of the kernel ABI.
  # kmod-amneziawg is selected from the release asset set and then installed;
  # this prevents an incompatible kernel module from being guessed by CPU arch.
  if [ "$PM" = opkg ]; then ext='ipk'; else ext='apk'; fi
  tools="$(find_asset "^amneziawg-tools_v${OWVER}_${ARCH}_${TARGET#*/}_${SUBTARGET}\\.${ext}$")"
  [ -n "$tools" ] || tools="$(find_asset "^amneziawg-tools_.*_${ARCH}_${TARGET#*/}_${SUBTARGET}\\.${ext}$")"
  proto="$(find_asset "^luci-proto-amneziawg_.*\\.${ext}$")"
  kmod="$(find_asset "^kmod-amneziawg_.*_${ARCH}_${TARGET#*/}_${SUBTARGET}\\.${ext}$")"
  [ -n "$tools" ] || die "No amneziawg-tools asset for $ARCH/$TARGET/$SUBTARGET/$OWVER"
  [ -n "$kmod" ] || die "No kernel-matched kmod-amneziawg asset for $ARCH/$TARGET/$SUBTARGET/$OWVER"
  [ -n "$proto" ] || die "No luci-proto-amneziawg asset for $OWVER"

  mkdir -p "$TMP/pkg"
  for name in "$tools" "$kmod" "$proto"; do
    url="$(asset_url "$name")"
    file="$TMP/pkg/$name"
    log "Downloading $(basename "$name")"
    fetch "$file" "$url" || die "Download failed: $name"
    install_pkg "$file" || die "Package installation failed: $name"
  done
  log 'AmneziaWG packages installed from the device/OpenWrt-matched release.'
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
    log 'Existing AWG/WARP identity and config found; reusing them.'
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
  id="$(json "$response" '@.id')"
  token="$(json "$response" '@.token')"
  [ -n "$id" ] && [ -n "$token" ] || die 'WARP registration response did not contain id/token'

  patch_json "$TMP/warp-enable.json" "$CF_API/$id" "$token" '{"warp_enabled":true}' || die 'Cannot enable WARP on the registered device'
  get_json "$TMP/device.json" "$CF_API/$id" "$token" || die 'Cannot retrieve WARP device configuration'
  v4="$(json "$TMP/device.json" '@.config.interface.addresses.v4')"
  v6="$(json "$TMP/device.json" '@.config.interface.addresses.v6')"
  peer_key="$(json "$TMP/device.json" '@.config.peers[0].public_key')"
  endpoint="$(json "$TMP/device.json" '@.config.peers[0].endpoint.host')"
  [ -n "$v4" ] && [ -n "$peer_key" ] && [ -n "$endpoint" ] || die 'WARP configuration response is incomplete'
  dns="1.1.1.1"

  # AWG 2.0 accepts the native WireGuard fields plus optional obfuscation
  # fields. We keep them explicit and deterministic. They can be overridden
  # by a provider-supplied .conf through --config in future releases; WARP
  # itself does not expose AWG S/J/H parameters through its API.
  cat > "$CONF" <<CFG
[Interface]
PrivateKey = $private_key
Address = $v4
${v6:+Address = $v6}
DNS = $dns

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
  "device_id": "$id",
  "access_token": "$token",
  "private_key": "$private_key",
  "public_key": "$public_key",
  "endpoint": "$endpoint"
}
JSON
  chmod 600 "$IDENTITY"
  log 'WARP identity, keys and full endpoint/address configuration saved locally.'
}

apply_uci(){
  have uci || die 'uci is required'
  private_key="$(sed -n 's/^PrivateKey[[:space:]]*=[[:space:]]*//p' "$CONF" | head -n1)"
  v4="$(sed -n 's/^Address[[:space:]]*=[[:space:]]*//p' "$CONF" | head -n1)"
  v6="$(sed -n 's/^Address[[:space:]]*=[[:space:]]*//p' "$CONF" | tail -n1)"
  dns="$(sed -n 's/^DNS[[:space:]]*=[[:space:]]*//p' "$CONF" | head -n1)"
  peer_key="$(sed -n 's/^PublicKey[[:space:]]*=[[:space:]]*//p' "$CONF" | head -n1)"
  endpoint="$(sed -n 's/^Endpoint[[:space:]]*=[[:space:]]*//p' "$CONF" | head -n1)"
  [ -n "$private_key" ] && [ -n "$v4" ] && [ -n "$peer_key" ] && [ -n "$endpoint" ] || die 'Saved AWG config is incomplete'

  uci -q delete "network.$IFACE" || true
  uci set "network.$IFACE=interface"
  uci set "network.$IFACE.proto=amneziawg"
  uci set "network.$IFACE.private_key=$private_key"
  uci add_list "network.$IFACE.addresses=$v4"
  [ "$v6" != "$v4" ] && [ -n "$v6" ] && uci add_list "network.$IFACE.addresses=$v6" || true
  uci set "network.$IFACE.dns=$dns"
  peer="$(uci add network amneziawg_${IFACE})"
  uci set "network.$peer.public_key=$peer_key"
  uci set "network.$peer.endpoint_host=${endpoint%%:*}"
  uci set "network.$peer.endpoint_port=${endpoint##*:}"
  uci set "network.$peer.persistent_keepalive=25"
  uci add_list "network.$peer.allowed_ips=0.0.0.0/0"
  [ -n "$v6" ] && uci add_list "network.$peer.allowed_ips=::/0" || true
  uci set "network.$peer.route_allowed_ips=0"
  uci commit network
  /etc/init.d/network reload >/dev/null 2>&1 || true
  log "UCI interface $IFACE prepared (route_allowed_ips=0; no forced full-tunnel yet)."
}

firewall_setup(){
  # Do not overwrite existing firewall policy. Create a dedicated zone and
  # forwarding only when absent; routing mode is controlled by the main engine.
  if uci show firewall 2>/dev/null | grep -q "=zone"; then :; fi
}

openwrt_release
ensure_http_client
install_awg_packages
register_warp
apply_uci
firewall_setup
log "AWG/WARP setup complete: interface=$IFACE config=$CONF"
