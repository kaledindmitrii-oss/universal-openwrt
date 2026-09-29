#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
. "$ROOT/modules/source-resolver.sh"
sh -n "$ROOT/modules/source-resolver.sh"
test "$(uowrt_jsdelivr_url "https://raw.githubusercontent.com/foo/bar/main/test.txt")" = "https://cdn.jsdelivr.net/gh/foo/bar@main/test.txt"
case "$(uowrt_source_status 2>/dev/null || true)" in *status=*) :;; esac
printf "source_resolver: OK\n"
