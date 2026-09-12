#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
sh -n "$ROOT/src/universal-openwrt"
sh -n "$ROOT/installer/install.sh"
sh -n "$ROOT/install-luci.sh"
printf 'smoke: OK\n'
