#!/bin/sh
# Universal OpenWrt AI Access Engine.
UOWRT_LIB_DIR="${UOWRT_LIB_DIR:-/usr/lib/universal-openwrt}"
[ -f "$UOWRT_LIB_DIR/source-resolver.sh" ] && . "$UOWRT_LIB_DIR/source-resolver.sh" 2>/dev/null || true
# Diagnostic + guarded access layer. Mutating actions are explicit, transactional, service-tested, and rolled back on failure.

UOWRT_AI_DIR="${UOWRT_AI_DIR:-/etc/universal-openwrt/ai}"
UOWRT_AI_RES="${UOWRT_AI_RES:-/usr/lib/universal-openwrt/test-resources/ai}"
UOWRT_AI_STATE="${UOWRT_AI_STATE:-$UOWRT_AI_DIR/state.tsv}"
UOWRT_AI_PRESETS="${UOWRT_AI_PRESETS:-$UOWRT_AI_DIR/presets}"
UOWRT_AI_LOG="${UOWRT_AI_LOG:-$UOWRT_AI_DIR/diagnostics.tsv}"

ai_init(){
  mkdir -p "$UOWRT_AI_DIR" "$UOWRT_AI_PRESETS" 2>/dev/null || return 1
  [ -f "$UOWRT_AI_STATE" ] || printf 'service\tstatus\treason\tstrategy\tupdated\n' >"$UOWRT_AI_STATE"
  [ -f "$UOWRT_AI_LOG" ] || printf 'ts\tservice\tdomain\tstatus\treason\tcode\tipv4\tipv6\tms\n' >"$UOWRT_AI_LOG"
}
ai_have(){ command -v "$1" >/dev/null 2>&1; }
ai_catalog(){ [ -s "$UOWRT_AI_RES/services.tsv" ] && cat "$UOWRT_AI_RES/services.tsv" || return 1; }
ai_service_row(){ awk -F '\t' -v id="$1" '$0 !~ /^#/ && $1==id{print;exit}' "$UOWRT_AI_RES/services.tsv" 2>/dev/null; }
ai_domains(){
  R="$(ai_service_row "$1")"; [ -n "$R" ] || return 1
  printf '%s,%s,%s\n' "$(printf '%s' "$R"|cut -f3)" "$(printf '%s' "$R"|cut -f4)" "$(printf '%s' "$R"|cut -f5)" | tr ',' '\n' | awk 'NF{print}' | sort -u
}
ai_service_label(){ R="$(ai_service_row "$1")"; printf '%s\n' "$(printf '%s' "$R"|cut -f2)"; }
ai_curl(){
  URL="$1"; SHIFTED="$2"; OPT='--connect-timeout 5 --max-time 12 -sS -o /dev/null -w %{http_code}|%{time_total}'
  if [ "$SHIFTED" = 4 ]; then OPT="$OPT -4"; elif [ "$SHIFTED" = 6 ]; then OPT="$OPT -6"; fi
  if ai_have curl; then curl -L $OPT "$URL" 2>/dev/null || true; return 0; fi
  if ai_have wget; then if wget -q -T 10 --spider "$URL" >/dev/null 2>&1; then printf '200|0'; else printf '000|12'; fi; return 0; fi
  printf '000|99'
}
ai_dns(){
  D="$1"
  if ai_have nslookup; then nslookup "$D" 127.0.0.1 2>/dev/null | awk '/^Address: /{print $2}' | grep -v '^127\.0\.0\.1$' | head -n1; return 0; fi
  if ai_have getent; then getent ahosts "$D" 2>/dev/null | awk 'NR==1{print $1;exit}'; return 0; fi
  return 1
}
ai_classify(){
  CODE="$1"; V4="$2"; V6="$3"; DNSOK="$4"; HTTP3="$5"; GEO_SENSITIVE="${6:-0}"
  case "$CODE" in
    401|407) echo AUTH_BLOCK; return;;
    403) echo POLICY_OR_GEO; return;;
    404) echo SERVICE_DOWN_OR_ENDPOINT; return;;
    5??) echo SERVICE_DOWN; return;;
  esac
  [ "$DNSOK" = 1 ] && { echo DNS_BLOCK; return; }
  [ "$CODE" = 000 ] && [ "$V4" = 1 ] && [ "$V6" = 1 ] && [ "$HTTP3" = fail ] && { echo DPI_OR_QUIC_BLOCK; return; }
  [ "$CODE" = 000 ] && [ "$V4" = 0 ] && [ "$V6" = 0 ] && { echo IP_BLOCK_OR_GEO; return; }
  [ "$CODE" = 000 ] && { echo DPI_BLOCK; return; }
  echo PASS
}
ai_strategy_candidates(){
  ID="$1"; STATUS="$2"; CLASS="$(ai_service_row "$ID"|cut -f9)"
  case "$STATUS:$CLASS" in
    DNS_BLOCK:*) printf '%s\n' dns dpi awg-full proxy;;
    IP_BLOCK_OR_GEO:*|POLICY_OR_GEO:social) printf '%s\n' proxy awg-full awg-full dpi;;
    QUIC_BLOCK:video) printf '%s\n' dpi awg-full proxy;;
    QUIC_BLOCK:*) printf '%s\n' dpi awg-full awg-full proxy;;
    DPI_OR_QUIC_BLOCK:video) printf '%s\n' dpi awg-full proxy;;
    DPI_OR_QUIC_BLOCK:*) printf '%s\n' dpi awg-full awg-full proxy;;
    DPI_BLOCK:video) printf '%s\n' dpi awg-full proxy;;
    DPI_BLOCK:social) printf '%s\n' dpi awg-full awg-full proxy;;
    DPI_BLOCK:*) printf '%s\n' dpi awg-full awg-full proxy;;
    *) printf '%s\n' dpi awg-full awg-full proxy;;
  esac
}
ai_probe_domains(){
  ID="$1"; MAX="${2:-5}"; N=0; PASS=0; FAIL=0
  for D in $(ai_domains "$ID"); do
    N=$((N+1)); [ "$N" -gt "$MAX" ] && break
    R="$(ai_curl "https://$D/" 4)"; C="$(printf '%s' "$R"|cut -d'|' -f1)"
    if [ "$C" != 000 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
    printf 'probe.%s=%s|%s\n' "$D" "$C" "$(printf '%s' "$R"|cut -d'|' -f2)"
  done
  printf 'probe_summary=pass:%s fail:%s total:%s\n' "$PASS" "$FAIL" "$N"
}
ai_probe_service(){
  ID="$1"; R="$(ai_service_row "$ID")"; [ -n "$R" ] || { echo "unknown service: $ID" >&2; return 2; }
  DOMAIN="$(printf '%s' "$R"|cut -f3|cut -d, -f1)"; URL="https://$DOMAIN/"; GEO="$(printf '%s' "$R"|cut -f8)"
  DNS_IP="$(ai_dns "$DOMAIN" | head -n1)"; DNSOK=1; [ -n "$DNS_IP" ] && DNSOK=0
  V4R="$(ai_curl "$URL" 4)"; V4CODE="$(printf '%s' "$V4R"|cut -d'|' -f1)"; V4MS="$(printf '%s' "$V4R"|cut -d'|' -f2)"
  V6R="$(ai_curl "$URL" 6)"; V6CODE="$(printf '%s' "$V6R"|cut -d'|' -f1)"
  V4=1; V6=1; [ "$V4CODE" != 000 ] && V4=0; [ "$V6CODE" != 000 ] && V6=0
  HTTP3=skip
  if [ "$(printf '%s' "$R"|cut -f7)" = 1 ] && ai_have curl && curl --help all 2>/dev/null | grep -q -- '--http3'; then
    curl --http3 -fL -sS -o /dev/null --connect-timeout 5 --max-time 10 "$URL" >/dev/null 2>&1 && HTTP3=ok || HTTP3=fail
  fi
  CODE="$V4CODE"; [ "$CODE" = 000 ] && CODE="$V6CODE"
  STATUS="$(ai_classify "$CODE" "$V4" "$V6" "$DNSOK" "$HTTP3" "$GEO")"; [ "$STATUS" = PASS ] && [ "$HTTP3" = fail ] && STATUS=QUIC_BLOCK; STRATEGY=diagnose-service
  case "$STATUS" in
    PASS) STRATEGY=ai-direct;; DNS_BLOCK) STRATEGY=ai-dns;; QUIC_BLOCK) STRATEGY=ai-quic-fallback;; DPI_BLOCK|DPI_OR_QUIC_BLOCK) STRATEGY=ai-tcp-multidisorder;; IP_BLOCK_OR_GEO|POLICY_OR_GEO) STRATEGY=ai-selective-proxy;; AUTH_BLOCK) STRATEGY=direct-auth-check;; esac
  ai_init
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$ID" "$DOMAIN" "$STATUS" "$STATUS" "$CODE" "$V4" "$V6" "$V4MS" >>"$UOWRT_AI_LOG"
  awk -F '\t' -v s="$ID" '$1!=s' "$UOWRT_AI_STATE" >"$UOWRT_AI_STATE.tmp"
  printf '%s\t%s\t%s\t%s\t%s\n' "$ID" "$STATUS" "$STATUS" "$STRATEGY" "$(date +%s)" >>"$UOWRT_AI_STATE.tmp"; mv "$UOWRT_AI_STATE.tmp" "$UOWRT_AI_STATE"
  printf 'service=%s\nlabel=%s\nclass=%s\ndomain=%s\ndns=%s\nipv4=%s\nipv6=%s\nhttp3=%s\nhttp_code=%s\nlatency_ms=%s\nstatus=%s\nnext=%s\n--- endpoint matrix ---\n' "$ID" "$(ai_service_label "$ID")" "$(printf '%s' "$R"|cut -f9)" "$DOMAIN" "$DNS_IP" "$V4" "$V6" "$HTTP3" "$CODE" "$V4MS" "$STATUS" "$STRATEGY"
  ai_probe_domains "$ID" 5
  printf '%s\n' '--- priority ---'; N=0; while read -r C; do N=$((N+1)); printf '%s.%s\n' "$N" "$C"; done <<EOF
