#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
M="$ROOT/modules/wireguard-remote.sh"
S="$ROOT/src/universal-openwrt"
SE="$ROOT/modules/strategy-engine.sh"
[ -f "$M" ]
grep -Fq 'WG_REMOTE_IFACE="${UOWRT_REMOTE_WG_IFACE:-wg0}"' "$M"
grep -Fq 'WG_REMOTE_PORT="${UOWRT_REMOTE_WG_PORT:-51820}"' "$M"
grep -Fq 'WG_REMOTE_ADDR="${UOWRT_REMOTE_WG_ADDR:-10.66.66.1/24}"' "$M"
grep -Fq 'route_allowed_ips=never-managed' "$M"
grep -Fq 'strategy_integration=none' "$M"
grep -Fq 'uci set "firewall.$z.masq=0"' "$M"
grep -Fq 'mode_remote=Remote WireGuard' "$M"
grep -Fq 'mode_vpn=WireGuard VPN' "$M"
grep -Fq 'white_ip=' "$M"
grep -Fq 'count_vpn_devices' "$M"
# Remote WG must not be a Universal OpenWrt strategy/backend.
! grep -Eiq 'wireguard-remote|uowrt_remote_wg|wg0' "$S" "$SE"
# Device manager supports two explicit per-device modes; VPN routing is opt-in and isolated.
grep -Fq 'add <name>' "$M"
grep -Fq 'set-mode' "$M"
grep -Fq 'show|config)' "$M"
grep -Fq 'qr)' "$M"
grep -Fq 'revoke)' "$M"
grep -Fq 'regenerate)' "$M"
grep -Fq 'state=online' "$M"
grep -Fq 'latest-handshakes' "$M"
grep -Fq 'qrencode' "$M"
grep -Fq 'remote_endpoint_resolve' "$M"
grep -Fq 'route_allowed_ips=0' "$M"
grep -Fq 'AllowedIPs = 10.66.66.0/24' "$M"
grep -Fq 'DEPENDS:=+luci +luci-base +rpcd +rpcd-mod-ucode +ucode +qrencode' "$ROOT/luci-app-universal-openwrt/Makefile"
grep -Fq '"qrencode"' "$ROOT/tools/build-assets.py"
grep -Fq '0.0.0.0/0' "$M"
! grep -Fq '::/0' "$M"
# Existing AWG/WARP routing code remains untouched.
grep -Fq 'awg-full' "$S"
grep -Fq 'UOWRT:AWG' "$SE"
for f in "$ROOT"/modules/*.sh "$ROOT"/tests/*.sh; do sh -n "$f"; done
printf 'wireguard_remote_isolation: OK\n'
