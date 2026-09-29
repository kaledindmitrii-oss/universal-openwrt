#!/bin/sh
# Dedicated Telegram controller.
# Keeps Telegram outside the generic AI/adaptive controller and monitors the
# actual local SOCKS5/WS path before changing anything.
TGCTL_CONF=${TGCTL_CONF:-/etc/universal-openwrt/telegram-controller.conf}
TGCTL_STATE=${TGCTL_STATE:-/etc/universal-openwrt/telegram-controller.state}
TGCTL_LOG=${TGCTL_LOG:-/var/log/universal-openwrt-telegram-controller.log}
TGCTL_LOCK=${TGCTL_LOCK:-/var/run/universal-openwrt-telegram-controller.lock.d}
TGCTL_PORT_DEFAULT=1080
TGCTL_INTERVAL_DEFAULT=15
TGCTL_FAIL_LIMIT_DEFAULT=2
TGCTL_DOMAINS_DEFAULT='telegram.org t.me web.telegram.org api.telegram.org'

telegram_controller_init(){
  mkdir -p "$(dirname "$TGCTL_CONF")" "$(dirname "$TGCTL_STATE")" "$(dirname "$TGCTL_LOG")" 2>/dev/null || return 1
  [ -f "$TGCTL_CONF" ] || cat >"$TGCTL_CONF" <<'EOL'
# Dedicated Telegram controller. It never participates in generic AI/adaptive selection.
enabled=0
mode=auto
port=1080
interval=15
fail_limit=2
domains="telegram.org t.me web.telegram.org api.telegram.org"
EOL
  [ -f "$TGCTL_STATE" ] || cat >"$TGCTL_STATE" <<'EOL'
status=unknown
active=none
healthy=0
fail_count=0
last_change=0
last_probe=0
last_reason=never
EOL
}

telegram_controller_load(){
  telegram_controller_init || return 1
  enabled=0; mode=auto; port=1080; interval=15; fail_limit=2; domains="$TGCTL_DOMAINS_DEFAULT"
  . "$TGCTL_CONF" 2>/dev/null || true
  TGCTL_ENABLED="$enabled"; TGCTL_MODE="$mode"; TGCTL_PORT="$port"; TGCTL_INTERVAL="$interval"; TGCTL_FAIL_LIMIT="$fail_limit"; TGCTL_DOMAINS="$domains"
  status=unknown; active=none; healthy=0; fail_count=0; last_change=0; last_probe=0; last_reason=never
  . "$TGCTL_STATE" 2>/dev/null || true
  TGCTL_STATUS="$status"; TGCTL_ACTIVE="$active"; TGCTL_HEALTHY="$healthy"; TGCTL_FAIL_COUNT="$fail_count"; TGCTL_LAST_CHANGE="$last_change"; TGCTL_LAST_PROBE="$last_probe"; TGCTL_LAST_REASON="$last_reason"
}

telegram_controller_save_state(){
  telegram_controller_init || return 1
  TMP="$TGCTL_STATE.tmp.$$"
  cat >"$TMP" <<EOL
status=$1
active=$2
healthy=$3
fail_count=$4
last_change=$5
last_probe=$6
last_reason=$7
EOL
  mv "$TMP" "$TGCTL_STATE"
}

telegram_controller_log(){ printf '[%s] %s\n' "$(date '+%F %T' 2>/dev/null || echo now)" "$*" >>"$TGCTL_LOG" 2>/dev/null || true; }

telegram_controller_lock(){
  if mkdir "$TGCTL_LOCK" 2>/dev/null; then printf '%s\n' "$$" >"$TGCTL_LOCK/pid"; return 0; fi
  P="$(cat "$TGCTL_LOCK/pid" 2>/dev/null || true)"
  case "$P" in
    ''|*[!0-9]*) rm -rf "$TGCTL_LOCK" 2>/dev/null || true;;
    *) kill -0 "$P" 2>/dev/null && return 1 || rm -rf "$TGCTL_LOCK" 2>/dev/null || true;;
  esac
  mkdir "$TGCTL_LOCK" 2>/dev/null || return 1
  printf '%s\n' "$$" >"$TGCTL_LOCK/pid"
  return 0
}
telegram_controller_unlock(){ rm -rf "$TGCTL_LOCK" 2>/dev/null || true; }

