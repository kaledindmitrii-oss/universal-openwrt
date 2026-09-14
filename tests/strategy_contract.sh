#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src/universal-openwrt"
SE="$ROOT/modules/strategy-engine.sh"
TG="$ROOT/modules/tg-socks5-go.sh"
for f in "$SRC" "$SE" "$TG"; do sh -n "$f"; done
for s in core dns dpi dpi-youtube-auto dpi-discord dpi-game awg-split awg-full podkop proxy tg-socks5 tg-ws vless-tproxy; do
  grep -E -q "(^|\||[[:space:]])${s}(\)|\||[[:space:]])" "$SRC" || { echo "missing strategy mapping: $s"; exit 1; }
done
grep -Fq 'telegram) if tggo_running' "$SRC"
grep -Fq "tg-socks5 tg-ws core" "$SRC"
grep -Fq 'strategy_apply' "$SRC"
grep -Fq 'tg_failover_active(){ if tggo_running' "$SRC"
printf 'strategy_contract: OK\n'
