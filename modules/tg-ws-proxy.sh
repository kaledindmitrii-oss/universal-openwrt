#!/bin/sh
# Optional Telegram MTProto WebSocket backend.
# This module does not redistribute a third-party binary. It integrates a locally
# installed tg-ws-proxy / tg-ws-proxy-rs executable.
TGWS_CONF=${TGWS_CONF:-/etc/universal-openwrt/telegram-ws.conf}
TGWS_PID=${TGWS_PID:-/var/run/universal-openwrt-tg-ws.pid}
TGWS_LOG=${TGWS_LOG:-/var/log/universal-openwrt-tg-ws.log}
TGWS_PORT_DEFAULT=1443

tgws_init(){
  mkdir -p "$(dirname "$TGWS_CONF")" "$(dirname "$TGWS_PID")" "$(dirname "$TGWS_LOG")" 2>/dev/null || return 1
  [ -f "$TGWS_CONF" ] || cat >"$TGWS_CONF" <<'EOL'
# Optional Telegram MTProto WebSocket proxy backend.
# Install a compatible tg-ws-proxy or tg-ws-proxy-rs binary separately.
enabled=0
port=1443
secret=
link_ip=
binary=
EOL
}

tgws_load(){
  tgws_init || return 1
  enabled=0; port=1443; secret=''; link_ip=''; binary=''
  . "$TGWS_CONF" 2>/dev/null || true
  TGWS_ENABLED="$enabled"; TGWS_PORT="$port"; TGWS_SECRET="$secret"; TGWS_LINK_IP="$link_ip"; TGWS_BIN_CFG="$binary"
}

tgws_find_bin(){
  tgws_load || return 1
  if [ -n "$TGWS_BIN_CFG" ] && [ -x "$TGWS_BIN_CFG" ]; then printf '%s\n' "$TGWS_BIN_CFG"; return 0; fi
  for b in /usr/bin/tg-ws-proxy-rs /usr/bin/tg-ws-proxy /usr/sbin/tg-ws-proxy-rs /usr/sbin/tg-ws-proxy; do
    [ -x "$b" ] && { printf '%s\n' "$b"; return 0; }
  done
  command -v tg-ws-proxy-rs 2>/dev/null && return 0
  command -v tg-ws-proxy 2>/dev/null && return 0
  return 1
}

tgws_configured(){ tgws_load; BIN="$(tgws_find_bin 2>/dev/null || true)"; [ "$TGWS_ENABLED" = 1 ] && [ -n "$TGWS_SECRET" ] && [ -n "$BIN" ]; }

tgws_process_running(){
  [ -f "$TGWS_PID" ] && kill -0 "$(cat "$TGWS_PID" 2>/dev/null)" 2>/dev/null && return 0
  BIN="$(tgws_find_bin 2>/dev/null || true)"
  [ -n "$BIN" ] && ps w 2>/dev/null | grep -F "$BIN" | grep -v grep >/dev/null 2>&1
}
tgws_running(){
  tgws_load || return 1
  [ "$TGWS_ENABLED" = 1 ] || return 1
  tgws_process_running
}
tgws_status(){
  tgws_load || return 1
  BIN="$(tgws_find_bin 2>/dev/null || true)"
  PROCESS_RUNNING=no; tgws_process_running && PROCESS_RUNNING=yes
  CONFIGURED=no; [ "$TGWS_ENABLED" = 1 ] && [ -n "$TGWS_SECRET" ] && [ -n "$BIN" ] && CONFIGURED=yes
  RUNNING=no; [ "$TGWS_ENABLED" = 1 ] && [ "$PROCESS_RUNNING" = yes ] && RUNNING=yes
  ACTIVE=no; [ "$RUNNING" = yes ] && [ "$CONFIGURED" = yes ] && ACTIVE=yes
  printf 'enabled=%s\nport=%s\nrunning=%s\nprocess_running=%s\nbinary=%s\nconfigured=%s\nactive=%s\n' "$TGWS_ENABLED" "$TGWS_PORT" "$RUNNING" "$PROCESS_RUNNING" "${BIN:-missing}" "$CONFIGURED" "$ACTIVE"
}

tgws_stop(){
  if [ -f "$TGWS_PID" ]; then PID="$(cat "$TGWS_PID" 2>/dev/null)"; kill "$PID" 2>/dev/null || true; sleep 1; kill -9 "$PID" 2>/dev/null || true; rm -f "$TGWS_PID"; fi
}

tgws_enable(){
  tgws_load || return 1
  [ "$TGWS_ENABLED" = 1 ] || { echo 'Telegram WS backend is disabled in configuration'; return 2; }
  BIN="$(tgws_find_bin 2>/dev/null || true)"
  [ -n "$BIN" ] || { echo 'Telegram WS backend binary is not installed'; return 2; }
  case "$TGWS_PORT" in ''|*[!0-9]*|0|[1-9]|[1-9][0-9]|[1-9][0-9][0-9][0-9][0-9]*) echo 'Invalid Telegram WS port'; return 1;; esac
  [ -n "$TGWS_SECRET" ] || { echo 'Telegram WS secret is not configured'; return 2; }
  if [ -x /etc/init.d/universal-openwrt-tg-ws ]; then /etc/init.d/universal-openwrt-tg-ws enable >/dev/null 2>&1 || true; /etc/init.d/universal-openwrt-tg-ws restart >/dev/null 2>&1; sleep 1; tgws_status; tgws_running; return $?; fi
  tgws_stop
  ARGS="--port $TGWS_PORT --secret $TGWS_SECRET"
  [ -n "$TGWS_LINK_IP" ] && ARGS="$ARGS --link-ip $TGWS_LINK_IP"
  # shellcheck disable=SC2086
  nohup "$BIN" $ARGS >>"$TGWS_LOG" 2>&1 &
  PID=$!; echo "$PID" >"$TGWS_PID"; sleep 1
  kill -0 "$PID" 2>/dev/null || { rm -f "$TGWS_PID"; echo 'Telegram WS backend failed to start'; return 1; }
  echo "Telegram MTProto WebSocket proxy started on port $TGWS_PORT"
}

tgws_disable(){ if [ -x /etc/init.d/universal-openwrt-tg-ws ]; then /etc/init.d/universal-openwrt-tg-ws stop >/dev/null 2>&1 || true; fi; tgws_stop; echo 'Telegram MTProto WebSocket proxy stopped'; }