telegram_controller_active(){
  if tggo_running 2>/dev/null; then echo socks5; return 0; fi
  if tgws_configured 2>/dev/null && tgws_running 2>/dev/null; then echo ws; return 0; fi
  if tg_failover_runtime_socks 2>/dev/null; then echo external-socks5; return 0; fi
  if telemt_configured 2>/dev/null && telemt_process_running 2>/dev/null; then echo telemt; return 0; fi
  echo none
}

telegram_controller_curl(){
  command -v curl >/dev/null 2>&1 || return 127
  curl -fsSIL --connect-timeout 4 --max-time 8 "$1" >/dev/null 2>&1
}

telegram_controller_probe_direct(){
  D=''
  for D in $TGCTL_DOMAINS; do
    telegram_controller_curl "https://$D/" && return 0
  done
  return 1
}

telegram_controller_probe_socks(){
  command -v curl >/dev/null 2>&1 || return 127
  P="${TGCTL_PORT:-$TGCTL_PORT_DEFAULT}"
  D=''
  for D in $TGCTL_DOMAINS; do
    curl -fsSIL --connect-timeout 5 --max-time 10 --proxy "socks5h://127.0.0.1:$P" "https://$D/" >/dev/null 2>&1 && return 0
  done
  return 1
}

telegram_controller_probe(){
  telegram_controller_load || return 1
  ACTIVE="$(telegram_controller_active)"
  case "$ACTIVE" in
    socks5)
      if telegram_controller_probe_socks; then printf 'status=pass\nactive=socks5\nreason=socks5_probe_ok\n'; return 0; fi
      printf 'status=fail\nactive=socks5\nreason=socks5_probe_failed\n'; return 1;;
    ws)
      # MTProto/WS is not a local SOCKS endpoint; process health is the safest
      # generic check here. Detailed Telegram handshake remains provider-side.
      tgws_running && { printf 'status=degraded\nactive=ws\nreason=ws_process_alive\n'; return 0; }
      printf 'status=fail\nactive=ws\nreason=ws_process_dead\n'; return 1;;
    external-socks5)
      if [ -s /etc/universal-openwrt/telegram-socks5.conf ]; then printf 'status=degraded\nactive=external-socks5\nreason=external_socks_runtime\n'; return 0; fi
      printf 'status=fail\nactive=external-socks5\nreason=external_socks_unknown\n'; return 1;;
    telemt)
      telemt_process_running && { printf 'status=degraded\nactive=telemt\nreason=telemt_process_alive\n'; return 0; }
      printf 'status=fail\nactive=telemt\nreason=telemt_process_dead\n'; return 1;;
    *)
      telegram_controller_probe_direct && { printf 'status=direct\nactive=none\nreason=direct_ok\n'; return 0; }
      printf 'status=fail\nactive=none\nreason=no_telegram_path\n'; return 1;;
  esac
}

telegram_controller_status(){
  telegram_controller_load || return 1
  ACTIVE="$(telegram_controller_active)"
  TELEMT_CFG=no; TELEMT_RUN=no; telemt_configured 2>/dev/null && TELEMT_CFG=yes || true; telemt_process_running 2>/dev/null && TELEMT_RUN=yes || true
  printf 'enabled=%s\nmode=%s\nport=%s\ninterval=%s\nfail_limit=%s\nstatus=%s\nactive=%s\nhealthy=%s\nfail_count=%s\nlast_change=%s\nlast_probe=%s\nlast_reason=%s\n' \
    "$TGCTL_ENABLED" "$TGCTL_MODE" "$TGCTL_PORT" "$TGCTL_INTERVAL" "$TGCTL_FAIL_LIMIT" "$TGCTL_STATUS" "$ACTIVE" "$TGCTL_HEALTHY" "$TGCTL_FAIL_COUNT" "$TGCTL_LAST_CHANGE" "$TGCTL_LAST_PROBE" "$TGCTL_LAST_REASON"; printf 'telemt_configured=%s\ntelemt_running=%s\n' "$TELEMT_CFG" "$TELEMT_RUN"
}

