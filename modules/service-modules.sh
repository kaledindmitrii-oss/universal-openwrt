#!/bin/sh
# Universal OpenWrt v30.2.19 - independent service module registry
# Each module owns its recovery queue. All modules are enabled by default.

SERVICE_MODULE_CONF='/etc/universal-openwrt/service-modules.conf'
SERVICE_MODULES='youtube social gaming ai telegram streaming messaging developer news'
SERVICE_GROUPS='youtube social ai gaming telegram streaming messaging developer news'

service_modules_init(){
  mkdir -p "$(dirname "$SERVICE_MODULE_CONF")" 2>/dev/null || return 1
  if [ ! -f "$SERVICE_MODULE_CONF" ]; then
    : >"$SERVICE_MODULE_CONF"
    for m in $SERVICE_MODULES; do printf '%s=1\n' "$m" >>"$SERVICE_MODULE_CONF"; done
  fi
}
service_module_valid(){ case " $SERVICE_MODULES " in *" $1 "*) return 0;; *) return 1;; esac; }
service_module_enabled(){ service_modules_init || return 1; service_module_valid "$1" || return 1; v="$(awk -F= -v m="$1" '$1==m{print $2;exit}' "$SERVICE_MODULE_CONF" 2>/dev/null)"; [ "${v:-1}" = 1 ]; }
service_module_set(){ service_modules_init || return 1; service_module_valid "$1" || return 1; case "$2" in 0|1) ;; *) return 1;; esac; t="$SERVICE_MODULE_CONF.tmp.$$"; awk -F= -v m="$1" -v v="$2" 'BEGIN{done=0} $1==m{print m"="v;done=1;next} {print} END{if(!done)print m"="v}' "$SERVICE_MODULE_CONF" >"$t" && mv "$t" "$SERVICE_MODULE_CONF"; }
service_modules_status(){ service_modules_init || return 1; printf 'module\tenabled\tmode\n'; for m in $SERVICE_MODULES; do if service_module_enabled "$m"; then printf '%s\t1\tindependent\n' "$m"; else printf '%s\t0\tdisabled\n' "$m"; fi; done; }
service_group_valid(){ case " $SERVICE_GROUPS " in *" $1 "*) return 0;; *) return 1;; esac; }
service_group_label(){ case "$1" in youtube) echo 'YouTube';; social) echo 'Социальные сети';; ai) echo 'AI';; gaming) echo 'Игры';; telegram) echo 'Telegram';; streaming) echo 'Видео и музыка';; messaging) echo 'Мессенджеры';; developer) echo 'Разработка';; news) echo 'Новости';; esac; }
service_module_label(){ case "$1" in youtube) echo 'YouTube';; social) echo 'Социальные сети';; gaming) echo 'Игры';; ai) echo 'AI';; telegram) echo 'Telegram';; streaming) echo 'Видео и музыка';; messaging) echo 'Мессенджеры';; developer) echo 'Разработка';; news) echo 'Новости';; esac; }
