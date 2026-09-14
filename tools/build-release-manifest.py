#!/usr/bin/env python3
import hashlib, json, os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / 'VERSION').read_text().strip()
REPO = os.environ.get('UOW_REPO', 'kaledindmitrii-oss/universal-openwrt')
TAG = f'v{VERSION}'
BASE = f'https://github.com/{REPO}/releases/download/{TAG}'

assets = []
for p in sorted((ROOT / 'assets').glob('*/*')):
    if not p.is_file() or p.name == 'manifest.json':
        continue
    assets.append({
        'file': p.name,
        'path': str(p.relative_to(ROOT)).replace('\\', '/'),
        'bytes': p.stat().st_size,
        'sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
        'url': f'{BASE}/{p.name}',
    })
for name in [f'universal-openwrt-v{VERSION}.tar.gz', f'universal-openwrt-v{VERSION}.zip']:
    local = ROOT / 'dist' / name
    if local.is_file():
        assets.append({'file': name, 'bytes': local.stat().st_size, 'sha256': hashlib.sha256(local.read_bytes()).hexdigest(), 'url': f'{BASE}/{name}'})
    else:
        # Archives are produced later by the release workflow; workflow performs a second manifest build after packaging.
        assets.append({'file': name, 'bytes': 0, 'sha256': '', 'url': f'{BASE}/{name}'})

payload = {
    'schema': 1,
    'repository': REPO,
    'tag': TAG,
    'version': VERSION,
    'supported': {'openwrt': ['24.10.2+', '25.12.x'], 'firewall': 'fw4', 'network': 'nftables'},
    'packages': {
        'opkg': next((a for a in assets if a['file'].endswith('.ipk') and not a['file'].startswith('luci-')), None),
        'opkg_luci': next((a for a in assets if a['file'].endswith('.ipk') and a['file'].startswith('luci-')), None),
        'apk': next((a for a in assets if a['file'].endswith('.apk') and not a['file'].startswith('luci-')), None),
        'apk_luci': next((a for a in assets if a['file'].endswith('.apk') and a['file'].startswith('luci-')), None),
    },
    'assets': assets,
}
(ROOT / 'release-manifest.json').write_text(json.dumps(payload, indent=2) + '\n')
print(f'Built release manifest for {VERSION}: {len(assets)} assets')
