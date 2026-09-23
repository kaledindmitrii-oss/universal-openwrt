#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src/universal-openwrt"
python3 - "$SRC" <<'PY'
import re,sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text(); lines=s.splitlines()
# Regression: baseline timing file must be initialized before any use under set -u.
base=[i for i,l in enumerate(lines,1) if 'BASELINE_TIMES=' in l]
uses=[i for i,l in enumerate(lines,1) if '$BASELINE_TIMES' in l]
assert base and uses and base[0] < min(uses), (base,uses)
# Regression: resource discovery must not copy active.lst onto itself.
for i,l in enumerate(lines,1):
    assert 'cp -f "$RESOURCE_DIR/active.lst" "$OUT"' not in l, i
# Candidate-builder failure must propagate instead of silently producing an empty suite.
idx=next(i for i,l in enumerate(lines) if l.startswith('resource_matrix_build_candidate(){'))
assert 'resource_matrix_init || return 1' in '\n'.join(lines[idx:idx+5])
# Top-level cleanup trap must not be overwritten by nested controller functions.
assert sum('trap ' in l and 'EXIT' in l for l in lines) == 1
# Locks must use PID ownership and explicit unlock, avoiding stale locks and trap clobbering.
for name,token in [('strategy','STRATEGY_CHANGE_LOCK'),('resource','RESOURCE_BENCH_LOCK'),('predictive','PRED_LOCK'),('vpn','VPN_MONITOR_LOCK')]:
    assert token in s, name
assert 'strategy_change_unlock' in s and 'rm -f "$RESOURCE_BENCH_LOCK"' in s
assert 'predictive_unlock' in s and 'rm -f "$VPN_MONITOR_LOCK"' in s
# Dry-run must terminate before backup/backend/module mutation and real install must fail early without a pinned backend.
install=s.index('  install)')
dry=s.index("log 'DRY-RUN: no configuration", install)
backup=s.index('    backup', install)
assert dry < backup
assert '[ -n "$BACKEND_URL" ] || die' in s
assert '[ -n "$BACKEND_SHA256" ] || die' in s
print('runtime_hardening: OK')
PY
