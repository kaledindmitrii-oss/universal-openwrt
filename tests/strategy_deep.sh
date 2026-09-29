#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SRC="$ROOT/src/universal-openwrt"
AI="$ROOT/modules/ai-access-engine.sh"
INS="$ROOT/installer/install.sh"
AUTO="$ROOT/modules/automation.sh"
for f in "$SRC" "$AI" "$INS" "$AUTO"; do sh -n "$f"; done
# Specialized DPI labels must not be benchmarked as separate identical implementations.
grep -Fq 'video|discord|gaming|social-video) echo dpi' "$SRC"
grep -Fq 'video|social-video|discord|gaming) printf' "$SRC"
# Adaptive lock must be PID based and stale-lock aware.
grep -Fq 'kill -0 "$_controller_pid"' "$SRC"
grep -Fq 'UOWRT_CONTROLLER_LOCK=' "$SRC"
grep -Fq 'mkdir "$UOWRT_CONTROLLER_LOCK"' "$SRC"
grep -Fq 'adaptive_guard_regressions' "$SRC"
grep -Fq 'healthy protected service regressed' "$SRC"
grep -Fq 'Manual and automatic strategy changes share one mutation gate' "$SRC"
# Rollback must remove generated configs/directories absent from snapshot.
grep -Fq 'rm -rf /etc/universal-openwrt/awg' "$SRC"
grep -Fq 'rm -f "$TGGO_CONF"' "$SRC"
# Installer must not silently enable automation.
! grep -Eq '^[[:space:]]*enable_daily_automation[[:space:]]*$' "$INS"
# AI classification and guarded service-level application contract.
grep -Fq '[ "$DNSOK" = 1 ] && { echo DNS_BLOCK' "$AI"
grep -Fq '[ "$CODE" = 000 ] && [ "$V4" = 0 ] && [ "$V6" = 0 ] && { echo IP_BLOCK_OR_GEO' "$AI"
grep -Fq 'ai_strategy_candidates(){' "$AI"
grep -Fq 'ai_apply(){' "$AI"
printf '%s\n' 'strategy_deep: OK'
