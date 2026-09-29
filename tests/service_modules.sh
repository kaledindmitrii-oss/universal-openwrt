#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT/modules/service-modules.sh"
TMP="${TMPDIR:-/tmp}/uowrt-service-modules.$$"
trap 'rm -f "$TMP"' EXIT
SERVICE_MODULE_CONF="$TMP"
service_modules_init
EXPECTED='youtube social gaming ai telegram streaming messaging developer'
for m in $EXPECTED; do service_module_enabled "$m"; done
service_module_set gaming 0
! service_module_enabled gaming
service_module_set gaming 1
service_module_enabled gaming
service_module_set ai 0
! service_module_enabled ai
printf 'SERVICE_MODULES=PASS\n'
