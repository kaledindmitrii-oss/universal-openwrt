#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SRC="$ROOT/src/universal-openwrt"
MOD="$ROOT/modules/automation.sh"
INIT="$ROOT/packaging/root/etc/init.d/universal-openwrt-automation"
RPC="$ROOT/luci-app-universal-openwrt/root/usr/share/rpcd/ucode/luci.universal_openwrt"
ACL="$ROOT/luci-app-universal-openwrt/root/usr/share/rpcd/acl.d/luci-app-universal-openwrt.json"
for f in "$SRC" "$MOD" "$INIT" "$RPC" "$ACL"; do test -s "$f" || { echo "missing: $f"; exit 1; }; done
head -n1 "$SRC" | grep -Fxq '#!/bin/sh'
head -n1 "$MOD" | grep -Fxq '#!/bin/sh'
head -n1 "$INIT" | grep -Fxq '#!/bin/sh /etc/rc.common'
sh -n "$SRC"
sh -n "$MOD"
sh -n "$INIT"
grep -Fq 'UOWRT_AUTOMATION_INTERVALS=' "$MOD"
grep -Fq 'enabled=0' "$MOD"
grep -Fq 'automation_build_cron' "$MOD"
grep -Fq 'interval_hours' "$MOD"
grep -Fq -- '--automation-run' "$SRC"
grep -Fq -- '--automation-enable' "$SRC"
grep -Fq -- '--automation-disable' "$SRC"
for method in automation_status automation_enable automation_disable automation_config automation_run; do
  grep -Fq "$method" "$RPC" || { echo "missing RPC: $method"; exit 1; }
  grep -Fq "$method" "$ACL" || { echo "missing ACL: $method"; exit 1; }
done
grep -Fq 'Автоматический подбор стратегии' "$ROOT/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
grep -Fq "type:'time'" "$ROOT/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
grep -Fq 'Периодичность' "$ROOT/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
grep -Fq 'automation_config' "$ROOT/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
grep -Fq 'automation-toggle' "$ROOT/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
printf '%s\n' 'automation: OK'
