#!/bin/sh
# Telegram local SOCKS5 -> WebSocket bridge, compatible with the lightweight
# tg-ws-proxy-go used by StressOzz/Zapret-Manager.
TGGO_BIN=${TGGO_BIN:-/usr/bin/tg-ws-proxy-go}
TGGO_CONF=${TGGO_CONF:-/etc/universal-openwrt/telegram-socks5-go.conf}
TGGO_PID=${TGGO_PID:-/var/run/universal-openwrt-tg-socks5-go.pid}
TGGO_LOG=${TGGO_LOG:-/var/log/universal-openwrt-tg-socks5-go.log}
TGGO_PORT_DEFAULT=1080
TGGO_REPO='d0mhate/-tg-ws-proxy-Manager-go'

tggo_init(){
  mkdir -p "$(dirname "$TGGO_CONF")" "$(dirname "$TGGO_PID")" "$(dirname "$TGGO_LOG")" 2>/dev/null || return 1
  [ -f "$TGGO_CONF" ] || cat >"$TGGO_CONF" <<'EOL'
enabled=0
host=0.0.0.0
port=1080
username=
password=
cf_proxy=1
cf_proxy_first=1
cf_balance=1
pool_size=4
buf_kb=256
dial_timeout=10s
init_timeout=15s
EOL
}

tggo_load(){
  tggo_init || return 1
  enabled=0; host=0.0.0.0; port=1080; username=''; password=''; cf_proxy=1; cf_proxy_first=1; cf_balance=1; pool_size=4; buf_kb=256; dial_timeout=10s; init_timeout=15s
  . "$TGGO_CONF" 2>/dev/null || true
  TGGO_ENABLED="$enabled"; TGGO_HOST="$host"; TGGO_PORT="$port"; TGGO_USER="$username"; TGGO_PASS="$password"; TGGO_CF_PROXY="$cf_proxy"; TGGO_CF_FIRST="$cf_proxy_first"; TGGO_CF_BALANCE="$cf_balance"; TGGO_POOL="$pool_size"; TGGO_BUF="$buf_kb"; TGGO_DIAL="$dial_timeout"; TGGO_INIT="$init_timeout"
}

tggo_arch(){
  A=''
  if command -v apk >/dev/null 2>&1; then A="$(apk --print-arch 2>/dev/null | head -n1)"; fi
  [ -n "$A" ] || A="$(opkg print-architecture 2>/dev/null | awk 'NR>1{print $2}' | tail -n1)"
  [ -n "$A" ] || A="$(uname -m 2>/dev/null)"
  case "$A" in
    aarch64|aarch64_cortex-a53|arm64) echo tg-ws-proxy-openwrt-aarch64;;
    armv7|armv7l|arm_cortex-a7_neon-vfpv4|arm_cortex-a7) echo tg-ws-proxy-openwrt-armv7;;
    mipsel_24kc|mipsel*) echo tg-ws-proxy-openwrt-mipsel_24kc;;
    mips_24kc|mips*) echo tg-ws-proxy-openwrt-mips_24kc;;
    x86_64|x86-64) echo tg-ws-proxy-openwrt-x86_64;;
    *) return 1;;
  esac
}

tggo_process_running(){
  [ -f "$TGGO_PID" ] && kill -0 "$(cat "$TGGO_PID" 2>/dev/null)" 2>/dev/null && return 0
  pidof tg-ws-proxy-go >/dev/null 2>&1
}

tggo_installed(){ [ -x "$TGGO_BIN" ]; }

tggo_lan_ip(){
  DEV="${LAN_DEV:-}"
  [ -n "$DEV" ] || DEV="$(uci -q get network.lan.device 2>/dev/null || true)"
  [ -n "$DEV" ] || DEV="$(uci -q get network.lan.ifname 2>/dev/null || true)"
  [ -n "$DEV" ] || DEV=br-lan
  ip -4 -o addr show dev "$DEV" scope global 2>/dev/null | awk 'NR==1{split($4,a,"/");print a[1]}'
}
tggo_configured(){ tggo_load && tggo_installed && [ -n "$TGGO_HOST" ] && [ -n "$TGGO_PORT" ]; }
tggo_running(){ tggo_load && [ "$TGGO_ENABLED" = 1 ] && tggo_process_running; }

