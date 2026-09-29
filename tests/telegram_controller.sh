#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d /tmp/uowrt-tgctl.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
export TGCTL_CONF="$tmp/conf"
export TGCTL_STATE="$tmp/state"
export TGCTL_LOG="$tmp/log"
export TGCTL_LOCK="$tmp/lock.d"
export TGCTL_PORT_DEFAULT=1080
# Minimal stubs for isolated controller test.
tggo_running(){ return 1; }
tgws_configured(){ return 1; }
tgws_running(){ return 1; }
tg_failover_runtime_socks(){ return 1; }
tggo_enable(){ return 1; }
tggo_disable(){ return 0; }
tggo_stop(){ return 0; }
tgws_enable(){ return 1; }
tgws_disable(){ return 0; }
. "$ROOT/modules/telegram-controller.sh"
telegram_controller_init
telegram_controller_load
grep -q '^enabled=0$' "$TGCTL_CONF"
grep -q '^port=1080$' "$TGCTL_CONF"
telegram_controller_config 1 auto 1080 15 2 >/dev/null
grep -q '^enabled=1$' "$TGCTL_CONF"
grep -q '^mode=auto$' "$TGCTL_CONF"
status="$(telegram_controller_status)"
printf '%s\n' "$status" | grep -q '^port=1080$'
printf '%s\n' "$status" | grep -q '^enabled=1$'
# No Telegram controller operation is allowed to call generic strategy functions.
! grep -qE 'adaptive_controller_run|ai_apply|strategy_apply' "$ROOT/modules/telegram-controller.sh"
printf '%s\n' 'telegram_controller: OK'
# Explicit mode branches must exist and remain Telegram-local.
grep -q 'socks5)' "$ROOT/modules/telegram-controller.sh"
grep -q 'ws)' "$ROOT/modules/telegram-controller.sh"
grep -q 'telemt)' "$ROOT/modules/telegram-controller.sh"
grep -q 'forced_telemt' "$ROOT/modules/telegram-controller.sh"
! grep -qE 'strategy_apply|adaptive_controller_run|ai_apply' "$ROOT/modules/telegram-controller.sh"
