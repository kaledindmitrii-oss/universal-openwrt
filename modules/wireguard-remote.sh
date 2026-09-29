#!/bin/sh
# Universal OpenWrt — isolated Remote WireGuard module
# Purpose: isolated WireGuard remote access OR full IPv4 Internet VPN for
# explicitly selected devices. It is never an AWG/WARP/strategy backend.
# Remote WireGuard and WireGuard VPN share the same isolated wg0 interface but
# are separated by per-device AllowedIPs and the VPN forwarding/NAT policy.
# No device is switched to VPN mode implicitly.
# This module must not be registered in strategy-engine, AI access, AWG/WARP,
# Telegram, DNS, or any adaptive/fallback logic.

set -u

WG_REMOTE_IFACE="${UOWRT_REMOTE_WG_IFACE:-wg0}"
WG_REMOTE_PORT="${UOWRT_REMOTE_WG_PORT:-51820}"
WG_REMOTE_ADDR="${UOWRT_REMOTE_WG_ADDR:-10.66.66.1/24}"
WG_REMOTE_ZONE="${UOWRT_REMOTE_WG_ZONE:-uowrt_remote_wg}"
WG_REMOTE_STATE="/etc/universal-openwrt/wireguard-remote"
WG_REMOTE_DEVICES="$WG_REMOTE_STATE/devices"
WG_REMOTE_SERVER_KEY="$WG_REMOTE_STATE/server.key"
WG_REMOTE_SERVER_PUB="$WG_REMOTE_STATE/server.pub"
WG_REMOTE_ENDPOINT_FILE="$WG_REMOTE_STATE/endpoint"
WG_REMOTE_DEFAULT_MODE="${UOWRT_REMOTE_WG_DEFAULT_MODE:-remote}"
WG_REMOTE_WAN_ZONE="${UOWRT_REMOTE_WG_WAN_ZONE:-wan}"

