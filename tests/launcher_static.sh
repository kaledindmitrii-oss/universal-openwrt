#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
BAT="$ROOT/Universal-OpenWrt-Launcher.bat"
V="$(cat "$ROOT/VERSION")"
test -f "$BAT"
grep -q 'chcp 65001' "$BAT"
grep -q 'set "ROUTER=192\.168\.1\.1"' "$BAT"
! grep -q '192\.168\.31\.1' "$BAT"
grep -q 'command -v apk' "$BAT"
grep -q 'apk --allow-untrusted add' "$BAT"
grep -q 'opkg install' "$BAT"
grep -Fq 'set "VERSION="' "$BAT"
grep -Fq 'call :READ_VERSION' "$BAT"
grep -Fq 'call :GITHUB_PREFLIGHT' "$BAT"
grep -Fq 'remote-wg-diagnose' "$BAT"
grep -Fq 'then echo [PACKAGE]' "$BAT"
! grep -Fq 'thenecho' "$BAT"
! grep -Fq 'elseecho' "$BAT"
grep -Fq 'telegram-backends-status' "$BAT"
grep -Fq '!VERSION!' "$BAT"
! grep -Fq '30.2.17' "$BAT"
! grep -Fq '30.2.18' "$BAT"
python - "$BAT" "$V" <<'PY'
import re,sys
p=sys.argv[1]; version=sys.argv[2]
s=open(p,encoding='utf-8').read().splitlines()
labels=[]; refs=[]
for i,line in enumerate(s,1):
    m=re.match(r'^:([A-Za-z0-9_-]+)\s*$',line.strip())
    if m: labels.append(m.group(1).lower())
    for x in re.findall(r'\b(?:goto|call)\s+:([A-Za-z0-9_-]+)',line,re.I): refs.append((x.lower(),i))
assert len(labels)==len(set(labels)), 'duplicate BAT label'
missing=sorted(set(x for x,_ in refs)-set(labels)-{'eof'})
assert not missing, missing
assert any(x.lower()==':fail' for x in s), 'FAIL label missing'
fail_idx=next(i for i,x in enumerate(s) if x.strip().lower()==':fail')
assert 'pause' in '\n'.join(s[fail_idx:]), 'failure path must pause'
assert 'goto MENU' in '\n'.join(s[fail_idx:]), 'failure path must return to menu'
text='\n'.join(s)
assert text.index('call :READ_VERSION') < text.index('call :CHECK_PROJECT'), 'VERSION must be loaded before versioned asset validation'
assert 'set "ROUTER=192.168.1.1"' in text, 'router default must be 192.168.1.1'
assert 'set "ROUTER=192.168.' + '31.1"' not in text, 'stale router default remains'
assert 'title Universal OpenWrt v!VERSION! - Launcher' in text, 'title must use runtime VERSION'
print('launcher_static: OK')
PY