tggo_status(){
  tggo_load || return 1
  INSTALLED=no; tggo_installed && INSTALLED=yes
  PROCESS_RUNNING=no; tggo_process_running && PROCESS_RUNNING=yes
  CONFIGURED=no; [ "$INSTALLED" = yes ] && [ -n "$TGGO_HOST" ] && [ -n "$TGGO_PORT" ] && CONFIGURED=yes
  RUNNING=no; [ "$CONFIGURED" = yes ] && [ "$PROCESS_RUNNING" = yes ] && RUNNING=yes
  LAN_IP="$(tggo_lan_ip 2>/dev/null || true)"
  LINK=''
  [ -n "$LAN_IP" ] && LINK="tg://socks?server=$LAN_IP&port=$TGGO_PORT"
  printf 'enabled=%s\ninstalled=%s\nhost=%s\nport=%s\nlan_ip=%s\nrunning=%s\nprocess_running=%s\nbinary=%s\nconfigured=%s\ncf_proxy=%s\ncf_proxy_first=%s\ncf_balance=%s\ntg_link=%s\nactive=%s\n' \
    "$TGGO_ENABLED" "$INSTALLED" "$TGGO_HOST" "$TGGO_PORT" "${LAN_IP:-}" "$RUNNING" "$PROCESS_RUNNING" "$TGGO_BIN" "$CONFIGURED" "$TGGO_CF_PROXY" "$TGGO_CF_FIRST" "$TGGO_CF_BALANCE" "$LINK" "$([ "$RUNNING" = yes ] && echo yes || echo no)"
}

tggo_stop(){
  if [ -f "$TGGO_PID" ]; then
    PID="$(cat "$TGGO_PID" 2>/dev/null)"; kill "$PID" 2>/dev/null || true; sleep 1; kill -9 "$PID" 2>/dev/null || true; rm -f "$TGGO_PID"
  fi
  pidof tg-ws-proxy-go >/dev/null 2>&1 && kill "$(pidof tg-ws-proxy-go)" 2>/dev/null || true
}

