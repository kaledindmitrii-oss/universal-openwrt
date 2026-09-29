#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
JS="$ROOT/luci-app-universal-openwrt/htdocs/luci-static/resources/view/universal-openwrt/overview.js"
RPC="$ROOT/luci-app-universal-openwrt/root/usr/share/rpcd/ucode/luci.universal_openwrt"
ACL="$ROOT/luci-app-universal-openwrt/root/usr/share/rpcd/acl.d/luci-app-universal-openwrt.json"
for f in "$JS" "$RPC" "$ACL"; do test -s "$f" || { echo "missing: $f"; exit 1; }; done
for label in 'Состояние системы' 'AI и популярные сервисы' 'AI: резервные пресеты' 'AWG / WARP' 'Telegram' 'Ресурсы' 'Расширенные инструменты' 'Мастер диагностики' 'Начать диагностику' 'Запустить автонастройку'; do grep -Fq "$label" "$JS" || { echo "missing UI label: $label"; exit 1; }; done
for method in ai_catalog ai_diagnose ai_auto ai_apply ai_preset_status telegram_backends_status telegram_telemt_install strategy_group_status strategy_group_apply strategy_group_disable strategy_group_enable telegram_details; do grep -Fq "$method" "$RPC" || { echo "missing RPC: $method"; exit 1; }; grep -Fq "$method" "$ACL" || { echo "missing ACL: $method"; exit 1; }; done
# Prevent the old wall-of-text dashboard from returning.
! grep -Fq "max-height:300px" "$JS" || true
printf '%s\n' 'luci_ui: OK'
# Guided assistant safety/UX contract.
grep -Fq "До подтверждения конфигурация не изменяется" "$JS" || { echo 'missing assistant safety copy'; exit 1; }
grep -Fq "Технические детали" "$JS" || { echo 'missing technical disclosure'; exit 1; }
grep -Fq "MASTER" "$JS" || { echo 'missing MASTER toggle'; exit 1; }
grep -Fq "Запустить автонастройку" "$JS" || { echo 'missing explicit auto-apply action'; exit 1; }
grep -Fq "Проверить снова" "$JS" || { echo 'missing retry action'; exit 1; }
# The assistant must diagnose before requesting a recommendation.
python - "$JS" <<'PY'
import sys
s=open(sys.argv[1],encoding='utf-8').read()
a=s.index("const a=await api.aiDiagnose")
b=s.index("const rec=await api.aiAuto", a)
assert a < b, 'assistant order regression: recommendation before diagnosis'
PY

grep -Fq 'Контуры стратегий' "$JS" || { echo 'missing strategy scope blocks'; exit 1; }
grep -Fq 'Открыть все настройки Telegram' "$JS" || { echo 'missing Telegram detail drill-down'; exit 1; }
grep -Fq 'Remote WireGuard' "$JS" || { echo 'missing Remote WireGuard mode'; exit 1; }
grep -Fq 'WireGuard VPN' "$JS" || { echo 'missing WireGuard VPN mode'; exit 1; }
grep -Fq 'Белый IP' "$JS" || { echo 'missing white IP diagnostics'; exit 1; }
grep -Fq 'remote_wg_diagnose' "$RPC" || { echo 'missing remote WG diagnose RPC'; exit 1; }
grep -Fq 'remote_wg_set_mode' "$RPC" || { echo 'missing remote WG mode RPC'; exit 1; }
grep -Fq 'Secret key' "$JS" || { echo 'missing Telegram secret display'; exit 1; }
