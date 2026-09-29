#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
AWG="$ROOT/modules/awg-warp.sh"
SRC="$ROOT/src/universal-openwrt"
sh -n "$AWG"
# TLS verification must never be disabled for GitHub/package retrieval.
! grep -Fq -- '--no-check-certificate' "$AWG"
# Device-specific package selection must include the full target tuple for all three packages.
grep -Fq 'REPO="${UOWRT_AWG_REPO:-2Grey/awg-openwrt}"' "$AWG"
grep -Fq '24.10.8' "$AWG"
grep -Fq 'amneziawg-tools_v${OWVER}_${ARCH}_${TARGET#*/}_${SUBTARGET}' "$AWG"
grep -Fq 'kmod-amneziawg_.*_${ARCH}_${TARGET#*/}_${SUBTARGET}' "$AWG"
grep -Fq 'luci-proto-amneziawg_v${OWVER}_${ARCH}_${TARGET#*/}_${SUBTARGET}' "$AWG"
# Release assets are hash-verified before installation.
grep -Fq 'asset_digest "$name"' "$AWG"
grep -Fq 'sha256sum "$file"' "$AWG"
# Actual provider configs and Cloudflare WARP are distinct capabilities.
grep -Fq -- '--mode auto|warp|provider' "$AWG"
grep -Fq "TUNNEL_KIND='amneziawg-obfuscated'" "$AWG"
grep -Fq "TUNNEL_KIND='wireguard-compatible'" "$AWG"
# Provider AWG parameters are preserved into UCI.
for p in awg_jc awg_jmin awg_jmax awg_s1 awg_s2 awg_h1 awg_h2 awg_h3 awg_h4 awg_s3 awg_s4 awg_i1 awg_i2 awg_i3 awg_i4 awg_i5 awg_header_protection_key awg_content_padding_addition awg_rekey_after_time awg_rekey_timeout awg_reject_after_time awg_keepalive_timeout awg_max_handshake_attempts awg_random_trailers awg_disable_cookies; do grep -Fq "network.\$IFACE.\$p" "$AWG" 2>/dev/null || grep -Fq "network.\$IFACE.$p" "$AWG"; done
# Full-tunnel routing must target the selected AWG peer only.
grep -Fq 'amneziawg_${IFACE}' "$SRC"
grep -Fq 'route_allowed_ips=1' "$SRC"
# There is no fake split-routing claim: the automatic split strategy is rejected until
# an owned policy-routing classifier exists.
grep -Fq 'AWG split strategy is unavailable: no owned policy-routing classifier' "$SRC"
# A real client-VPN firewall zone is created; the previous no-op must stay gone.
grep -Fq 'firewall_setup(){' "$AWG"
grep -Fq 'masq=1' "$AWG"
grep -Fq 'FORWARD="${LAN_ZONE}_to_uowrt_awg"' "$AWG"
printf '%s\n' 'awg_deep: OK'
