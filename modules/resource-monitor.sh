#!/bin/sh
# Universal OpenWrt v30.2.19 — live resource monitor and guarded recovery queue.
# The monitor is intentionally read/diagnose first. Strategy mutation remains
# behind the shared controller lock and the AI engine's rollback/guard logic.

UOWRT_RESOURCE_MONITOR_DIR="${UOWRT_RESOURCE_MONITOR_DIR:-/etc/universal-openwrt/resource-monitor}"
UOWRT_RESOURCE_MONITOR_STATE="${UOWRT_RESOURCE_MONITOR_STATE:-$UOWRT_RESOURCE_MONITOR_DIR/state.tsv}"
UOWRT_RESOURCE_MONITOR_LOG="${UOWRT_RESOURCE_MONITOR_LOG:-$UOWRT_RESOURCE_MONITOR_DIR/events.log}"
UOWRT_RESOURCE_MONITOR_SERVICES="${UOWRT_RESOURCE_MONITOR_SERVICES:-openai anthropic gemini kimi deepseek perplexity mistral grok copilot youtube instagram x}"

resource_monitor_init(){
  mkdir -p "$UOWRT_RESOURCE_MONITOR_DIR" 2>/dev/null || return 1
  [ -f "$UOWRT_RESOURCE_MONITOR_STATE" ] || printf 'service\tstatus\treason\tstrategy\tupdated\tchange\n' >"$UOWRT_RESOURCE_MONITOR_STATE"
  touch "$UOWRT_RESOURCE_MONITOR_LOG" 2>/dev/null || true
}
resource_monitor_event(){
  resource_monitor_init >/dev/null 2>&1 || true
  printf '%s\t%s\n' "$(date +%s)" "$*" >>"$UOWRT_RESOURCE_MONITOR_LOG" 2>/dev/null || true
}
resource_monitor_set(){
  _rm_s="$1"; _rm_status="$2"; _rm_reason="$3"; _rm_strategy="${4:-none}"; _rm_change="${5:-none}"; _rm_ts="$(date +%s)"
  resource_monitor_init >/dev/null 2>&1 || true
  awk -F '\t' -v s="$_rm_s" '$1!=s' "$UOWRT_RESOURCE_MONITOR_STATE" >"$UOWRT_RESOURCE_MONITOR_STATE.tmp" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$_rm_s" "$_rm_status" "$_rm_reason" "$_rm_strategy" "$_rm_ts" "$_rm_change" >>"$UOWRT_RESOURCE_MONITOR_STATE.tmp"
  mv -f "$UOWRT_RESOURCE_MONITOR_STATE.tmp" "$UOWRT_RESOURCE_MONITOR_STATE"
}
resource_monitor_status(){
  resource_monitor_init || return 1
  printf '=== RESOURCE MONITOR ===\n'
  printf 'services=%s\n' "$UOWRT_RESOURCE_MONITOR_SERVICES"
  cat "$UOWRT_RESOURCE_MONITOR_STATE"
}
resource_monitor_scan(){
  resource_monitor_init || return 1
  _rm_failed=0; _rm_ok=0; _rm_unknown=0
  printf '=== RESOURCE MONITOR SCAN ===\n'
  for _rm_s in $UOWRT_RESOURCE_MONITOR_SERVICES; do
    _rm_raw="$(ai_probe_service "$_rm_s" 2>/dev/null || true)"
    _rm_st="$(printf '%s\n' "$_rm_raw" | sed -n 's/^status=//p' | tail -1)"
    [ -n "$_rm_st" ] || _rm_st=UNKNOWN
    _rm_reason="$(printf '%s\n' "$_rm_raw" | sed -n 's/^next=//p' | tail -1)"
    case "$_rm_st" in
      PASS) _rm_ok=$((_rm_ok+1));;
      UNKNOWN) _rm_unknown=$((_rm_unknown+1));;
      *) _rm_failed=$((_rm_failed+1));;
    esac
    resource_monitor_set "$_rm_s" "$_rm_st" "${_rm_reason:-diagnostic}" "none" "observed"
    printf '%-12s %-20s %s\n' "$_rm_s" "$_rm_st" "${_rm_reason:-diagnostic}"
  done
  printf 'summary=ok:%s failed:%s unknown:%s\n' "$_rm_ok" "$_rm_failed" "$_rm_unknown"
  resource_monitor_event "scan ok=$_rm_ok failed=$_rm_failed unknown=$_rm_unknown"
  [ "$_rm_failed" -eq 0 ]
}
resource_monitor_failed(){
  resource_monitor_init || return 1
  awk -F '\t' 'NR>1 && $2!="PASS" && $2!="UNKNOWN" {print $1}' "$UOWRT_RESOURCE_MONITOR_STATE" 2>/dev/null
}
resource_monitor_healthy(){
  resource_monitor_init || return 1
  awk -F '\t' 'NR>1 && $2=="PASS" {print $1}' "$UOWRT_RESOURCE_MONITOR_STATE" 2>/dev/null
}
resource_monitor_recovery(){
  # One guarded recovery pass. Healthy resources are never selected as targets.
  # ai_apply snapshots the current working state, guards already-healthy
  # resources, and rolls back any candidate that regresses them.
  resource_monitor_scan >/dev/null 2>&1 || true
  _rm_queue="$(resource_monitor_failed || true)"
  [ -n "$_rm_queue" ] || { echo 'RESOURCE-MONITOR: all monitored resources are healthy.'; return 0; }
  for _rm_s in $_rm_queue; do
    # State may have changed after a previous candidate; never repair a resource
    # that has already recovered as a side effect of another global strategy.
    _rm_now="$(ai_probe_service "$_rm_s" 2>/dev/null || true)"
    _rm_now_st="$(printf '%s\n' "$_rm_now" | sed -n 's/^status=//p' | tail -1)"
    if [ "$_rm_now_st" = PASS ]; then
      resource_monitor_set "$_rm_s" PASS recovered-by-previous-strategy none recovered
      continue
    fi
    resource_monitor_event "recovery target=$_rm_s status=$_rm_now_st"
    echo "RESOURCE-MONITOR: recovering=$_rm_s status=${_rm_now_st:-UNKNOWN}"
    if ai_apply "$_rm_s"; then
      resource_monitor_set "$_rm_s" PASS monitored-recovery none recovered
      echo "RESOURCE-MONITOR: recovered=$_rm_s"
    else
      resource_monitor_set "$_rm_s" "${_rm_now_st:-FAILED}" "no-safe-candidate" none failed
      echo "RESOURCE-MONITOR: no safe candidate for=$_rm_s"
    fi
    # Rebuild the queue from reality. A successful global strategy may have
    # recovered several other failed resources; those are now removed.
    resource_monitor_scan >/dev/null 2>&1 || true
  done
  echo '=== RESOURCE MONITOR FINAL ==='
  resource_monitor_status
  resource_monitor_scan >/dev/null 2>&1
}
