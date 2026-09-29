#!/bin/sh
# Universal OpenWrt daily strategy automation.
# Runs at 04:00 router-local time, benchmarks the current network state,
# evaluates available strategies through the existing adaptive controller,
# keeps the best stable candidate and rolls back rejected candidates.

UOWRT_AUTOMATION_DIR='/etc/universal-openwrt/automation'
UOWRT_AUTOMATION_STATE="$UOWRT_AUTOMATION_DIR/state"
UOWRT_AUTOMATION_LOG="$UOWRT_AUTOMATION_DIR/history.log"
UOWRT_AUTOMATION_LOCK='/var/run/universal-openwrt-daily.lock.d'
UOWRT_AUTOMATION_CRONTAB='/etc/crontabs/root'
UOWRT_AUTOMATION_MARKER='# UOWRT_DAILY_STRATEGY'
UOWRT_AUTOMATION_CRON=''

# Supported intervals divide a 24-hour day so cron can represent them exactly.
UOWRT_AUTOMATION_INTERVALS='1 2 3 4 6 8 12 24'

automation_init(){
  mkdir -p "$UOWRT_AUTOMATION_DIR" 2>/dev/null || return 1
  [ -f "$UOWRT_AUTOMATION_STATE" ] || cat >"$UOWRT_AUTOMATION_STATE" <<'EOL'
enabled=0
hour=4
minute=0
interval_hours=24
last_start=0
last_end=0
last_rc=0
last_strategy=baseline
last_score=
last_signal=
EOL
  touch "$UOWRT_AUTOMATION_LOG" 2>/dev/null || return 1
}
automation_state_get(){ automation_init || return 1; awk -F= -v k="$1" '$1==k{print substr($0,index($0,"=")+1);exit}' "$UOWRT_AUTOMATION_STATE" 2>/dev/null; }
automation_state_set(){ automation_init || return 1; K="$1"; V="$2"; T="$UOWRT_AUTOMATION_STATE.tmp.$$"; awk -F= -v k="$K" '$1!=k{print}' "$UOWRT_AUTOMATION_STATE" 2>/dev/null >"$T" || true; printf '%s=%s\n' "$K" "$V" >>"$T"; mv "$T" "$UOWRT_AUTOMATION_STATE"; }
automation_log(){ printf '[%s] %s\n' "$(date '+%F %T' 2>/dev/null || echo now)" "$*" >>"$UOWRT_AUTOMATION_LOG"; }

