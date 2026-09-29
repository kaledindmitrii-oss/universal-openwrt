#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src/universal-openwrt"
sh -n "$SRC" "$ROOT/modules/source-resolver.sh" "$ROOT/modules/strategy-engine.sh" "$ROOT/modules/tg-socks5-go.sh"
grep -Fq 'KERNEL_ABI=' "$SRC"
grep -Fq 'KernelABI=' "$SRC"
grep -Fq 'vpn_health(){' "$SRC"
grep -Fq 'TG SOCKS5 release has no SHA256 digest' "$ROOT/modules/tg-socks5-go.sh"
grep -Fq 'UOWRT_GITHUB_MIRROR_PREFIX' "$ROOT/modules/source-resolver.sh"
grep -Fq 'TELEMT_REPO' "$ROOT/modules/telemt.sh"
grep -Fq 'telemt-aarch64-linux-musl.tar.gz' "$ROOT/modules/telemt.sh"
grep -Fq 'telegram_backends_status' "$ROOT/src/universal-openwrt"
grep -Fq 'controller_guard' "$ROOT/packaging/root/etc/init.d/universal-openwrt-tg-socks5-go"
! find "$ROOT/packaging/root/usr/lib/universal-openwrt" -type f 2>/dev/null | grep -q .
grep -Fq 'se_group_can_apply' "$ROOT/modules/strategy-engine.sh"
grep -Fq 'strategy_group_status' "$SRC"
# Regression: VPN profile records must use real newlines, not literal \n.
! grep -Fq "printf '%s|%s|%s|%s\\n'" "$SRC"
# Global strategies may not silently replace another group's global owner.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export UOWRT_GROUP_DIR="$tmp/groups"; export UOWRT_GROUP_STATE="$tmp/groups/state.tsv"
. "$ROOT/modules/strategy-engine.sh"
se_group_init
se_group_set youtube dpi active
if se_group_can_apply ai awg-full >/dev/null 2>&1; then echo 'global group conflict was not blocked'; exit 1; fi
se_group_set telegram tg-socks5 active
test "$(awk -F '\t' '$1=="telegram"{print $3}' "$UOWRT_GROUP_STATE")" = dedicated
grep -Fq 'openTelegramSettings' "$ROOT/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
grep -Fq 'telegramDetails' "$ROOT/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
! grep -Fq 'при наличии qrencode' "$ROOT/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
printf '%s\n' 'architecture_deep: OK'
