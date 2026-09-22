#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
V="$(cat "$ROOT/VERSION")"
for f in "$ROOT/src/universal-openwrt" "$ROOT/installer/install.sh" "$ROOT/install-luci.sh" "$ROOT/tests"/*.sh "$ROOT/modules"/*.sh "$ROOT/packaging/root/etc/init.d"/*; do sh -n "$f"; done
for f in universal-openwrt-tg-proxy universal-openwrt-tg-ws universal-openwrt-tg-socks5-go universal-openwrt-vpn-monitor; do test -f "$ROOT/packaging/root/etc/init.d/$f"; done
python3 - "$ROOT" "$V" <<'PY'
import sys,re,json,hashlib,gzip,io,tarfile,zlib
from pathlib import Path
root=Path(sys.argv[1]); V=sys.argv[2]
src=(root/'src/universal-openwrt').read_text()
# no CR bytes in runtime/install files
for base in ['src','modules','installer','packaging','luci-app-universal-openwrt']:
  for f in (root/base).rglob('*'):
    if f.is_file(): assert b'\r' not in f.read_bytes(), f
assert b'\r' not in (root/'install-luci.sh').read_bytes()
assert 'archive/refs/heads/${REF}.tar.gz' not in src
inst=(root/'installer/install.sh').read_text()
assert 'archive/refs/tags/${REF}.tar.gz' in inst
assert 'archive/refs/heads/${REF}.tar.gz' in inst
luci=(root/'install-luci.sh').read_text()
assert 'archive/refs/tags/${REF}.tar.gz' in luci
assert '24.10.2+' in (root/'installer/install.sh').read_text()
assert 'UOW_BACKEND_SHA256' in src
assert (root/'VERSION').read_text().strip() in (root/'README.md').read_text()
rm = json.loads((root/'release-manifest.json').read_text())
assert rm['version'] == V and rm['tag'] == 'v' + V
for key in ['opkg','opkg_luci','apk','apk_luci']:
    assert rm['packages'][key] and rm['packages'][key]['sha256']
assert 'releases/download/v' + V in (root/'release-manifest.json').read_text()

assert (root/'VERSION').read_text().strip() in (root/'installer/install.sh').read_text()
assert '--backend-sha256' in src
assert '__UOWRT_RC=' in (root/'luci-app-universal-openwrt/root/usr/share/rpcd/ucode/luci.universal_openwrt').read_text()
assert 'exit_code' in (root/'luci-app-universal-openwrt/root/usr/share/rpcd/ucode/luci.universal_openwrt').read_text()
# Installer must never reference an init script that is absent from the release tree.
inst=(root/'installer/install.sh').read_text()
for m in re.findall(r'packaging/root/etc/init\.d/([A-Za-z0-9._-]+)', inst):
    assert (root/'packaging/root/etc/init.d'/m).is_file(), m
# Every dispatch mode must be implemented before runtime dispatch executes.
lines=src.splitlines()
fn_line={}
for i,line in enumerate(lines,1):
    m=re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\(\)\{',line)
    if m: fn_line[m.group(1)]=i
module_fns=set()
for mf in (root/'modules').glob('*.sh'):
    for line in mf.read_text().splitlines():
        m=re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\(\)\{',line)
        if m: module_fns.add(m.group(1))
dispatch_line=next(i for i,l in enumerate(lines,1) if l.strip()=='case "$MODE" in' and i>1800)
for i,line in enumerate(lines,1):
    m=re.match(r'^  ([a-z_]+)\)\s+([A-Za-z_][A-Za-z0-9_]*)',line)
    if m and m.group(1) not in ('*',):
        target=m.group(2)
        if target in ('if','case','for','while','until','return','log','die'): continue
        assert target in fn_line or target in module_fns or target in ('exit','tg_proxy_load','tg_failover_status','tgws_status','se_plan','se_status','te_status','te_profile_list','te_profile_create','te_profile_delete','te_enable','te_disable','te_auto_select'), (i,target)
        if target in fn_line and i>dispatch_line: assert fn_line[target] < i, (i,target,fn_line[target])
# CLI help/dispatch parity
h=set(re.findall(r'^\s*(--[a-z0-9-]+)',src,re.M)); d=set(re.findall(r'^\s*(--[a-z0-9-]+)\)',src,re.M)); assert h==d,(h-d,d-h)
# RPC method/ACL parity
uc=(root/'luci-app-universal-openwrt/root/usr/share/rpcd/ucode/luci.universal_openwrt').read_text()
methods=set(re.findall(r'(?:^|,|\n)\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*\{args:',uc,re.M))
a=json.loads((root/'luci-app-universal-openwrt/root/usr/share/rpcd/acl.d/luci-app-universal-openwrt.json').read_text())['luci-app-universal-openwrt']; r=set(a['read']['ubus']['universal_openwrt']); w=set(a['write']['ubus']['universal_openwrt']); assert not ((r|w)-methods),sorted((r|w)-methods); assert not (methods-(r|w)),sorted(methods-(r|w))
# manifests + hashes + core package contents
for fmt in ['ipk','apk']:
 m=json.loads((root/'assets'/fmt/'manifest.json').read_text()); assert m['version']==V
 for p in m['packages']:
  f=root/'assets'/fmt/p['file']; assert f.is_file() and f.stat().st_size==p['bytes']; assert hashlib.sha256(f.read_bytes()).hexdigest()==p['sha256']
  if fmt=='ipk':
   # OpenWrt 24.10 ipkg-build emits the outer .ipk as gzip-compressed tar.
   # This avoids GNU-ar member names such as control.tar.gz/ that some opkg
   # builds reject as malformed.
   raw=f.read_bytes(); outer=gzip.decompress(raw); tf=tarfile.open(fileobj=io.BytesIO(outer),mode='r:'); members={m.name:m for m in tf.getmembers()}
   assert './debian-binary' in members and './control.tar.gz' in members and './data.tar.gz' in members
   assert tf.extractfile(members['./debian-binary']).read()==b'2.0\n'
   data=tf.extractfile(members['./data.tar.gz']).read()
   data_members=tarfile.open(fileobj=io.BytesIO(gzip.decompress(data)),mode='r:').getmembers()
   names={m.name for m in data_members}
   if p['file'].startswith('universal-openwrt_'):
    assert 'usr' in names and 'usr/lib' in names and 'usr/lib/universal-openwrt' in names and 'etc' in names and 'etc/init.d' in names,(p['file'],'directory entries')
    for req in ['usr/sbin/universal-openwrt','usr/lib/universal-openwrt/strategy-engine.sh','usr/lib/universal-openwrt/tunnel-engine.sh','usr/lib/universal-openwrt/tg-ws-proxy.sh','usr/lib/universal-openwrt/tg-socks5-go.sh','etc/init.d/universal-openwrt-tg-proxy','etc/init.d/universal-openwrt-tg-ws','etc/init.d/universal-openwrt-tg-socks5-go']: assert req in names,(p['file'],req)
  else:
   raw=f.read_bytes(); pos=0; members=[]
   while pos<len(raw):
    d=zlib.decompressobj(16+zlib.MAX_WBITS); x=d.decompress(raw[pos:])+d.flush(); used=len(raw[pos:])-len(d.unused_data); assert used>0; pos+=used
    # APK v2 control is a tar segment without EOF blocks; data is a normal tarball.
    try: names={m.name for m in tarfile.open(fileobj=io.BytesIO(x),mode='r:').getmembers()}
    except tarfile.ReadError:
     tf=tarfile.open(fileobj=io.BytesIO(x+b'\0'*1024),mode='r:'); names={m.name for m in tf.getmembers()}
    members.append(names)
   assert len(members)==2,(p['file'],len(members))
   if p['file'].startswith('universal-openwrt-'):
    assert '.PKGINFO' in members[0]
    for req in ['usr/sbin/universal-openwrt','usr/lib/universal-openwrt/strategy-engine.sh','usr/lib/universal-openwrt/tunnel-engine.sh','usr/lib/universal-openwrt/tg-ws-proxy.sh','usr/lib/universal-openwrt/tg-socks5-go.sh','etc/init.d/universal-openwrt-tg-proxy','etc/init.d/universal-openwrt-tg-ws','etc/init.d/universal-openwrt-tg-socks5-go']: assert req in members[1],(p['file'],req)
print('release_integrity: OK')
PY
