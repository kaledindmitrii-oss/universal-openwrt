#!/bin/sh
# Universal OpenWrt Strategy Engine. Owns decisions; individual backends own rules.

UOWRT_STRATEGY_DIR='/etc/universal-openwrt/strategy'
UOWRT_STRATEGY_STATE="$UOWRT_STRATEGY_DIR/state.tsv"
UOWRT_STRATEGY_OWNERS="$UOWRT_STRATEGY_DIR/owners.tsv"

se_init(){
  mkdir -p "$UOWRT_STRATEGY_DIR" 2>/dev/null || return 1
  [ -f "$UOWRT_STRATEGY_STATE" ] || printf 'resource\tclass\tstrategy\tfallback\tconfidence\tupdated\n' > "$UOWRT_STRATEGY_STATE"
  [ -f "$UOWRT_STRATEGY_OWNERS" ] || printf 'owner\tbackend\tactive\tupdated\n' > "$UOWRT_STRATEGY_OWNERS"
}
se_set_owner(){ O="$1"; B="$2"; A="$3"; se_init || return 1; awk -F '\t' -v o="$O" '$1!=o' "$UOWRT_STRATEGY_OWNERS" > "$UOWRT_STRATEGY_OWNERS.tmp"; printf '%s\t%s\t%s\t%s\n' "$O" "$B" "$A" "$(date +%s)" >> "$UOWRT_STRATEGY_OWNERS.tmp"; mv "$UOWRT_STRATEGY_OWNERS.tmp" "$UOWRT_STRATEGY_OWNERS"; }
se_clear_owner(){ O="$1"; se_init || return 1; awk -F '\t' -v o="$O" '$1!=o' "$UOWRT_STRATEGY_OWNERS" > "$UOWRT_STRATEGY_OWNERS.tmp"; mv "$UOWRT_STRATEGY_OWNERS.tmp" "$UOWRT_STRATEGY_OWNERS"; }
se_record(){ R="$1"; C="$2"; S="$3"; F="$4"; CONF="$5"; se_init || return 1; awk -F '\t' -v r="$R" '$1!=r' "$UOWRT_STRATEGY_STATE" > "$UOWRT_STRATEGY_STATE.tmp"; printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$R" "$C" "$S" "$F" "$CONF" "$(date +%s)" >> "$UOWRT_STRATEGY_STATE.tmp"; mv "$UOWRT_STRATEGY_STATE.tmp" "$UOWRT_STRATEGY_STATE"; }
se_choose(){
  CLASS="$1"; case "$CLASS" in
    telegram) printf 'tg-socks5\ttg-ws\tcore\n';;
    video|social-video) printf 'dpi-youtube-auto\tdpi\tvless-tproxy\tawg-split\n';;
    discord|gaming) printf 'dpi\tvless-tproxy\tawg-split\n';;
    ai|developer|streaming|news) printf 'awg-split\tvless-tproxy\tdpi\n';;
    *) printf 'core\tdoh-unpoison\tdpi\tawg-split\tvless-tproxy\n';;
  esac
}
se_plan(){
  se_init || return 1; resource_matrix_init 2>/dev/null || true
  printf 'resource-class\tpreferred\tfallbacks\n'
  for C in critical telegram video discord gaming social ai developer streaming news; do printf '%s\t%s\t%s\n' "$C" "$(se_choose "$C" | head -n1 | cut -f1)" "$(se_choose "$C" | cut -f1 | tail -n +2 | tr '\n' ',')"; done
}
se_status(){ se_init || return 1; OWNERS=$(awk 'NR>1{n++}END{print n+0}' "$UOWRT_STRATEGY_OWNERS" 2>/dev/null); STATE=$(awk 'NR>1{n++}END{print n+0}' "$UOWRT_STRATEGY_STATE" 2>/dev/null); [ -n "$OWNERS" ] || OWNERS=0; [ -n "$STATE" ] || STATE=0; STATUS=idle; [ "$OWNERS" -gt 0 ] || [ "$STATE" -gt 0 ] && STATUS=active; echo 'Strategy Engine'; echo "status=$STATUS"; echo "owners=$OWNERS"; echo "state_entries=$STATE"; echo '--- owners ---'; cat "$UOWRT_STRATEGY_OWNERS"; echo '--- state ---'; tail -n 80 "$UOWRT_STRATEGY_STATE"; }
se_apply_core(){ se_set_owner UOWRT:DPI core 1; se_clear_owner UOWRT:VLESS; se_clear_owner UOWRT:AWG; se_clear_owner UOWRT:WARP; }
se_apply_vless(){ se_set_owner UOWRT:VLESS sing-box-vless 1; }
se_apply_awg(){ se_set_owner UOWRT:AWG amneziawg 1; se_clear_owner UOWRT:VLESS; }
se_apply_warp(){ se_set_owner UOWRT:WARP wireguard-warp 1; se_clear_owner UOWRT:VLESS; }
