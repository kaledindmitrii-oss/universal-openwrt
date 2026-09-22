#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
V="$(cat "$ROOT/VERSION")"
for f in \
  "$ROOT/assets/ipk/universal-openwrt_${V}-1_all.ipk" \
  "$ROOT/assets/ipk/luci-app-universal-openwrt_${V}-1_all.ipk" \
  "$ROOT/assets/apk/universal-openwrt-${V}-r1.apk" \
  "$ROOT/assets/apk/luci-app-universal-openwrt-${V}-r1.apk"; do
  test -s "$f"
done
# Release workflow must publish both archive formats, packages and checksums.
grep -q 'dist/\*\.tar\.gz' "$ROOT/.github/workflows/release.yml"
grep -q 'dist/\*\.zip' "$ROOT/.github/workflows/release.yml"
grep -q 'dist/SHA256SUMS' "$ROOT/.github/workflows/release.yml"
grep -q 'dist/release-manifest.json' "$ROOT/.github/workflows/release.yml"
test -x "$ROOT/tools/build-release-manifest.py"
grep -q 'tests/platform_scope.sh' "$ROOT/.github/workflows/release.yml"
grep -q 'tests/release_assets.sh' "$ROOT/.github/workflows/release.yml"
# The Universal OpenWrt LuCI integration must pull in the full LuCI shell, not only luci-base.
grep -q 'DEPENDS:=+luci +luci-base +rpcd +rpcd-mod-ucode +ucode' "$ROOT/luci-app-universal-openwrt/Makefile"
grep -q '"universal-openwrt","luci","luci-base","rpcd","rpcd-mod-ucode","ucode"' "$ROOT/tools/build-assets.py"
# The installer must install LuCI before claiming a successful release/package install.
grep -q 'install_luci_package "\$luci_file"' "$ROOT/installer/install.sh"
grep -q 'Release manifest does not contain a LuCI package' "$ROOT/installer/install.sh"
grep -q 'LuCI shell: verified' "$ROOT/installer/install.sh"

printf 'release_assets: OK\n'

# The plain piped bootstrap must enter release-package mode before any source archive lookup.
python3 - "$ROOT/installer/install.sh" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
assert 'if [ -z "$SRC" ] && [ -z "$URL" ] && [ "$USE_SOURCE" = 0 ]; then' in s
release_pos=s.index('install_release_packages\n  exit 0', s.index('if [ -z "$SRC" ] && [ -z "$URL" ] && [ "$USE_SOURCE" = 0 ]'))
source_pos=s.index('# Explicit source mode keeps checkout/archive installation available.')
assert release_pos < source_pos
assert 'source directory not found' in s
PY

# Every materialized manifest asset must carry bytes and sha256.
# Archive entries may be zero placeholders before release packaging; the workflow reruns this test after archives exist.
python3 - "$ROOT/release-manifest.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
for a in r['assets']:
    if a.get('bytes',0)==0: continue
    assert len(a.get('sha256','')) == 64, a
PY
# Release manifest package entries must point directly at GitHub Release Assets.
python3 - "$ROOT/release-manifest.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
base=f"https://github.com/{r['repository']}/releases/download/{r['tag']}/"
for key,v in r['packages'].items():
    assert v and v['url'].startswith(base), (key,v)
    assert v['url'].endswith(v['file']), (key,v)
PY