automation_valid_time(){
  case "$1" in ''|*[!0-9]*) return 1;; esac
  [ "$1" -ge 0 ] 2>/dev/null && [ "$1" -le 23 ] 2>/dev/null
}
automation_valid_minute(){
  case "$1" in ''|*[!0-9]*) return 1;; esac
  [ "$1" -ge 0 ] 2>/dev/null && [ "$1" -le 59 ] 2>/dev/null
}
automation_valid_interval(){
  case " $UOWRT_AUTOMATION_INTERVALS " in *" $1 "*) return 0;; esac
  return 1
}
automation_build_cron(){
  H="$1"; M="$2"; I="$3"
  automation_valid_time "$H" || return 1
  automation_valid_minute "$M" || return 1
  automation_valid_interval "$I" || return 1
  HOURS=''
  N=0
  while [ "$N" -lt 24 ]; do
    X=$(( (H + N) % 24 ))
    if [ -n "$HOURS" ]; then HOURS="$HOURS,$X"; else HOURS="$X"; fi
    N=$((N + I))
  done
  UOWRT_AUTOMATION_CRON="$M $HOURS * * * /usr/sbin/universal-openwrt --automation-run # UOWRT_DAILY_STRATEGY"
  printf '%s\n' "$UOWRT_AUTOMATION_CRON"
}
automation_cron_installed(){
  [ -f "$UOWRT_AUTOMATION_CRONTAB" ] || return 1
  grep -F -q "$UOWRT_AUTOMATION_MARKER" "$UOWRT_AUTOMATION_CRONTAB" 2>/dev/null
}
automation_write_cron(){
  automation_build_cron "$(automation_state_get hour)" "$(automation_state_get minute)" "$(automation_state_get interval_hours)" >/dev/null || return 1
  mkdir -p "$(dirname "$UOWRT_AUTOMATION_CRONTAB")" 2>/dev/null || return 1
  touch "$UOWRT_AUTOMATION_CRONTAB" 2>/dev/null || return 1
  T="$UOWRT_AUTOMATION_CRONTAB.tmp.$$"
  grep -F -v "$UOWRT_AUTOMATION_MARKER" "$UOWRT_AUTOMATION_CRONTAB" >"$T" 2>/dev/null || true
  printf '%s\n' "$UOWRT_AUTOMATION_CRON" >>"$T"
  mv "$T" "$UOWRT_AUTOMATION_CRONTAB" || return 1
  return 0
}
automation_cron_reload(){
  if [ -x /etc/init.d/cron ]; then
    /etc/init.d/cron enable >/dev/null 2>&1 || true
    /etc/init.d/cron restart >/dev/null 2>&1 || /etc/init.d/cron start >/dev/null 2>&1 || true
  fi
}
automation_enable(){
  automation_init || return 1
  automation_state_set enabled 1
  automation_write_cron || { automation_state_set enabled 0; return 1; }
  automation_cron_reload
  H="$(automation_state_get hour)"; M="$(automation_state_get minute)"; I="$(automation_state_get interval_hours)"
  automation_log "Strategy automation enabled: anchor=$(printf '%02d:%02d' "$H" "$M") interval=${I}h router-local time."
  echo "Strategy automation: ENABLED (start $(printf '%02d:%02d' "$H" "$M"), every ${I}h, router-local time)"
}
automation_disable(){
  automation_init || return 1
  if [ -f "$UOWRT_AUTOMATION_CRONTAB" ]; then
    T="$UOWRT_AUTOMATION_CRONTAB.tmp.$$"
    grep -F -v "$UOWRT_AUTOMATION_MARKER" "$UOWRT_AUTOMATION_CRONTAB" >"$T" 2>/dev/null || true
    mv "$T" "$UOWRT_AUTOMATION_CRONTAB" || return 1
  fi
  automation_state_set enabled 0
  automation_cron_reload
  automation_log 'Strategy automation disabled.'
  echo 'Strategy automation: DISABLED'
}
automation_config(){
  automation_init || return 1
  E="$1"; H="$2"; M="$3"; I="$4"
  case "$E" in 0|1) ;; *) echo 'Invalid enabled value'; return 2;; esac
  automation_valid_time "$H" || { echo 'Invalid hour: use 0-23'; return 2; }
  automation_valid_minute "$M" || { echo 'Invalid minute: use 0-59'; return 2; }
  automation_valid_interval "$I" || { echo "Invalid interval: supported values: $UOWRT_AUTOMATION_INTERVALS"; return 2; }
  automation_state_set hour "$H"
  automation_state_set minute "$M"
  automation_state_set interval_hours "$I"
  if [ "$E" = 1 ]; then automation_enable; else automation_disable; fi
}
automation_status(){
  automation_init || return 1
  H="$(automation_state_get hour)"; M="$(automation_state_get minute)"; I="$(automation_state_get interval_hours)"
  [ -n "$H" ] || H=4; [ -n "$M" ] || M=0; [ -n "$I" ] || I=24
  echo 'Strategy Automation'
  echo "enabled=$(automation_state_get enabled)"
  echo "hour=$H"
  echo "minute=$M"
  echo "interval_hours=$I"
  echo "schedule=$(printf '%02d:%02d' "$H" "$M") every ${I}h router-local-time"
  echo "cron=$(automation_cron_installed && echo installed || echo not-installed)"
  echo "cron_entry=$(automation_build_cron "$H" "$M" "$I" 2>/dev/null || true)"
  echo "last_start=$(automation_state_get last_start)"
  echo "last_end=$(automation_state_get last_end)"
  echo "last_rc=$(automation_state_get last_rc)"
  echo "last_strategy=$(automation_state_get last_strategy)"
  echo "last_score=$(automation_state_get last_score)"
  echo "last_signal=$(automation_state_get last_signal)"
  echo "log=$UOWRT_AUTOMATION_LOG"
}
automation_lock(){
  if mkdir "$UOWRT_AUTOMATION_LOCK" 2>/dev/null; then
    printf '%s\n' "$$" >"$UOWRT_AUTOMATION_LOCK/pid"
    return 0
  fi
  P="$(cat "$UOWRT_AUTOMATION_LOCK/pid" 2>/dev/null || true)"
  case "$P" in
    ''|*[!0-9]*) rm -rf "$UOWRT_AUTOMATION_LOCK" 2>/dev/null || true;;
    *) if kill -0 "$P" 2>/dev/null; then return 1; else rm -rf "$UOWRT_AUTOMATION_LOCK" 2>/dev/null || true; fi;;
  esac
  mkdir "$UOWRT_AUTOMATION_LOCK" 2>/dev/null || return 1
  printf '%s\n' "$$" >"$UOWRT_AUTOMATION_LOCK/pid"
  return 0
}
automation_unlock(){ rm -rf "$UOWRT_AUTOMATION_LOCK" 2>/dev/null || true; }
automation_run(){
  automation_init || return 1
  automation_lock || { automation_log 'Skipped: another daily strategy run is already active.'; return 3; }
  START="$(date +%s)"; automation_state_set last_start "$START"; automation_log 'Daily strategy evaluation started.'
  RC=0
  # Refresh the resource matrix first, but never abort a strategy evaluation
  # solely because the remote list could not be refreshed.
  if resource_matrix_init 2>/dev/null; then
    resource_matrix_remote_update >/dev/null 2>&1 || automation_log 'Resource list refresh failed; using cached resources.'
  fi
  # Keep reserve community strategy sources current when available.
  zapret_source_update >/dev/null 2>&1 || automation_log 'Zapret source refresh unavailable; keeping cached sources.'
  AUTOMATION_FORCE_BENCHMARK=1 SPEED=standard adaptive_controller_run >>"$UOWRT_AUTOMATION_LOG" 2>&1 || RC=$?
  ACTIVE="$(adaptive_state_get active 2>/dev/null || echo baseline)"
  SCORE="$(adaptive_state_get score 2>/dev/null || true)"
  SIGNAL="$(adaptive_state_get signal 2>/dev/null || true)"
  END="$(date +%s)"
  automation_state_set last_end "$END"
  automation_state_set last_rc "$RC"
  automation_state_set last_strategy "${ACTIVE:-baseline}"
  automation_state_set last_score "$SCORE"
  automation_state_set last_signal "$SIGNAL"
  automation_log "Daily strategy evaluation finished: rc=$RC strategy=${ACTIVE:-baseline} score=${SCORE:-unknown} signal=${SIGNAL:-unknown}."
  automation_unlock
  return "$RC"
}
