#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP="$ROOT/luci-app-universal-openwrt"
BIN_SRC="$ROOT/src/universal-openwrt"
[ "$(id -u)" = 0 ] || { echo 'root required'; exit 1; }
[ -f "$BIN_SRC" ] || { echo 'backend missing'; exit 1; }
mkdir -p /usr/bin /etc/init.d /usr/share/luci/menu.d /usr/share/rpcd/acl.d /usr/share/rpcd/ucode /www/luci-static/resources/view/universal-openwrt
cp -f "$BIN_SRC" /usr/sbin/universal-openwrt; chmod 0755 /usr/sbin/universal-openwrt
cp -f "$ROOT/root/etc/init.d/universal-openwrt-vpn-monitor" /etc/init.d/universal-openwrt-vpn-monitor; chmod 0755 /etc/init.d/universal-openwrt-vpn-monitor
cp -f "$APP/root/usr/share/luci/menu.d/luci-app-universal-openwrt.json" /usr/share/luci/menu.d/
cp -f "$APP/root/usr/share/rpcd/acl.d/luci-app-universal-openwrt.json" /usr/share/rpcd/acl.d/
cp -f "$APP/root/usr/share/rpcd/ucode/luci.universal_openwrt" /usr/share/rpcd/ucode/; chmod 0755 /usr/share/rpcd/ucode/luci.universal_openwrt
cp -f "$APP/htdocs/luci-static/resources/view/universal-openwrt/overview.js" /www/luci-static/resources/view/universal-openwrt/
/etc/init.d/rpcd reload 2>/dev/null || true
rm -rf /tmp/luci-* 2>/dev/null || true
echo 'Universal OpenWrt LuCI installed. Re-login to LuCI and open Services -> Universal OpenWrt.'
