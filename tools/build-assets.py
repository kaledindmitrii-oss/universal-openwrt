#!/usr/bin/env python3
"""Build architecture-independent UOWRT IPK/APK assets.
For production signed APKs, use the OpenWrt SDK/buildroot; these local assets are unsigned
and intended for `apk add --allow-untrusted`.
"""
from pathlib import Path
import tarfile,gzip,io,os,json,hashlib

ROOT=Path(__file__).resolve().parents[1]
VERSION=(ROOT/"VERSION").read_text().strip()
OUT=ROOT/"assets"

def add(t,src,arc,mode):
    data=Path(src).read_bytes(); i=tarfile.TarInfo(arc); i.size=len(data); i.mode=mode; i.mtime=0;i.uid=0;i.gid=0
    t.addfile(i,io.BytesIO(data))
def data_tar(files):
    # Match OpenWrt ipkg-build: the data archive must contain directory
    # entries, not only regular files. BusyBox tar/opkg on 24.10 can fail
    # with wfopen ENOENT when parent directories are absent from the archive.
    b=io.BytesIO()
    dirs=set()
    for _, arc, _ in files:
        parts=Path(arc).parts[:-1]
        cur=[]
        for part in parts:
            cur.append(part); dirs.add("/".join(cur)+"/")
    with tarfile.open(fileobj=b,mode="w",format=tarfile.GNU_FORMAT) as t:
        for d in sorted(dirs):
            i=tarfile.TarInfo(d); i.type=tarfile.DIRTYPE; i.mode=0o755; i.mtime=0; i.uid=0; i.gid=0
            t.addfile(i)
        for s,a,m in sorted(files,key=lambda x:x[1]):add(t,s,a,m)
    return b.getvalue()
def gz(x):return gzip.compress(x,9,mtime=0)
def files_for(sub):
    out=[]
    if sub=="core":
        out=[(ROOT/"src/universal-openwrt","usr/sbin/universal-openwrt",0o755)]
        out += [(f,f"usr/lib/universal-openwrt/{f.name}",0o755) for f in (ROOT/"modules").glob("*.sh")]
        out += [(f,f"etc/init.d/{f.name}",0o755) for f in (ROOT/"packaging/root/etc/init.d").iterdir() if f.is_file()]
        out += [(f,f"usr/lib/universal-openwrt/test-resources/{f.relative_to(ROOT/'resources')}",0o644) for f in (ROOT/"resources").rglob("*") if f.is_file()]
    else:
        for f in (ROOT/"luci-app-universal-openwrt").rglob("*"):
            if not f.is_file():continue
            r=str(f.relative_to(ROOT/"luci-app-universal-openwrt"))
            if r.startswith("root/"): a=r[5:]
            elif r.startswith("htdocs/"): a="www/"+r[7:]
            else: continue
            out.append((f,a,0o755 if f.name.startswith("luci.") else 0o644))
    return out
def ipk(name,files,depends):
    c=f"Package: {name}\nVersion: {VERSION}-1\nArchitecture: all\nSection: net\nPriority: optional\nMaintainer: Universal OpenWrt\nDescription: Universal OpenWrt adaptive network manager\n"
    if depends:c+=f"Depends: {depends}\n"
    dt=data_tar(files)
    installed_size=len(dt)
    c += f"Installed-Size: {installed_size}\n"
    b=io.BytesIO()
    with tarfile.open(fileobj=b,mode="w",format=tarfile.GNU_FORMAT) as t:
        d=c.encode();i=tarfile.TarInfo("./control");i.size=len(d);i.mode=0o644;i.mtime=0;i.uid=0;i.gid=0;t.addfile(i,io.BytesIO(d))
    # OpenWrt's native ipkg-build format for 24.10 is a gzip-compressed
    # tar stream containing exactly these three members. Do not build the
    # outer container with GNU ar: its member names are emitted as
    # "control.tar.gz/" etc. by GNU ar, which older opkg builds reject as
    # "Malformed package file".
    outer=io.BytesIO()
    with tarfile.open(fileobj=outer,mode="w",format=tarfile.GNU_FORMAT) as t:
        for name,data in (("./debian-binary",b"2.0\n"),("./control.tar.gz",gz(b.getvalue())),("./data.tar.gz",gz(dt))):
            i=tarfile.TarInfo(name); i.size=len(data); i.mode=0o644; i.mtime=0; i.uid=0; i.gid=0
            t.addfile(i,io.BytesIO(data))
    return gz(outer.getvalue())
def apk(name,files,depends):
    # APK v2 package = gzip(control tar segment) + gzip(data tarball).
    # A single gzip stream containing both .PKGINFO and data is malformed to
    # apk-tools (OpenWrt 25.12), even when --allow-untrusted is used.
    data_raw=data_tar(files)
    data_gz=gz(data_raw)
    datahash=hashlib.sha256(data_gz).hexdigest()
    installed_size=sum(Path(src).stat().st_size for src,_,_ in files)
    p=f"pkgname = {name}\npkgver = {VERSION}-r1\npkgdesc = Universal OpenWrt adaptive network manager\nurl = https://github.com/kaledindmitrii-oss/universal-openwrt\nbuilddate = 0\nsize = {installed_size}\narch = all\nlicense = MIT\norigin = {name}\ndatahash = {datahash}\n"
    p+="".join(f"depend = {d}\n" for d in depends)

    cb=io.BytesIO()
    with tarfile.open(fileobj=cb,mode="w",format=tarfile.GNU_FORMAT) as t:
        d=p.encode(); i=tarfile.TarInfo(".PKGINFO"); i.size=len(d); i.mode=0o644; i.mtime=0; i.uid=0; i.gid=0
        t.addfile(i,io.BytesIO(d))
    # Control is a tar segment: deliberately strip the normal tar EOF blocks.
    control_raw=cb.getvalue().rstrip(b"\0")
    return gz(control_raw)+data_gz

spec=[("universal-openwrt",files_for("core"),[]),("luci-app-universal-openwrt",files_for("luci"),["universal-openwrt","luci","luci-base","rpcd","rpcd-mod-ucode","ucode"])]
(OUT/"ipk").mkdir(parents=True,exist_ok=True);(OUT/"apk").mkdir(parents=True,exist_ok=True)
# Keep generated asset directories deterministic: remove packages from older releases.
for fmt, ext in (("ipk", "ipk"), ("apk", "apk")):
    for old in (OUT/fmt).glob(f"*.{ext}"):
        old.unlink()
for n,f,d in spec:
    (OUT/"ipk"/f"{n}_{VERSION}-1_all.ipk").write_bytes(ipk(n,f,", ".join(d)))
    (OUT/"apk"/f"{n}-{VERSION}-r1.apk").write_bytes(apk(n,f,d))
manifest={"version":VERSION,"packages":[]}
for fmt,ext in (("apk","apk"),("ipk","ipk")):
    for fp in sorted((OUT/fmt).glob(f"*.{ext}")):
        manifest["packages"].append({"format":fmt,"file":fp.name,"sha256":hashlib.sha256(fp.read_bytes()).hexdigest(),"bytes":fp.stat().st_size,"signed":False})
(OUT/"apk"/"manifest.json").write_text(json.dumps({"version":VERSION,"format":"apk","packages":[x for x in manifest["packages"] if x["format"]=="apk"]},indent=2)+"\n")
(OUT/"ipk"/"manifest.json").write_text(json.dumps({"version":VERSION,"format":"ipk","packages":[x for x in manifest["packages"] if x["format"]=="ipk"]},indent=2)+"\n")
print("Built assets for",VERSION)
