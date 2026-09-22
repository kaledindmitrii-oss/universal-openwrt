#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SRC="$ROOT/src/universal-openwrt"
INST="$ROOT/installer/install.sh"
# Runtime and installer must only encode the two supported OpenWrt generations.
grep -q '24\.10.\*' "$SRC"
grep -Eq '25\.12\.\*' "$SRC"
grep -q '24\.10.2+' "$INST"
grep -Eq '25\.12\.\*' "$INST"
! grep -Eq 'fw3|18\.06|19\.07|21\.02|22\.03|23\.05' "$SRC"
! grep -Eq 'fw3' "$INST"
# fw4/nftables are hard requirements.
grep -q 'fw4' "$SRC"
grep -q 'nft' "$SRC"
grep -q "VERSION='$(cat "$ROOT/VERSION")'" "$SRC"
# Runtime must reject pre-24.10.2 releases and accept 24.10.2+.
printf 'platform_scope: OK\n'
