#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d /tmp/uowrt-tgtest.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
export TGGO_CONF="$tmp/conf"
export TGGO_PID="$tmp/pid"
export TGGO_LOG="$tmp/log"
export TGGO_BIN="$tmp/tg-ws-proxy-go"
. "$ROOT/modules/tg-socks5-go.sh"
tggo_status | grep -q 'enabled=0'
tggo_status | grep -q 'installed=no'
# Fake binary and config: installed/configured state must be deterministic.
cat > "$TGGO_BIN" <<'EOT'
#!/bin/sh
exit 0
EOT
chmod 755 "$TGGO_BIN"
cat > "$TGGO_CONF" <<'EOT'
enabled=1
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
EOT
tggo_configured
! tggo_running
tggo_status | grep -q 'installed=yes'
tggo_status | grep -q 'configured=yes'
tggo_status | grep -q 'running=no'
# Strategy engine must prefer tg-socks5 before tg-ws.
printf '%s\n' > "$tmp/strategy.conf" "."
. "$ROOT/modules/strategy-engine.sh"
out="$(se_choose telegram)"
test "$(printf '%s' "$out" | cut -f1)" = tg-socks5
test "$(printf '%s' "$out" | cut -f2)" = tg-ws
printf 'tg_strategy: OK\n'