log(){ printf '[remote-wg] %s\n' "$*"; }
die(){ log "ERROR: $*" >&2; return 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
uci_get(){ uci -q get "$1" 2>/dev/null || true; }

usage(){
  cat <<USAGE
Usage: wireguard-remote.sh <status|setup|check|list|add|show|config|qr|revoke|regenerate|remove>

Modes:
  Remote WireGuard — access to the router/tunnel network only; no Internet NAT.
  WireGuard VPN    — full IPv4 Internet through this router for selected devices.
                    Requires a publicly reachable WireGuard endpoint (normally
                    a real public/white IPv4, or a supported DDNS/public route).
                    CGNAT is not considered guaranteed.

Neither mode participates in Universal OpenWrt strategy, AWG/WARP, Telegram,
AI, DNS or adaptive/fallback routing.

Device management:
  list
  add <name>
  show <name>
  config <name>
  qr <name>
  revoke <name> confirm
  regenerate <name> confirm
  remove <name> confirm

Endpoint is discovered automatically from saved remote-access settings, DDNS or the current public IPv4.
USAGE
}

validate_runtime(){
  have uci || return 1
  have ip || return 1
  have wg || return 1
  have fw4 || return 1
  [ -d /etc/config ] || return 1
}

ensure_state(){
  mkdir -p "$WG_REMOTE_DEVICES" 2>/dev/null || return 1
  chmod 700 "$WG_REMOTE_STATE" "$WG_REMOTE_DEVICES" 2>/dev/null || true
}

valid_name(){ printf '%s' "$1" | grep -Eq '^[A-Za-z0-9._-]{1,48}$'; }
valid_endpoint(){ printf '%s' "$1" | grep -Eq '^[A-Za-z0-9._:\[\]-]+:[0-9]{1,5}$'; }
valid_mode(){ [ "$1" = remote ] || [ "$1" = vpn ]; }

remote_endpoint_resolve(){
  local ep host public ddns
  ep="${UOWRT_REMOTE_WG_ENDPOINT:-}"
  if [ -z "$ep" ] && [ -s "$WG_REMOTE_ENDPOINT_FILE" ]; then ep="$(cat "$WG_REMOTE_ENDPOINT_FILE" 2>/dev/null || true)"; fi
  if [ -z "$ep" ] && [ -f /etc/config/ddns ] && command -v uci >/dev/null 2>&1; then
    ddns="$(uci -q show ddns 2>/dev/null | sed -n 's/^ddns\.[^.]*\.lookup_host=//p' | sed 's/^\x27//;s/\x27$//' | head -n1)"
    [ -n "$ddns" ] && ep="$ddns:$WG_REMOTE_PORT"
  fi
  if [ -z "$ep" ] && command -v curl >/dev/null 2>&1; then
    public="$(curl -4fsSL --connect-timeout 3 --max-time 6 https://api.ipify.org 2>/dev/null || true)"
    printf '%s' "$public" | grep -Eq '^[0-9]+(\.[0-9]+){3}$' && ep="$public:$WG_REMOTE_PORT"
  fi
  if [ -z "$ep" ] && command -v wget >/dev/null 2>&1; then
    public="$(wget -q -T 5 -O - https://api.ipify.org 2>/dev/null || true)"
    printf '%s' "$public" | grep -Eq '^[0-9]+(\.[0-9]+){3}$' && ep="$public:$WG_REMOTE_PORT"
  fi
  valid_endpoint "$ep" || return 1
  printf '%s\n' "$ep" >"$WG_REMOTE_ENDPOINT_FILE" 2>/dev/null || true
  chmod 600 "$WG_REMOTE_ENDPOINT_FILE" 2>/dev/null || true
  printf '%s\n' "$ep"
}
file_name(){ printf '%s' "$1" | tr -cd 'A-Za-z0-9._-' | cut -c1-48; }


remote_snapshot(){
  ensure_state || return 1
  cp -p /etc/config/network "$WG_REMOTE_STATE/.network.before" 2>/dev/null || true
  cp -p /etc/config/firewall "$WG_REMOTE_STATE/.firewall.before" 2>/dev/null || true
}
remote_restore_snapshot(){
  [ -f "$WG_REMOTE_STATE/.network.before" ] && cp -p "$WG_REMOTE_STATE/.network.before" /etc/config/network 2>/dev/null || true
  [ -f "$WG_REMOTE_STATE/.firewall.before" ] && cp -p "$WG_REMOTE_STATE/.firewall.before" /etc/config/firewall 2>/dev/null || true
  uci revert network 2>/dev/null || true
  uci revert firewall 2>/dev/null || true
  /etc/init.d/network reload >/dev/null 2>&1 || true
  /etc/init.d/firewall reload >/dev/null 2>&1 || true
  rm -f "$WG_REMOTE_STATE/.network.before" "$WG_REMOTE_STATE/.firewall.before" 2>/dev/null || true
}
remote_snapshot_cleanup(){ rm -f "$WG_REMOTE_STATE/.network.before" "$WG_REMOTE_STATE/.firewall.before" 2>/dev/null || true; }

server_key_init(){
  local existing
  ensure_state || return 1
  if [ ! -s "$WG_REMOTE_SERVER_KEY" ]; then
    existing="$(uci_get network.$WG_REMOTE_IFACE.private_key)"
    if [ -n "$existing" ]; then
      printf '%s\n' "$existing" >"$WG_REMOTE_SERVER_KEY"
      chmod 600 "$WG_REMOTE_SERVER_KEY"
    else
      have wg || return 1
      wg genkey >"$WG_REMOTE_SERVER_KEY" || return 1
      chmod 600 "$WG_REMOTE_SERVER_KEY"
    fi
  fi
  if [ ! -s "$WG_REMOTE_SERVER_PUB" ]; then
    wg pubkey <"$WG_REMOTE_SERVER_KEY" >"$WG_REMOTE_SERVER_PUB" || return 1
    chmod 600 "$WG_REMOTE_SERVER_PUB"
  fi
  printf '%s\n' "$(cat "$WG_REMOTE_SERVER_KEY")"
}

setup_network(){
  local section peer key
  key="$(server_key_init)" || return 1
  section="$(uci -q show network | sed -n "s/^network\.\([^.=]*\)=interface$/\1/p" | grep -Fx "$WG_REMOTE_IFACE" | head -n1)"
  if [ -n "$section" ]; then
    [ "$(uci_get network."$section".proto)" = wireguard ] || return 1
  else
    uci set "network.$WG_REMOTE_IFACE=interface"
    uci set "network.$WG_REMOTE_IFACE.proto=wireguard"
  fi
  # Never take over an existing WireGuard interface used by another part of
  # the router. An existing wg0 is accepted only when it already matches the
  # known remote-access identity (address + port). Otherwise fail closed.
  [ "$(uci_get network.$WG_REMOTE_IFACE.proto)" = wireguard ] || return 1
  local existing_port existing_addr existing_key
  existing_port="$(uci_get network.$WG_REMOTE_IFACE.listen_port)"
  existing_addr="$(uci_get network.$WG_REMOTE_IFACE.addresses)"
  existing_key="$(uci_get network.$WG_REMOTE_IFACE.private_key)"
  if [ -n "$existing_port" ] && [ "$existing_port" != "$WG_REMOTE_PORT" ]; then return 1; fi
  if [ -n "$existing_addr" ] && [ "$existing_addr" != "$WG_REMOTE_ADDR" ]; then return 1; fi
  [ -n "$existing_port" ] || uci set "network.$WG_REMOTE_IFACE.listen_port=$WG_REMOTE_PORT"
  [ -n "$existing_addr" ] || uci set "network.$WG_REMOTE_IFACE.addresses=$WG_REMOTE_ADDR"
  [ -n "$existing_key" ] || uci set "network.$WG_REMOTE_IFACE.private_key=$key"
  # Do not change auto/start semantics of an existing interface.
  uci commit network
  /etc/init.d/network reload >/dev/null 2>&1 || true
  # Existing peers are preserved. Device manager only owns peers recorded in
  # its own state directory.
  peer=""
  : "$peer"
  remote_endpoint_resolve >/dev/null 2>&1 || true
}

wan_ipv4(){
  local ip=""
  if have ubus && have jsonfilter; then
    ip="$(ubus call network.interface.wan status 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null || true)"
  fi
  if [ -z "$ip" ] && have ip; then
    ip="$(ip -4 addr show scope global 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
  fi
  printf '%s\n' "$ip"
}
wan_is_private(){
  # Return 0 for non-public/special IPv4 ranges. RFC1918 + RFC6598 are the
  # important cases for CGNAT, with loopback/link-local/benchmark/multicast
  # and 0/8 rejected as well. This avoids false "white IP" positives.
  printf '%s\n' "$1" | awk -F. '
    NF!=4 {exit 0}
    {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i>255) exit 0}
    $1==0 || $1==10 || $1==127 || $1>=224 {exit 0}
    $1==169 && $2==254 {exit 0}
    $1==172 && $2>=16 && $2<=31 {exit 0}
    $1==192 && $2==168 {exit 0}
    $1==100 && $2>=64 && $2<=127 {exit 0}
    $1==192 && $2==0 && ($3==0 || $3==2) {exit 0}
    $1==198 && ($2==18 || $2==19) {exit 0}
    {exit 1}
  '
}
public_ipv4(){
  local public=""
  if have curl; then public="$(curl -4fsSL --connect-timeout 3 --max-time 6 https://api.ipify.org 2>/dev/null || true)"; fi
  if [ -z "$public" ] && have wget; then public="$(wget -q -T 5 -O - https://api.ipify.org 2>/dev/null || true)"; fi
  printf '%s\n' "$public"
}
white_ip_check(){
  local wan public verdict reason
  wan="$(wan_ipv4)"; public="$(public_ipv4)"
  if [ -z "$wan" ]; then verdict="unknown"; reason="WAN IPv4 не определён";
  elif wan_is_private "$wan"; then verdict="no"; reason="WAN IPv4 относится к private/CGNAT диапазону";
  elif ! printf '%s' "$wan" | grep -Eq '^[0-9]+(\.[0-9]+){3}$'; then verdict="unknown"; reason="WAN IPv4 имеет неизвестный формат";
  elif [ -z "$public" ]; then verdict="unknown"; reason="Внешний IPv4 не удалось проверить";
  elif [ "$wan" = "$public" ]; then verdict="yes"; reason="WAN IPv4 совпадает с внешним IPv4";
  else verdict="no"; reason="WAN IPv4 не совпадает с внешним IPv4 — вероятен NAT/CGNAT"; fi
  printf 'wan_ipv4=%s\npublic_ipv4=%s\nwhite_ip=%s\nwhite_ip_reason=%s\n' "${wan:-unknown}" "${public:-unknown}" "$verdict" "$reason"
}
count_vpn_devices(){
  local f n c=0
  for f in "$WG_REMOTE_DEVICES"/*.mode; do
    [ -f "$f" ] || continue
    n="$(cat "$f" 2>/dev/null || true)"
    [ "$n" = vpn ] && c=$((c+1))
  done
  printf '%s\n' "$c"
}
sync_vpn_firewall(){
  local z forward found=0 n mode
  z="$(uci -q show firewall | sed -n "s/^firewall\.\([^.=]*\)=zone$/\1/p" | while read -r s; do [ "$(uci_get firewall.$s.name)" = "$WG_REMOTE_ZONE" ] && printf '%s\n' "$s" && break; done)"
  [ -n "$z" ] || return 1
  if [ "$(count_vpn_devices)" -gt 0 ]; then
    # This zone is owned by Remote WireGuard. NAT is enabled only while at least
    # one explicitly selected device is in WireGuard VPN mode.
    uci set "firewall.$z.masq=1"
    uci set "firewall.$z.mtu_fix=1"
    forward="$(uci -q show firewall | sed -n 's/^firewall\.\([^.=]*\)=forwarding$/\1/p' | while read -r s; do [ "$(uci_get firewall.$s.src)" = "$WG_REMOTE_ZONE" ] && [ "$(uci_get firewall.$s.dest)" = "$WG_REMOTE_WAN_ZONE" ] && printf '%s\n' "$s" && break; done)"
    if [ -z "$forward" ]; then
      forward="$(uci add firewall forwarding)" || return 1
      uci set "firewall.$forward.src=$WG_REMOTE_ZONE"
      uci set "firewall.$forward.dest=$WG_REMOTE_WAN_ZONE"
      uci set "firewall.$forward.name=uowrt_remote_wg_vpn_forward"
    fi
  else
    uci set "firewall.$z.masq=0"
    uci set "firewall.$z.mtu_fix=0"
    for forward in $(uci -q show firewall | sed -n 's/^firewall\.\([^.=]*\)=forwarding$/\1/p'); do
      [ "$(uci_get firewall.$forward.src)" = "$WG_REMOTE_ZONE" ] || continue
      [ "$(uci_get firewall.$forward.dest)" = "$WG_REMOTE_WAN_ZONE" ] || continue
      uci -q delete "firewall.$forward"
    done
  fi
  uci commit firewall
  /etc/init.d/firewall reload >/dev/null 2>&1 || true
}

setup_firewall(){
  local z
  z="$(uci -q show firewall | sed -n "s/^firewall\.\([^.=]*\)=zone$/\1/p" | while read -r s; do [ "$(uci_get firewall.$s.name)" = "$WG_REMOTE_ZONE" ] && printf '%s\n' "$s" && break; done)"
  if [ -z "$z" ]; then
    z="$(uci add firewall zone)" || return 1
    uci set "firewall.$z.name=$WG_REMOTE_ZONE"
    # A newly-created zone is owned by this module.
    uci set "firewall.$z.network=$WG_REMOTE_IFACE"
    uci set "firewall.$z.input=ACCEPT"
    uci set "firewall.$z.output=ACCEPT"
    uci set "firewall.$z.forward=REJECT"
    uci set "firewall.$z.masq=0"
    uci set "firewall.$z.mtu_fix=0"
  else
    # Existing zone may belong to another component. Only verify that it
    # already points at our interface; never rewrite its policy.
    case " $(uci_get firewall.$z.network) " in
      *" $WG_REMOTE_IFACE "*) ;;
      *) return 1;;
    esac
  fi
  uci commit firewall
  /etc/init.d/firewall reload >/dev/null 2>&1 || true
  sync_vpn_firewall || return 1
}

peer_section_for(){
  local name="$1" f pub
  f="$WG_REMOTE_DEVICES/$(file_name "$name").pub"
  [ -s "$f" ] || return 1
  pub="$(cat "$f")"
  uci -q show network | sed -n "s/^network\.\([^.=]*\)=wireguard_${WG_REMOTE_IFACE}$/\1/p" | while read -r p; do
    [ "$(uci_get network.$p.public_key)" = "$pub" ] && { printf '%s\n' "$p"; break; }
  done
}

setup(){
  validate_runtime || die 'requires uci, ip, wg, fw4 on OpenWrt'
  ensure_state || die 'cannot create private device state directory'
  remote_snapshot || die 'cannot create Remote WireGuard safety snapshot'
  if ! setup_network || ! setup_firewall || ! check; then
    log 'Remote WireGuard setup failed; restoring pre-change network/firewall state'
    remote_restore_snapshot
    return 1
  fi
  remote_snapshot_cleanup
  return 0
}

check(){
  validate_runtime || { log 'runtime prerequisites: FAIL'; return 1; }
  [ "$(uci_get network.$WG_REMOTE_IFACE.proto)" = wireguard ] || { log 'network interface: FAIL'; return 1; }
  [ "$(uci_get network.$WG_REMOTE_IFACE.listen_port)" = "$WG_REMOTE_PORT" ] || { log 'listen port: FAIL'; return 1; }
  [ "$(uci_get network.$WG_REMOTE_IFACE.addresses)" = "$WG_REMOTE_ADDR" ] || { log 'address: FAIL'; return 1; }
  [ -s "$WG_REMOTE_SERVER_KEY" ] || { log 'server key: FAIL'; return 1; }
  [ -s "$WG_REMOTE_SERVER_PUB" ] || { log 'server public key: FAIL'; return 1; }
  log 'remote WireGuard isolation: PASS'
  log "interface=$WG_REMOTE_IFACE address=$WG_REMOTE_ADDR port=$WG_REMOTE_PORT zone=$WG_REMOTE_ZONE"
  log 'default-route ownership: NONE'
  log 'Internet NAT ownership: NONE'
  log 'strategy/AWG/WARP ownership: NONE'
}

status(){
  printf 'Remote WireGuard\n'
  printf 'interface=%s\n' "$WG_REMOTE_IFACE"
  printf 'proto=%s\n' "$(uci_get network.$WG_REMOTE_IFACE.proto)"
  printf 'address=%s\n' "$(uci_get network.$WG_REMOTE_IFACE.addresses)"
  printf 'listen_port=%s\n' "$(uci_get network.$WG_REMOTE_IFACE.listen_port)"
  printf 'private_key=%s\n' "$( [ -n "$(uci_get network.$WG_REMOTE_IFACE.private_key)" ] && echo configured || echo missing )"
  printf 'server_public_key=%s\n' "$(cat "$WG_REMOTE_SERVER_PUB" 2>/dev/null || echo missing)"
  printf 'zone=%s\n' "$WG_REMOTE_ZONE"
  printf 'route_allowed_ips=never-managed\n'
  printf 'vpn_devices=%s\n' "$(count_vpn_devices)"
  printf 'masquerade=%s\n' "$( [ "$(count_vpn_devices)" -gt 0 ] && echo enabled || echo disabled )"
  printf 'strategy_integration=none\n'
  if have wg; then wg show "$WG_REMOTE_IFACE" 2>/dev/null || true; fi
  list
}

device_runtime_status(){
  local name="$1" base pub revoked now hs rx tx endpoint
  base="$WG_REMOTE_DEVICES/$(file_name "$name")"
  pub="$(cat "$base.pub" 2>/dev/null || true)"
  [ -n "$pub" ] || { printf 'state=missing'; return 0; }
  [ -f "$base.revoked" ] && { printf 'state=revoked'; return 0; }
  if ! have wg || ! wg show "$WG_REMOTE_IFACE" >/dev/null 2>&1; then
    printf 'state=offline'
    return 0
  fi
  hs="$(wg show "$WG_REMOTE_IFACE" latest-handshakes 2>/dev/null | awk -v k="$pub" '$1==k{print $2;exit}')"
  rx="$(wg show "$WG_REMOTE_IFACE" transfer 2>/dev/null | awk -v k="$pub" '$1==k{print $2;exit}')"
  tx="$(wg show "$WG_REMOTE_IFACE" transfer 2>/dev/null | awk -v k="$pub" '$1==k{print $3;exit}')"
  endpoint="$(wg show "$WG_REMOTE_IFACE" endpoints 2>/dev/null | awk -v k="$pub" '$1==k{print substr($0,index($0,$2));exit}')"
  now="$(date +%s 2>/dev/null || echo 0)"
  if [ -n "$hs" ] && [ "$hs" != 0 ] && [ "$now" -ge "$hs" ] 2>/dev/null && [ $((now-hs)) -le 180 ] 2>/dev/null; then
    printf 'state=online'
  elif [ -n "$hs" ] && [ "$hs" != 0 ]; then
    printf 'state=inactive'
  else
    printf 'state=never-connected'
  fi
  printf '\thandshake=%s\trx=%s\ttx=%s\tendpoint=%s' "${hs:-0}" "${rx:-0}" "${tx:-0}" "${endpoint:-}"
}

list(){
  local f n ep ipf st mode
  printf 'devices:\n'
  for f in "$WG_REMOTE_DEVICES"/*.name; do
    [ -f "$f" ] || continue
    n="$(cat "$f")"
    ep="$(cat "${f%.name}.endpoint" 2>/dev/null || echo '')"
    ipf="$(cat "${f%.name}.address" 2>/dev/null || echo '')"
    st="$(device_runtime_status "$n")"
    mode="$(cat "${f%.name}.mode" 2>/dev/null || echo remote)"
    printf '%s\t%s\t%s\tmode=%s\t%s\n' "$n" "$ipf" "$ep" "$mode" "$st"
  done
}

create_device(){
  local name="$1" mode="${2:-$WG_REMOTE_DEFAULT_MODE}" endpoint dns base priv pub ipaddr serverpub section conf i candidate snapshot=0
  valid_mode "$mode" || die "invalid mode: $mode (use remote or vpn)"
  valid_name "$name" || die 'invalid device name'
  endpoint="$(remote_endpoint_resolve 2>/dev/null || true)"
  [ -n "$endpoint" ] || die 'cannot determine Remote WireGuard endpoint; configure UOWRT_REMOTE_WG_ENDPOINT or DDNS/public IPv4 once'
  dns="${UOWRT_REMOTE_WG_CLIENT_DNS:-}"
  ensure_state || die 'cannot create device state'
  base="$WG_REMOTE_DEVICES/$(file_name "$name")"
  [ ! -e "$base.name" ] || die 'device already exists'
  server_key_init >/dev/null || die 'server key initialization failed'
  section="$(uci -q show network | sed -n "s/^network\.\([^.=]*\)=wireguard_${WG_REMOTE_IFACE}$/\1/p" | head -n1)"
  if [ -z "$section" ]; then
    remote_snapshot || die 'cannot create Remote WireGuard safety snapshot'
    snapshot=1
    if ! setup_network || ! setup_firewall; then
      remote_restore_snapshot
      die 'automatic Remote WireGuard setup failed; previous network/firewall state restored'
    fi
    remote_snapshot_cleanup
    snapshot=0
    section="$(uci -q show network | sed -n "s/^network\.\([^.=]*\)=wireguard_${WG_REMOTE_IFACE}$/\1/p" | head -n1)"
  fi
  [ -n "$section" ] || die 'remote WireGuard interface is not configured'
  priv="$(wg genkey)" || die 'cannot generate device private key'
  pub="$(printf '%s' "$priv" | wg pubkey)" || die 'cannot generate device public key'
  ipaddr=""
  i=2
  while [ "$i" -lt 255 ]; do
    candidate="10.66.66.$i/32"
    if ! grep -Rqs "^$candidate$" "$WG_REMOTE_DEVICES"/*.address 2>/dev/null; then ipaddr="$candidate"; break; fi
    i=$((i + 1))
  done
  [ -n "$ipaddr" ] || die 'no free remote WireGuard address'
  remote_snapshot || die 'cannot create device-change safety snapshot'
  snapshot=1
  section="$(uci add network "wireguard_${WG_REMOTE_IFACE}")" || { remote_restore_snapshot; die 'cannot create peer'; }
  uci set "network.$section.public_key=$pub"
  uci set "network.$section.allowed_ips=$ipaddr"
  uci set "network.$section.route_allowed_ips=0"
  uci set "network.$section.persistent_keepalive=25"
  if ! uci commit network || ! /etc/init.d/network reload >/dev/null 2>&1; then
    remote_restore_snapshot
    die 'failed to apply peer; previous network state restored'
  fi
  serverpub="$(cat "$WG_REMOTE_SERVER_PUB")"
  printf '%s\n' "$endpoint" >"$WG_REMOTE_ENDPOINT_FILE"
  printf '%s\n' "$name" >"$base.name"
  printf '%s\n' "$endpoint" >"$base.endpoint"
  printf '%s\n' "$ipaddr" >"$base.address"
  printf '%s\n' "$pub" >"$base.pub"
  printf '%s\n' "$mode" >"$base.mode"
  printf '%s\n' "$priv" >"$base.key"
  rm -f "$base.revoked"
  chmod 600 "$base.key" "$base.pub" "$base.name" "$base.endpoint" "$base.address" "$base.mode"
  conf="$base.conf"
  cat >"$conf" <<CFG
[Interface]
PrivateKey = $priv
Address = $ipaddr
$( [ -n "$dns" ] && printf "DNS = %s\n" "$dns" )

[Peer]
PublicKey = $serverpub
AllowedIPs = $( [ "$mode" = vpn ] && printf "0.0.0.0/0" || printf "10.66.66.0/24" ) # Remote WireGuard: 10.66.66.0/24; WireGuard VPN: 0.0.0.0/0
# Contract: AllowedIPs = 10.66.66.0/24 in Remote WireGuard mode.
Endpoint = $endpoint
PersistentKeepalive = 25
CFG
  chmod 600 "$conf"
  remote_snapshot_cleanup
  sync_vpn_firewall || { log "VPN firewall synchronization failed"; return 1; }
  snapshot=0
  printf 'DEVICE=%s\nADDRESS=%s\nENDPOINT=%s\nPUBLIC_KEY=%s\nCONFIG_FILE=%s\n' "$name" "$ipaddr" "$endpoint" "$pub" "$conf"
  cat "$conf"
  if have qrencode; then
    printf '\nQR_SVG_BEGIN\n'
    qrencode -t SVG -o - <"$conf" 2>/dev/null || true
    printf '\nQR_SVG_END\n'
  else
    printf '\nQR_STATUS=qrencode-not-installed\n'
  fi
}

add_device(){ create_device "$1"; }

show_device(){
  local name="$1" base
  valid_name "$name" || die 'invalid device name'
  base="$WG_REMOTE_DEVICES/$(file_name "$name")"
  [ -s "$base.conf" ] || die 'device not found'
  cat "$base.conf"
}

qr_device(){
  local name="$1" base
  valid_name "$name" || die 'invalid device name'
  base="$WG_REMOTE_DEVICES/$(file_name "$name")"
  [ -s "$base.conf" ] || die 'device not found'
  have qrencode || die 'qrencode is not installed; text configuration remains available'
  qrencode -t SVG -o - <"$base.conf"
}

revoke_device(){
  local name="$1" confirm="${2:-}" base p
  valid_name "$name" || die 'invalid device name'
  [ "$confirm" = confirm ] || die 'confirmation required: revoke <name> confirm'
  base="$WG_REMOTE_DEVICES/$(file_name "$name")"
  [ -s "$base.name" ] || die 'device not found'
  p="$(peer_section_for "$name" || true)"
  if [ -n "$p" ]; then
    remote_snapshot || die 'cannot create revoke safety snapshot'
    if ! uci -q delete "network.$p" || ! uci commit network || ! /etc/init.d/network reload >/dev/null 2>&1; then
      remote_restore_snapshot
      die 'revoke failed; previous network state restored'
    fi
    remote_snapshot_cleanup
  fi
  : >"$base.revoked"
  chmod 600 "$base.revoked"
  log "device revoked: $name"
}

regenerate_device(){
  local name="$1" confirm="${2:-}" base p mode
  valid_name "$name" || die 'invalid device name'
  [ "$confirm" = confirm ] || die 'confirmation required: regenerate <name> confirm'
  base="$WG_REMOTE_DEVICES/$(file_name "$name")"
  [ -s "$base.name" ] || die 'device not found'
  p="$(peer_section_for "$name" || true)"
  remote_snapshot || die 'cannot create regenerate safety snapshot'
  if [ -n "$p" ]; then
    uci -q delete "network.$p" || true
    uci commit network || { remote_restore_snapshot; die 'failed to remove old peer'; }
    /etc/init.d/network reload >/dev/null 2>&1 || true
  fi
  mode="$(cat "$base.mode" 2>/dev/null || echo remote)"
  rm -f "$base.name" "$base.endpoint" "$base.address" "$base.pub" "$base.key" "$base.conf" "$base.mode" "$base.revoked"
  remote_snapshot_cleanup
  create_device "$name" "$mode" || { :; return 1; }
}

remove_device(){
  local name="$1" confirm="${2:-}" base p
  valid_name "$name" || die 'invalid device name'
  [ "$confirm" = confirm ] || die 'confirmation required: remove <name> confirm'
  base="$WG_REMOTE_DEVICES/$(file_name "$name")"
  [ -s "$base.name" ] || die 'device not found'
  p="$(peer_section_for "$name")"
  [ -z "$p" ] || uci -q delete "network.$p"
  uci commit network
  /etc/init.d/network reload >/dev/null 2>&1 || true
  rm -f "$base.name" "$base.endpoint" "$base.address" "$base.pub" "$base.key" "$base.conf" "$base.mode"
  sync_vpn_firewall || true
  log "device removed: $name"
}

set_mode(){
  local name="$1" mode="${2:-}" base endpoint addr dns priv serverpub
  valid_name "$name" || die 'invalid device name'
  valid_mode "$mode" || die 'invalid mode: use remote or vpn'
  base="$WG_REMOTE_DEVICES/$(file_name "$name")"
  [ -s "$base.conf" ] || die 'device not found'
  endpoint="$(cat "$base.endpoint")"; addr="$(cat "$base.address")"; dns="${UOWRT_REMOTE_WG_CLIENT_DNS:-}"; priv="$(cat "$base.key")"; serverpub="$(cat "$WG_REMOTE_SERVER_PUB")"
  printf '%s\n' "$mode" >"$base.mode"
  cat >"$base.conf" <<CFG
[Interface]
PrivateKey = $priv
Address = $addr
$( [ -n "$dns" ] && printf "DNS = %s\n" "$dns" )

[Peer]
PublicKey = $serverpub
AllowedIPs = $( [ "$mode" = vpn ] && printf "0.0.0.0/0" || printf "10.66.66.0/24" ) # Remote WireGuard: 10.66.66.0/24; WireGuard VPN: 0.0.0.0/0
# Contract: AllowedIPs = 10.66.66.0/24 in Remote WireGuard mode.
Endpoint = $endpoint
PersistentKeepalive = 25
CFG
  chmod 600 "$base.mode" "$base.conf"
  sync_vpn_firewall || die 'failed to synchronize WireGuard VPN firewall'
  printf 'DEVICE=%s\nMODE=%s\nCONFIG_FILE=%s\n' "$name" "$mode" "$base.conf"
  cat "$base.conf"
}

diagnose(){
  local vpn white
  vpn="$(count_vpn_devices)"
  printf 'mode_remote=Remote WireGuard\n'
  printf 'mode_vpn=WireGuard VPN\n'
  printf 'mode_remote_details=Только доступ к роутеру и сети WireGuard; интернет клиента идёт напрямую через его обычное подключение.\n'
  printf 'mode_vpn_details=Полный IPv4 интернет через этот роутер; клиент использует 0.0.0.0/0, а роутер выполняет forwarding и NAT в WAN.\n'
  printf 'vpn_devices=%s\n' "$vpn"
  white="$(white_ip_check)"; printf '%s\n' "$white"
  if printf '%s\n' "$white" | grep -q '^white_ip=yes$'; then
    printf 'direct_incoming=ready-confidence-high\n'
    printf 'guarantee=Корректная прямая работа входящего WireGuard гарантируется только при реально публичном IPv4 и разрешённом UDP-порту 51820; совпадение IP само по себе не проверяет firewall провайдера.\n'
  elif printf '%s\n' "$white" | grep -q '^white_ip=no$'; then
    printf 'direct_incoming=blocked-or-not-guaranteed\n'
    printf 'guarantee=Прямая работа входящего WireGuard не гарантируется: обнаружен NAT/CGNAT или непубличный WAN IPv4.\n'
  else
    printf 'direct_incoming=unknown\n'
    printf 'guarantee=Не удалось подтвердить публичный IPv4; прямая работа входящего WireGuard не гарантируется.\n'
  fi
  printf 'ipv6_note=WireGuard VPN пока маршрутизирует только IPv4; IPv6 не объявляется через туннель, поэтому IPv6 не следует считать защищённым этим режимом.\n'
}

config_device(){ show_device "$1"; }

case "${1:-}" in
  status) status;;
  diagnose) diagnose;;
  check) check;;
  setup) setup;;
  list) ensure_state && list;;
  add) [ "$#" -ge 2 ] || { usage; exit 2; }; add_device "$2" "${3:-$WG_REMOTE_DEFAULT_MODE}";;
  set-mode) [ "$#" -ge 3 ] || { usage; exit 2; }; set_mode "$2" "$3";;
  show|config) [ "$#" -ge 2 ] || { usage; exit 2; }; show_device "$2";;
  qr) [ "$#" -ge 2 ] || { usage; exit 2; }; qr_device "$2";;
  revoke) [ "$#" -ge 3 ] || { usage; exit 2; }; revoke_device "$2" "$3";;
  regenerate) [ "$#" -ge 3 ] || { usage; exit 2; }; regenerate_device "$2" "$3";;
  remove) [ "$#" -ge 3 ] || { usage; exit 2; }; remove_device "$2" "$3";;
  -h|--help|help) usage;;
  *) usage; exit 2;;
esac