telegram_controller_recover(){
  telegram_controller_load || return 1
  telegram_controller_lock || { echo 'Telegram controller is busy'; return 2; }
  NOW="$(date +%s)"
  ACTIVE="$(telegram_controller_active)"
  if telegram_controller_probe >/tmp/uowrt-tg-probe.$$ 2>/dev/null; then
    REASON="$(sed -n 's/^reason=//p' /tmp/uowrt-tg-probe.$$ | head -n1)"; rm -f /tmp/uowrt-tg-probe.$$
    telegram_controller_save_state pass "$ACTIVE" 1 0 "${TGCTL_LAST_CHANGE:-0}" "$NOW" "${REASON:-healthy}"
    telegram_controller_unlock
    echo 'Telegram: already healthy; no change applied'
    return 0
  fi
  rm -f /tmp/uowrt-tg-probe.$$
  case "$TGCTL_MODE" in off) telegram_controller_save_state fail "$ACTIVE" 0 $((TGCTL_FAIL_COUNT+1)) "${TGCTL_LAST_CHANGE:-0}" "$NOW" disabled; telegram_controller_unlock; return 1;; esac

  # Explicit modes are strict: selecting a backend never silently falls through
  # to another Telegram provider. This keeps the Telegram controller isolated
  # and prevents two Telegram transports from competing for ownership.
  case "$TGCTL_MODE" in
    socks5)
      tgws_disable >/dev/null 2>&1 || true
      telemt_disable >/dev/null 2>&1 || true
      tg_proxy_disable >/dev/null 2>&1 || true
      tggo_enable >/dev/null 2>&1 || true
      if telegram_controller_probe >/dev/null 2>&1; then
        telegram_controller_save_state pass socks5 1 0 "$NOW" "$NOW" forced_socks5
        telegram_controller_unlock; echo 'Telegram: SOCKS5 active'; return 0
      fi
      telegram_controller_save_state fail none 0 $((TGCTL_FAIL_COUNT+1)) "${TGCTL_LAST_CHANGE:-0}" "$NOW" socks5_failed
      telegram_controller_unlock; echo 'Telegram: SOCKS5 path failed' >&2; return 1;;
    ws)
      tggo_disable >/dev/null 2>&1 || true
      telemt_disable >/dev/null 2>&1 || true
      tg_proxy_disable >/dev/null 2>&1 || true
      if tgws_enable >/dev/null 2>&1 && telegram_controller_probe >/dev/null 2>&1; then
        telegram_controller_save_state degraded ws 1 0 "$NOW" "$NOW" forced_ws
        telegram_controller_unlock; echo 'Telegram: WS active'; return 0
      fi
      telegram_controller_save_state fail none 0 $((TGCTL_FAIL_COUNT+1)) "${TGCTL_LAST_CHANGE:-0}" "$NOW" ws_failed
      telegram_controller_unlock; echo 'Telegram: WS path failed' >&2; return 1;;
    telemt)
      tggo_disable >/dev/null 2>&1 || true
      tgws_disable >/dev/null 2>&1 || true
      tg_proxy_disable >/dev/null 2>&1 || true
      if telemt_configured 2>/dev/null && telemt_enable >/dev/null 2>&1 && telegram_controller_probe >/dev/null 2>&1; then
        telegram_controller_save_state degraded telemt 1 0 "$NOW" "$NOW" forced_telemt
        telegram_controller_unlock; echo 'Telegram: Rust Telemt active'; return 0
      fi
      telegram_controller_save_state fail none 0 $((TGCTL_FAIL_COUNT+1)) "${TGCTL_LAST_CHANGE:-0}" "$NOW" telemt_failed
      telegram_controller_unlock; echo 'Telegram: Telemt path failed' >&2; return 1;;
  esac

  # Auto mode may fail over only inside the dedicated Telegram backend family.
  # It never calls the generic strategy/AI engine.
  # Prefer the dedicated local SOCKS5 bridge. Never change generic strategy state.
  if [ "$ACTIVE" = socks5 ]; then
    tggo_stop >/dev/null 2>&1 || true
    tggo_enable >/dev/null 2>&1 || true
    if telegram_controller_probe >/dev/null 2>&1; then
      telegram_controller_save_state pass socks5 1 0 "$NOW" "$NOW" restarted_socks5
      telegram_controller_unlock; echo 'Telegram: SOCKS5 recovered'; return 0
    fi
  else
    tggo_enable >/dev/null 2>&1 || true
    if telegram_controller_probe >/dev/null 2>&1; then
      telegram_controller_save_state pass socks5 1 0 "$NOW" "$NOW" started_socks5
      telegram_controller_unlock; echo 'Telegram: SOCKS5 started and verified'; return 0
    fi
  fi
  # Only switch to another Telegram-specific path after the local SOCKS5 path fails.
  if tgws_configured 2>/dev/null; then
    tggo_disable >/dev/null 2>&1 || true
    if tgws_enable >/dev/null 2>&1 && telegram_controller_probe >/dev/null 2>&1; then
      telegram_controller_save_state degraded ws 1 0 "$NOW" "$NOW" fallback_ws
      telegram_controller_unlock; echo 'Telegram: WS fallback active'; return 0
    fi
    tgws_disable >/dev/null 2>&1 || true
  fi
  if [ "$TGCTL_MODE" = telemt ] && telemt_configured 2>/dev/null; then
    tggo_disable >/dev/null 2>&1 || true; tgws_disable >/dev/null 2>&1 || true; tg_proxy_disable >/dev/null 2>&1 || true
    if telemt_enable >/dev/null 2>&1 && telemt_process_running; then
      telegram_controller_save_state degraded telemt 1 0 "$NOW" "$NOW" telemt_active
      telegram_controller_unlock; echo 'Telegram: Rust Telemt active'; return 0
    fi
  fi
  # Existing external Telegram SOCKS5 policy is the final dedicated fallback.
  if tg_failover_runtime_socks 2>/dev/null; then
    telegram_controller_save_state degraded external-socks5 1 0 "$NOW" "$NOW" fallback_external_socks5
    telegram_controller_unlock; echo 'Telegram: external SOCKS5 path detected'; return 0
  fi
  FC=$((TGCTL_FAIL_COUNT+1))
  telegram_controller_save_state fail none 0 "$FC" "${TGCTL_LAST_CHANGE:-0}" "$NOW" all_telegram_paths_failed
  telegram_controller_unlock
  echo 'Telegram: no healthy dedicated path found' >&2
  return 1
}

