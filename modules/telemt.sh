#!/bin/sh
# Optional Telegram MTProto backend: Telemt (Rust + Tokio).
# It is Telegram-only and never participates in the generic strategy engine.
TELEMT_CONF=${TELEMT_CONF:-/etc/universal-openwrt/telemt.conf}
TELEMT_CFG=${TELEMT_CFG:-/etc/telemt/telemt.toml}
TELEMT_BIN=${TELEMT_BIN:-/usr/bin/telemt}
TELEMT_PID=${TELEMT_PID:-/var/run/universal-openwrt-telemt.pid}
TELEMT_LOG=${TELEMT_LOG:-/var/log/universal-openwrt-telemt.log}
TELEMT_REPO='telemt/telemt'
TELEMT_PORT_DEFAULT=2443
TELEMT_LOCK=${TELEMT_LOCK:-/var/run/universal-openwrt-telegram-backend.lock.d}

telemt_init(){
  mkdir -p "$(dirname "$TELEMT_CONF")" "$(dirname "$TELEMT_PID")" "$(dirname "$TELEMT_LOG")" "$(dirname "$TELEMT_CFG")" 2>/dev/null || return 1
  [ -f "$TELEMT_CONF" ] || cat >"$TELEMT_CONF" <<'EOL'
enabled=0
port=2443
secret=
tls_domain=
public_host=
EOL
}
telemt_load(){ telemt_init || return 1; enabled=0; port=2443; secret=''; tls_domain=''; public_host=''; . "$TELEMT_CONF" 2>/dev/null || true; TELEMT_ENABLED="$enabled"; TELEMT_PORT="$port"; TELEMT_SECRET="$secret"; TELEMT_TLS_DOMAIN="$tls_domain"; TELEMT_PUBLIC_HOST="$public_host"; }
telemt_arch_asset(){
  A=''; command -v apk >/dev/null 2>&1 && A="$(apk --print-arch 2>/dev/null|head -n1)"; [ -n "$A" ] || A="$(uname -m 2>/dev/null)"
  case "$A" in aarch64|aarch64_cortex-a53|arm64) echo telemt-aarch64-linux-musl.tar.gz;; x86_64|x86-64) echo telemt-x86_64-linux-musl.tar.gz;; *) return 1;; esac
}
telemt_installed(){ [ -x "$TELEMT_BIN" ]; }
telemt_process_running(){ [ -f "$TELEMT_PID" ] && P="$(cat "$TELEMT_PID" 2>/dev/null)" && case "$P" in ''|*[!0-9]*) return 1;; esac && kill -0 "$P" 2>/dev/null; }
telemt_configured(){ telemt_load; [ -n "$TELEMT_SECRET" ] && [ -n "$TELEMT_TLS_DOMAIN" ] && telemt_installed; }
telemt_status(){ telemt_load; HOST="$TELEMT_PUBLIC_HOST"; [ -n "$HOST" ] || HOST="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"; LINK=''; LINK_SCOPE=''; if [ -n "$HOST" ] && [ -n "$TELEMT_SECRET" ]; then LINK="tg://proxy?server=$HOST&port=$TELEMT_PORT&secret=$TELEMT_SECRET"; [ -n "$TELEMT_PUBLIC_HOST" ] && LINK_SCOPE=public || LINK_SCOPE=lan; fi; printf 'enabled=%s\ninstalled=%s\nport=%s\nsecret=%s\ntls_domain=%s\npublic_host=%s\nrunning=%s\nbackend=rust-telemt\nlink_scope=%s\ntg_link=%s\n' "$TELEMT_ENABLED" "$(telemt_installed && echo yes || echo no)" "$TELEMT_PORT" "$TELEMT_SECRET" "$TELEMT_TLS_DOMAIN" "$TELEMT_PUBLIC_HOST" "$(telemt_process_running && echo yes || echo no)" "$LINK_SCOPE" "$LINK"; }
telemt_random_secret(){ if command -v openssl >/dev/null 2>&1; then openssl rand -hex 16 2>/dev/null; return; fi; od -An -N16 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n'; }
telemt_install(){
  telemt_init || return 1; ASSET="$(telemt_arch_asset)" || { echo 'Telemt: unsupported architecture (official release currently exposes musl aarch64/x86_64 assets)'; return 2; }
  command -v sha256sum >/dev/null 2>&1 || { echo 'Telemt: sha256sum required'; return 1; }
  API=/tmp/uowrt-telemt-api.$$; TMP=/tmp/uowrt-telemt.$$; trap 'rm -f "$API" "$TMP" "$TMP.sha" "$TMP.tar"' 0 1 2 3 15
  if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 10 --max-time 30 "https://api.github.com/repos/$TELEMT_REPO/releases/latest" -o "$API" || return 1
  elif command -v wget >/dev/null 2>&1; then wget -q -T 20 -O "$API" "https://api.github.com/repos/$TELEMT_REPO/releases/latest" || return 1
  else echo 'Telemt: no download utility'; return 127; fi
  TAG="$(sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' "$API"|head -n1)"; [ -n "$TAG" ] || return 1
  SHA="$(grep -A 8 -F '"name": "'"$ASSET"'"' "$API"|sed -n 's/.*"digest": "sha256:\([0-9a-fA-F]*\)".*/\1/p'|head -n1)"; [ -n "$SHA" ] || { echo 'Telemt: release asset has no SHA256 digest'; return 1; }
  URL="https://github.com/$TELEMT_REPO/releases/download/$TAG/$ASSET"; echo "Downloading Telemt $TAG ($ASSET)"
  if command -v curl >/dev/null 2>&1; then curl -fL --connect-timeout 15 --max-time 240 "$URL" -o "$TMP.tar" || return 1; else wget -q -T 30 -O "$TMP.tar" "$URL" || return 1; fi
  ACT="$(sha256sum "$TMP.tar"|awk '{print $1}')"; [ "$ACT" = "$SHA" ] || { echo "Telemt SHA256 mismatch: $ACT"; return 1; }
  tar -xzf "$TMP.tar" -C /tmp || return 1; [ -x /tmp/telemt ] || { echo 'Telemt archive does not contain /tmp/telemt'; return 1; }; /tmp/telemt --help >/dev/null 2>&1 || true; telemt_stop >/dev/null 2>&1 || true; mv /tmp/telemt "$TELEMT_BIN"; chmod 755 "$TELEMT_BIN"; echo "Telemt installed: $TELEMT_BIN ($TAG)";
}
telemt_write_config(){
  telemt_load; [ -n "$TELEMT_SECRET" ] && [ -n "$TELEMT_TLS_DOMAIN" ] || return 1
  mkdir -p "$(dirname "$TELEMT_CFG")"; umask 077
  cat >"$TELEMT_CFG" <<EOL
[general]
use_middle_proxy = true
log_level = "normal"
[general.modes]
classic = false
secure = false
tls = true
[general.links]
show = "*"
$([ -n "$TELEMT_PUBLIC_HOST" ] && printf 'public_host = "%s"\n' "$TELEMT_PUBLIC_HOST" || true)
public_port = $TELEMT_PORT
[server]
port = $TELEMT_PORT
[[server.listeners]]
ip = "0.0.0.0"
[censorship]
tls_domain = "$TELEMT_TLS_DOMAIN"
mask = true
tls_emulation = true
[access.users]
openwrt = "$TELEMT_SECRET"
EOL
  chmod 600 "$TELEMT_CFG"
}
telemt_port_free(){ command -v ss >/dev/null 2>&1 && ! ss -ltn 2>/dev/null|awk -v p=":$TELEMT_PORT" '$4~p"$"{f=1}END{exit(f?0:1)}'; }
telemt_start(){
  telemt_load; [ "$TELEMT_ENABLED" = 1 ] || { echo 'Telemt is disabled'; return 2; }; telemt_installed || { echo 'Telemt is not installed'; return 2; }; telemt_write_config || { echo 'Telemt config is incomplete: set secret and tls_domain'; return 2; }; telemt_port_free || { echo "Telemt port $TELEMT_PORT is already in use"; return 2; }
  telemt_stop
  if [ -f /etc/universal-openwrt/telegram-controller.conf ] && grep -q '^enabled=1$' /etc/universal-openwrt/telegram-controller.conf; then
    nohup "$TELEMT_BIN" "$TELEMT_CFG" >>"$TELEMT_LOG" 2>&1 & echo $! >"$TELEMT_PID"
  elif [ -x /etc/init.d/universal-openwrt-telemt ]; then
    /etc/init.d/universal-openwrt-telemt enable >/dev/null 2>&1 || true
    /etc/init.d/universal-openwrt-telemt restart >/dev/null 2>&1
  else
    nohup "$TELEMT_BIN" "$TELEMT_CFG" >>"$TELEMT_LOG" 2>&1 & echo $! >"$TELEMT_PID"
  fi
  sleep 1; telemt_process_running || { echo 'Telemt failed to start'; return 1; }; echo "Telemt MTProto started on $TELEMT_PORT";
}
telemt_stop(){ [ -f "$TELEMT_PID" ] && P="$(cat "$TELEMT_PID" 2>/dev/null)" && kill "$P" 2>/dev/null || true; rm -f "$TELEMT_PID"; [ -x /etc/init.d/universal-openwrt-telemt ] && /etc/init.d/universal-openwrt-telemt stop >/dev/null 2>&1 || true; }
telemt_enable(){ telemt_load; [ -n "$TELEMT_SECRET" ] || { TELEMT_SECRET="$(telemt_random_secret)"; sed -i "s/^secret=.*/secret=$TELEMT_SECRET/" "$TELEMT_CONF"; }; [ -n "$TELEMT_TLS_DOMAIN" ] || { echo 'Set tls_domain first'; return 2; }; sed -i 's/^enabled=.*/enabled=1/' "$TELEMT_CONF"; telemt_start; }
telemt_disable(){ [ -f "$TELEMT_CONF" ] && sed -i 's/^enabled=.*/enabled=0/' "$TELEMT_CONF" || true; [ -x /etc/init.d/universal-openwrt-telemt ] && /etc/init.d/universal-openwrt-telemt disable >/dev/null 2>&1 || true; telemt_stop; }
