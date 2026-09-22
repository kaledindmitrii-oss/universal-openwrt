#!/bin/sh
set -eu
# Run on a real OpenWrt router after package installation.
# Only read-only/status RPC methods are exercised; no tunnel/DNS/firewall mutation.
if ! command -v ubus >/dev/null 2>&1; then echo "rpc_smoke: SKIP (not an OpenWrt runtime)"; exit 0; fi
/usr/sbin/universal-openwrt --rpc-smoke