$(ai_strategy_candidates "$ID" "$STATUS")
EOF
  [ "$STATUS" = PASS ]
}
ai_candidate_available(){
  case "$1" in
    dns) module_preflight doh-unpoison >/dev/null 2>&1 || module_preflight malw-hosts >/dev/null 2>&1;;
    dpi) module_preflight dpi-desync >/dev/null 2>&1;;
    awg-full|awg-full) module_preflight awg-warp >/dev/null 2>&1;;
    proxy) module_preflight proxy >/dev/null 2>&1;;
    *) return 1;;
  esac
}
ai_apply(){
  ID="${1:-openai}"; [ -n "$(ai_service_row "$ID")" ] || { echo "unknown service: $ID" >&2; return 2; }
  BASE="$(ai_probe_service "$ID" 2>/dev/null || true)"; STATUS="$(printf '%s\n' "$BASE"|sed -n 's/^status=//p'|tail -1)"
  [ "$STATUS" = PASS ] && { echo 'AI-APPLY: service already healthy; no changes.'; return 0; }
  # AI application is a global mutation today. Serialize it with every other
  # automatic controller and use the independent adaptive snapshot, not the
  # shared LAST_MODULE slot which can be overwritten by strategy_apply().
  controller_lock 2>/dev/null || { echo 'AI-APPLY: another automatic controller is active; retry later.' >&2; return 3; }
  SNAP="ai-guard-$ID"
  adaptive_snapshot "$SNAP" >/dev/null 2>&1 || { controller_unlock; echo 'AI-APPLY: cannot create rollback snapshot.' >&2; return 1; }
  cleanup(){ adaptive_restore "$SNAP" >/dev/null 2>&1 || true; controller_unlock; }
  echo "AI-APPLY: service=$ID status=${STATUS:-UNKNOWN}"
  for CAND in $(ai_strategy_candidates "$ID" "${STATUS:-DPI_BLOCK}"); do
    echo "AI-APPLY: trying=$CAND"
    if ! ai_candidate_available "$CAND"; then echo "AI-APPLY: skip=$CAND (not available)"; continue; fi
    adaptive_restore "$SNAP" >/dev/null 2>&1 || true
    if command -v se_group_can_apply >/dev/null 2>&1 && ! se_group_can_apply ai "$CAND"; then
      echo "AI-APPLY: skip=$CAND (global strategy conflicts with another active group)"
      continue
    fi
    if strategy_apply "$CAND"; then
      sleep 1
      if command -v strategy_stage_verify >/dev/null 2>&1 && ! strategy_stage_verify "$CAND"; then
        echo "AI-APPLY: candidate=$CAND failed stage verification"
        adaptive_restore "$SNAP" >/dev/null 2>&1 || true
        continue
      fi
      command -v se_group_set >/dev/null 2>&1 && se_group_set ai "$CAND" active >/dev/null 2>&1 || true
      TEST="$(ai_probe_service "$ID" 2>/dev/null || true)"; TSTAT="$(printf '%s\n' "$TEST"|sed -n 's/^status=//p'|tail -1)"
      if [ "$TSTAT" = PASS ]; then
        echo "AI-APPLY: target=$ID passed with $CAND; checking protected services"
        # Do not accept a fix that breaks core or another protected service.
        GUARD_FAIL=0
        for G in openai anthropic gemini deepseek kimi perplexity mistral grok copilot youtube instagram x; do
          [ "$G" = "$ID" ] && continue
          GROW="$(ai_service_row "$G" 2>/dev/null || true)"; [ -n "$GROW" ] || continue
          GTEST="$(ai_probe_service "$G" 2>/dev/null || true)"
          GS="$(printf '%s\n' "$GTEST"|sed -n 's/^status=//p'|tail -1)"
          GB="$(ai_probe_service "$G" 2>/dev/null || true)"
          # Only enforce the guard for services that were healthy at baseline.
          # A service already blocked before the experiment is not a regression.
          case "$GS" in PASS) :;; *)
            # Re-test baseline after restoring the snapshot to distinguish an
            # existing failure from a candidate-induced regression.
            adaptive_restore "$SNAP" >/dev/null 2>&1 || true
            BTEST="$(ai_probe_service "$G" 2>/dev/null || true)"; BS="$(printf '%s\n' "$BTEST"|sed -n 's/^status=//p'|tail -1)"
            adaptive_apply "$CAND" >/dev/null 2>&1 || true
            [ "$BS" = PASS ] && { echo "AI-APPLY: guard regression: $G $BS -> $GS"; GUARD_FAIL=1; }
            ;; esac
          [ "$GUARD_FAIL" -eq 1 ] && break
        done
        if [ "$GUARD_FAIL" -eq 0 ]; then echo "AI-APPLY: SUCCESS strategy=$CAND"; controller_unlock; return 0; fi
      fi
      echo "AI-APPLY: candidate rejected; restoring baseline"
    else
      echo "AI-APPLY: strategy failed=$CAND; restoring baseline"
    fi
    adaptive_restore "$SNAP" >/dev/null 2>&1 || true
  done
  adaptive_restore "$SNAP" >/dev/null 2>&1 || true
  controller_unlock
  echo 'AI-APPLY: no candidate passed; previous working configuration preserved/rolled back.'; return 1
}
ai_diagnose(){
  ai_init; IDS="${1:-all}"
  if [ "$IDS" = all ]; then IDS="$(awk -F '\t' '$0 !~ /^#/ && NF>=1{print $1}' "$UOWRT_AI_RES/services.tsv" 2>/dev/null)"; fi
  for ID in $IDS; do echo "=== $ID ==="; ai_probe_service "$ID" || true; done
  echo '=== AI STATE ==='; cat "$UOWRT_AI_STATE"
}
ai_preset_status(){
  ai_init
  echo '=== AI PRESET REGISTRY ==='
  cat "$UOWRT_AI_RES/presets/registry.tsv" 2>/dev/null || true
  echo '=== LOCAL IMPORTS ==='
  find "$UOWRT_AI_PRESETS" -type f -maxdepth 1 -print 2>/dev/null | sort || true
}
ai_preset_fetch(){
  ID="$1"; ROW="$(awk -F '\t' -v id="$ID" '$0 !~ /^#/ && $1==id{print;exit}' "$UOWRT_AI_RES/presets/registry.tsv" 2>/dev/null)"; [ -n "$ROW" ] || { echo "unknown preset: $ID" >&2; return 2; }
  ENGINE="$(printf '%s' "$ROW"|cut -f2)"; URL="$(printf '%s' "$ROW"|cut -f4)"; NAME="$(printf '%s' "$ROW"|cut -f3 | tr ' /' '__')"
  case "$ENGINE" in zapret2|zapret1) :;; *) echo 'unsupported preset engine' >&2; return 2;; esac
  ai_init; OUT="$UOWRT_AI_PRESETS/${ID}.txt"
  case "$URL" in https://raw.githubusercontent.com/*|https://github.com/*) :;; *) echo 'preset source URL rejected' >&2; return 2;; esac
  RAW="$URL"; case "$RAW" in *github.com/*/blob/*) RAW="$(printf '%s' "$RAW" | sed 's#https://github.com/#https://raw.githubusercontent.com/#; s#/blob/#/#; s#%20# #g')";; esac
  if command -v uowrt_fetch >/dev/null 2>&1; then uowrt_fetch "$OUT.tmp" "$RAW" >/dev/null 2>&1 || return 1
  elif ai_have curl; then curl -fsSL --connect-timeout 5 --max-time 20 "$RAW" -o "$OUT.tmp" 2>/dev/null || return 1
  elif ai_have wget; then wget -q -T 20 -O "$OUT.tmp" "$RAW" 2>/dev/null || return 1
  else return 127; fi
  [ -s "$OUT.tmp" ] || { rm -f "$OUT.tmp"; return 1; }
  grep -qE '^--(filter|lua-|dpi-|hostlist|payload|new|out-range|in-range)' "$OUT.tmp" || { rm -f "$OUT.tmp"; echo 'preset validation failed: no recognizable strategy directives' >&2; return 1; }
  mv "$OUT.tmp" "$OUT"
  printf 'imported=%s\nengine=%s\nfile=%s\nsource=%s\n' "$ID" "$ENGINE" "$OUT" "$URL"
}
ai_auto(){
  ID="${1:-openai}"; OUT="$(ai_probe_service "$ID" 2>/dev/null || true)"; STATUS="$(printf '%s\n' "$OUT"|sed -n 's/^status=//p'|tail -1)"; NEXT="$(printf '%s\n' "$OUT"|sed -n 's/^next=//p'|tail -1)"; PRIORITY="$(ai_strategy_candidates "$ID" "${STATUS:-DPI_BLOCK}" | tr '\n' ' ')"
  case "$STATUS" in
    PASS) echo 'AI-AUTO: direct path is healthy; no interception applied.'; return 0;;
    DNS_BLOCK) echo "AI-AUTO: priority=$PRIORITY; DNS is first. Use --ai-apply $ID for guarded application."; return 0;;
    DPI_BLOCK|DPI_OR_QUIC_BLOCK) echo "AI-AUTO: priority=$PRIORITY; DPI is first. Use --ai-apply $ID for service-level testing and rollback."; return 0;;
    IP_BLOCK_OR_GEO|POLICY_OR_GEO) echo "AI-AUTO: priority=$PRIORITY; relay/AWG is preferred before DPI for endpoint/region restrictions."; return 0;;
    *) echo "AI-AUTO: status=${STATUS:-UNKNOWN}; priority=$PRIORITY; no automatic mutation."; return 1;;
  esac
}
ai_help(){ cat <<'EOT'
AI Access Engine
  --ai-catalog              list AI service catalog
  --ai-diagnose [SERVICE]   diagnose one service or all services
  --ai-test SERVICE         diagnose one service (alias)
  --ai-auto [SERVICE]       classify and show ordered strategy candidates; does not mutate
  --ai-apply SERVICE        test candidates in priority order and rollback failed changes
  --ai-preset-status        show reserve community preset registry
  --ai-preset-fetch ID      explicitly fetch and validate one upstream preset
EOT
}
