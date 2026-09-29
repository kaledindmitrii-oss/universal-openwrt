#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/modules/ai-access-engine.sh"
RES="$ROOT/resources/ai"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
UOWRT_AI_RES="$RES"
UOWRT_AI_DIR="$TMP/state"
UOWRT_AI_STATE="$UOWRT_AI_DIR/state.tsv"
UOWRT_AI_PRESETS="$TMP/presets"
UOWRT_AI_LOG="$UOWRT_AI_DIR/diagnostics.tsv"
. "$MOD"
ai_init
test "$(ai_service_label openai)" = 'OpenAI / ChatGPT'
test "$(ai_service_label youtube)" = 'YouTube'
test "$(ai_service_label instagram)" = 'Instagram'
test "$(ai_service_label x)" = 'X / Twitter'
test "$(ai_strategy_candidates youtube DPI_BLOCK | head -n1)" = dpi
test "$(ai_strategy_candidates youtube QUIC_BLOCK | head -n1)" = dpi
test "$(ai_strategy_candidates instagram IP_BLOCK_OR_GEO | head -n1)" = proxy
test "$(ai_strategy_candidates openai DNS_BLOCK | head -n1)" = dns
test "$(ai_service_row anthropic | cut -f1)" = anthropic
awk -F '\t' '$0 !~ /^#/ {if(NF<8) exit 1}' "$RES/services.tsv"
awk -F '\t' '$0 !~ /^#/ {if(NF<7) exit 1}' "$RES/strategy-catalog.tsv"
awk -F '\t' '$0 !~ /^#/ {if(NF<7) exit 1}' "$RES/presets/registry.tsv"
# All reserve sources must be HTTPS GitHub references; no executable shell fragments are vendored.
awk -F '\t' '$0 !~ /^#/ {if($4 !~ /^https:\/\/(github\.com|raw\.githubusercontent\.com)\//) exit 1}' "$RES/presets/registry.tsv"
case "$RES" in *iptv*|*rostelecom*) echo 'forbidden project coupling'; exit 1;; esac
printf 'ai_access_engine: OK\n'
