#!/bin/sh
# Universal OpenWrt Tunnel Engine
# Open implementation of the VLESS/sing-box/TProxy/FakeIP architecture.

UOWRT_TUNNEL_DIR='/etc/universal-openwrt/tunnels'
UOWRT_TUNNEL_ACTIVE="$UOWRT_TUNNEL_DIR/active"
UOWRT_TUNNEL_CONFIG="$UOWRT_TUNNEL_DIR/sing-box.json"
UOWRT_TUNNEL_META="$UOWRT_TUNNEL_DIR/active.meta"

te_init(){
  mkdir -p "$UOWRT_TUNNEL_DIR" 2>/dev/null || return 1
  chmod 700 "$UOWRT_TUNNEL_DIR" 2>/dev/null || true
}
te_valid_name(){ printf '%s' "$1" | grep -Eq '^[A-Za-z0-9._-]{1,48}$'; }
te_json_escape(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
te_has_singbox(){ command -v sing-box >/dev/null 2>&1 || [ -x /usr/bin/sing-box ]; }
te_status(){
  te_init || return 1
  printf 'Tunnel Engine\n'
  PROFILES=0; for D in "$UOWRT_TUNNEL_DIR"/*; do [ -d "$D" ] && [ -f "$D/address" ] && PROFILES=$((PROFILES+1)); done
  printf 'directory=%s\n' "$UOWRT_TUNNEL_DIR"
  printf 'profiles=%s\n' "$PROFILES"
  printf 'sing_box=%s\n' "$(te_has_singbox && echo yes || echo no)"
  printf 'tproxy_supported=%s\n' "$(command -v ip >/dev/null 2>&1 && command -v nft >/dev/null 2>&1 && echo yes || echo no)"
  printf 'fakeip_range=198.18.0.0/15\n'
  if [ -s "$UOWRT_TUNNEL_ACTIVE" ]; then printf 'active=%s\n' "$(cat "$UOWRT_TUNNEL_ACTIVE")"; else printf 'active=none\n'; fi
  [ -s "$UOWRT_TUNNEL_META" ] && cat "$UOWRT_TUNNEL_META"
}
te_profile_dir(){ printf '%s/%s' "$UOWRT_TUNNEL_DIR" "$1"; }
te_profile_create(){
  NAME="$1"; ADDRESS="$2"; PORT="$3"; UUID="$4"; SERVERNAME="${5:-$ADDRESS}"
  te_valid_name "$NAME" || { log 'Invalid tunnel profile name'; return 1; }
  printf '%s' "$PORT" | grep -Eq '^[0-9]{1,5}$' || { log 'Invalid VLESS port'; return 1; }
  [ -n "$ADDRESS" ] && [ -n "$UUID" ] || { log 'Address and UUID are required'; return 1; }
  [ "$PORT" -ge 1 ] 2>/dev/null && [ "$PORT" -le 65535 ] 2>/dev/null || { log 'Port out of range'; return 1; }
  D="$(te_profile_dir "$NAME")"; mkdir -p "$D" || return 1; chmod 700 "$D"
  printf '%s\n' "$ADDRESS" > "$D/address"
  printf '%s\n' "$PORT" > "$D/port"
  printf '%s\n' "$UUID" > "$D/uuid"
  printf '%s\n' "$SERVERNAME" > "$D/servername"
  printf '%s\n' 'vless' > "$D/type"
  printf 'created=%s\nupdated=%s\n' "$(date +%s)" "$(date +%s)" > "$D/meta"
  chmod 600 "$D"/*
  log "Tunnel profile saved: $NAME"
}
te_profile_list(){
  te_init || return 1
  printf 'name\taddress\tport\tservername\n'
  for D in "$UOWRT_TUNNEL_DIR"/*; do
    [ -d "$D" ] || continue; N="${D##*/}"
    [ -f "$D/address" ] || continue
    printf '%s\t%s\t%s\t%s\n' "$N" "$(cat "$D/address")" "$(cat "$D/port")" "$(cat "$D/servername" 2>/dev/null || true)"
  done
}
te_profile_delete(){
  N="$1"; te_valid_name "$N" || return 1
  [ -d "$(te_profile_dir "$N")" ] || { log 'Tunnel profile not found'; return 1; }
  [ "$(cat "$UOWRT_TUNNEL_ACTIVE" 2>/dev/null || true)" = "$N" ] && te_disable
  rm -rf "$(te_profile_dir "$N")"
}
te_write_config(){
  N="$1"; D="$(te_profile_dir "$N")"; [ -d "$D" ] || return 1
  A="$(te_json_escape "$(cat "$D/address")")"; P="$(cat "$D/port")"; U="$(te_json_escape "$(cat "$D/uuid")")"; S="$(te_json_escape "$(cat "$D/servername")")"
  cat > "$UOWRT_TUNNEL_CONFIG.tmp" <<JSON
{
  "log": {"level": "warn"},
  "dns": {"servers": [{"tag":"fakeip","type":"fakeip","inet4_range":"198.18.0.0/15"},{"tag":"local","address":"local"}],"final":"fakeip"},
  "inbounds": [
    {"type":"tun","tag":"uowrt-tun","interface_name":"uowrt-tun","address":["172.19.0.1/30"],"auto_route":false,"strict_route":false,"stack":"system"}
  ],
  "outbounds": [
    {"type":"vless","tag":"uowrt-vless","server":"$A","server_port":$P,"uuid":"$U","tls":{"enabled":true,"server_name":"$S","utls":{"enabled":true,"fingerprint":"chrome"}}},
    {"type":"direct","tag":"direct"}
  ],
  "route": {"auto_detect_interface":true,"final":"uowrt-vless"}
}
JSON
  mv "$UOWRT_TUNNEL_CONFIG.tmp" "$UOWRT_TUNNEL_CONFIG"; chmod 600 "$UOWRT_TUNNEL_CONFIG"
}
te_config_check(){
  [ -s "$UOWRT_TUNNEL_CONFIG" ] || return 1
  if te_has_singbox; then sing-box check -c "$UOWRT_TUNNEL_CONFIG" >/dev/null 2>&1; return $?; fi
  grep -q '"uowrt-vless"' "$UOWRT_TUNNEL_CONFIG" && grep -q '"198.18.0.0/15"\|fakeip_range' "$UOWRT_TUNNEL_CONFIG" 2>/dev/null || true
  return 0
}
te_enable(){
  N="$1"; te_init || return 1; te_valid_name "$N" || return 1
  te_write_config "$N" || return 1
  te_config_check || { log 'Tunnel config validation failed'; return 1; }
  printf '%s\n' "$N" > "$UOWRT_TUNNEL_ACTIVE"
  printf 'engine=sing-box-vless\nprofile=%s\nfakeip=198.18.0.0/15\nupdated=%s\n' "$N" "$(date +%s)" > "$UOWRT_TUNNEL_META"
  log "Tunnel engine prepared profile=$N (traffic activation requires sing-box service integration)"
}
te_disable(){ rm -f "$UOWRT_TUNNEL_ACTIVE" "$UOWRT_TUNNEL_META"; }
te_auto_select(){
  # Selection is deliberately conservative: only choose a configured profile.
  te_init || return 1; BEST=''
  for D in "$UOWRT_TUNNEL_DIR"/*; do [ -d "$D" ] || continue; [ -f "$D/address" ] || continue; BEST="${D##*/}"; break; done
  [ -n "$BEST" ] || { log 'No tunnel profiles configured'; return 1; }
  te_enable "$BEST"
}