telegram_controller_config(){
  telegram_controller_init || return 1
  EN="${1:-0}"; MODE="${2:-auto}"; PORT="${3:-1080}"; INT="${4:-15}"; LIMIT="${5:-2}"
  case "$EN" in 0|1) ;; *) return 1;; esac
  case "$MODE" in auto|off|socks5|ws|telemt) ;; *) return 1;; esac
  case "$PORT" in ''|*[!0-9]*|0) return 1;; esac
  case "$INT" in ''|*[!0-9]*|0) return 1;; esac
  case "$LIMIT" in ''|*[!0-9]*|0) return 1;; esac
  TMP="$TGCTL_CONF.tmp.$$"
  cat >"$TMP" <<EOL
enabled=$EN
mode=$MODE
port=$PORT
interval=$INT
fail_limit=$LIMIT
domains="$TGCTL_DOMAINS_DEFAULT"
EOL
  mv "$TMP" "$TGCTL_CONF"
  if [ "$EN" = 1 ] && [ -x /etc/init.d/universal-openwrt-telegram-controller ]; then
    /etc/init.d/universal-openwrt-telegram-controller enable >/dev/null 2>&1 || true
    /etc/init.d/universal-openwrt-telegram-controller restart >/dev/null 2>&1 || true
  elif [ "$EN" = 0 ] && [ -x /etc/init.d/universal-openwrt-telegram-controller ]; then
    /etc/init.d/universal-openwrt-telegram-controller disable >/dev/null 2>&1 || true
    /etc/init.d/universal-openwrt-telegram-controller stop >/dev/null 2>&1 || true
  fi
  telegram_controller_status
}

telegram_controller_enable(){ telegram_controller_load; telegram_controller_config 1 "$TGCTL_MODE" "$TGCTL_PORT" "$TGCTL_INTERVAL" "$TGCTL_FAIL_LIMIT"; }
telegram_controller_disable(){ telegram_controller_load; telegram_controller_config 0 "$TGCTL_MODE" "$TGCTL_PORT" "$TGCTL_INTERVAL" "$TGCTL_FAIL_LIMIT"; }

telegram_controller_run(){
  telegram_controller_load || return 1
  [ "$TGCTL_ENABLED" = 1 ] || { telegram_controller_status; return 0; }
  telegram_controller_recover
}