tggo_install(){
  tggo_init || return 1
  ASSET="$(tggo_arch)" || { echo 'Unsupported architecture for Telegram SOCKS5'; return 2; }
  TMP="/tmp/universal-openwrt-tggo.$$"
  API_JSON="/tmp/universal-openwrt-tggo-api.$$"
  EXPECTED_SHA=''
  LATEST_TAG=''
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 10 --max-time 30 https://api.github.com/repos/$TGGO_REPO/releases/latest -o "$API_JSON" 2>/dev/null || true
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 15 -O "$API_JSON" https://api.github.com/repos/$TGGO_REPO/releases/latest 2>/dev/null || true
  fi
  if [ -s "$API_JSON" ]; then
    LATEST_TAG="$(sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' "$API_JSON" | head -n1)"
    EXPECTED_SHA="$(grep -A 8 -F '"name": "'"$ASSET"'"' "$API_JSON" 2>/dev/null | sed -n 's/.*"digest": "sha256:\([0-9a-fA-F]*\)".*/\1/p' | head -n1)"
  fi
  rm -f "$API_JSON"
  [ -n "$LATEST_TAG" ] || LATEST_TAG=latest
  rm -f "$TMP" "$TMP.tmp" 2>/dev/null || true
  URL="https://github.com/$TGGO_REPO/releases/download/$LATEST_TAG/$ASSET"
  [ "$LATEST_TAG" = latest ] && URL="https://github.com/$TGGO_REPO/releases/latest/download/$ASSET"
  echo "Downloading $ASSET from $URL"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 15 --max-time 180 "$URL" -o "$TMP.tmp" || { rm -f "$TMP" "$TMP.tmp"; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -T 20 -O "$TMP.tmp" "$URL" || { rm -f "$TMP" "$TMP.tmp"; return 1; }
  elif command -v uclient-fetch >/dev/null 2>&1; then
    uclient-fetch -T 20 -O "$TMP.tmp" "$URL" || { rm -f "$TMP" "$TMP.tmp"; return 1; }
  else
    echo 'No download utility available'; rm -f "$TMP" "$TMP.tmp"; return 127
  fi
  [ -s "$TMP.tmp" ] || { rm -f "$TMP" "$TMP.tmp"; return 1; }
  mv "$TMP.tmp" "$TMP"; chmod 755 "$TMP"
  if [ -n "$EXPECTED_SHA" ] && command -v sha256sum >/dev/null 2>&1; then
    ACTUAL_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
    [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] || { echo "TG SOCKS5 binary SHA256 mismatch (expected $EXPECTED_SHA, got $ACTUAL_SHA)"; rm -f "$TMP"; return 1; }
  fi
  "$TMP" --help >/dev/null 2>&1 || { echo 'Downloaded TG SOCKS5 binary failed self-check'; rm -f "$TMP"; return 1; }
  tggo_stop
  mv "$TMP" "$TGGO_BIN"; chmod 755 "$TGGO_BIN"
  echo "TG SOCKS5 binary installed: $TGGO_BIN"
}

tggo_enable(){
  tggo_load || return 1
  case "$TGGO_PORT" in ''|*[!0-9]*|0|[1-9]|[1-9][0-9]|[1-9][0-9][0-9][0-9][0-9]*) echo 'Invalid Telegram SOCKS5 port'; return 1;; esac
  if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | awk -v p=":$TGGO_PORT" '$4 ~ p"$"{found=1} END{exit(found?0:1)}'; then
    tggo_process_running || { echo "Telegram SOCKS5 port $TGGO_PORT is already in use"; return 2; }
  fi
  tggo_installed || tggo_install || return 1
  sed -i 's/^enabled=.*/enabled=1/' "$TGGO_CONF"
  if [ -x /etc/init.d/universal-openwrt-tg-socks5-go ]; then
    /etc/init.d/universal-openwrt-tg-socks5-go enable >/dev/null 2>&1 || true
    /etc/init.d/universal-openwrt-tg-socks5-go restart >/dev/null 2>&1 || true
  else
    tggo_stop
    ARGS="--mode socks5 --host $TGGO_HOST --port $TGGO_PORT --buf-kb $TGGO_BUF --pool-size $TGGO_POOL --dial-timeout $TGGO_DIAL --init-timeout $TGGO_INIT"
    [ "$TGGO_CF_PROXY" = 1 ] && ARGS="$ARGS --cf-proxy"
    [ "$TGGO_CF_FIRST" = 1 ] && ARGS="$ARGS --cf-proxy-first"
    [ "$TGGO_CF_BALANCE" = 1 ] && ARGS="$ARGS --cf-balance"
    [ -n "$TGGO_USER" ] && ARGS="$ARGS --username $TGGO_USER"
    [ -n "$TGGO_PASS" ] && ARGS="$ARGS --password $TGGO_PASS"
    # shellcheck disable=SC2086
    nohup "$TGGO_BIN" $ARGS >>"$TGGO_LOG" 2>&1 & echo $! >"$TGGO_PID"
    sleep 1
  fi
  tggo_running
}

tggo_disable(){
  [ -f "$TGGO_CONF" ] && sed -i 's/^enabled=.*/enabled=0/' "$TGGO_CONF" || true
  [ -x /etc/init.d/universal-openwrt-tg-socks5-go ] && /etc/init.d/universal-openwrt-tg-socks5-go disable >/dev/null 2>&1 || true
  [ -x /etc/init.d/universal-openwrt-tg-socks5-go ] && /etc/init.d/universal-openwrt-tg-socks5-go stop >/dev/null 2>&1 || true
  tggo_stop
}
