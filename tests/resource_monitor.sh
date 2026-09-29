#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/modules/resource-monitor.sh"
AI="$ROOT/modules/ai-access-engine.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
UOWRT_RESOURCE_MONITOR_DIR="$TMP/monitor"
UOWRT_RESOURCE_MONITOR_STATE="$UOWRT_RESOURCE_MONITOR_DIR/state.tsv"
UOWRT_RESOURCE_MONITOR_LOG="$UOWRT_RESOURCE_MONITOR_DIR/events.log"
UOWRT_AI_RES="$ROOT/resources/ai"
UOWRT_AI_DIR="$TMP/ai"
UOWRT_AI_STATE="$TMP/ai/state.tsv"
UOWRT_AI_PRESETS="$TMP/ai/presets"
UOWRT_AI_LOG="$TMP/ai/diagnostics.tsv"
. "$AI"
. "$MOD"
resource_monitor_init
grep -q '^service[[:space:]]' "$UOWRT_RESOURCE_MONITOR_STATE"
resource_monitor_set openai PASS healthy none baseline
resource_monitor_set youtube DPI_BLOCK blocked dpi failed
test "$(resource_monitor_healthy)" = openai
test "$(resource_monitor_failed)" = youtube
# Healthy resources are never emitted by the recovery queue.
! resource_monitor_failed | grep -q '^openai$'
# The monitor must not contain a second independent mutation lock.
! grep -qE 'strategy_apply|adaptive_apply|mkdir .*lock' "$MOD"
printf 'resource_monitor: OK\n'
