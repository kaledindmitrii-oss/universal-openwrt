#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src/universal-openwrt"
UI="$ROOT/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
sh -n "$SRC"
node --check "$UI"
# No direct recursive self-check invocation.
python - "$SRC" <<'PY'
import sys
s=open(sys.argv[1]).read()
start=s.index('modules_self_check(){')
end=s.find('\n}', start)
assert end != -1
body=s[start:end]
assert 'modules_self_check' not in body.replace('modules_self_check(){','',1)
PY
COUNT="$(grep -c "btn('" "$UI")"
[ "$COUNT" -le 32 ]
# Main dashboard keeps a small set of obvious actions; advanced actions stay inside details.
for label in 'Проверить' 'Автонастройка' 'Обновить' 'Начать диагностику'; do
  grep -Fq "'$label'" "$UI"
done
# Strategy mutations are serialized and failures are propagated.
grep -q "STRATEGY_CHANGE_LOCK='/var/run/universal-openwrt-strategy-change.lock'" "$SRC"
grep -q 'strategy_change_unlock' "$SRC"
grep -q '\[ "\$_dns_ok" -eq 1 \] || _strategy_rc=1' "$SRC"
# Learned per-resource policy can override static class preference.
grep -q 'strategy_for_resource(){' "$SRC"
grep -q 'P="$(awk -F' "$SRC"
printf 'interface_strategy_regression: OK\n'
