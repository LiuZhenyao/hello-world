#!/usr/bin/env python3
"""Create real distributable/source archives, check ZIP CRCs and write SHA256 sums."""
import hashlib, json, subprocess, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
BUILD=ROOT/'build'
RELEASES=ROOT/'releases'

def digest(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def main():
    exe=BUILD/'OrbitLaser.exe'
    if not exe.is_file():raise SystemExit('Missing build/OrbitLaser.exe; run scripts/build.py first.')
    RELEASES.mkdir(exist_ok=True)
    windows=RELEASES/'卫星轨道模拟仿真教学软件-2.0-Windows-x64.zip'
    source=RELEASES/'卫星轨道模拟仿真教学软件-2.0-源码.zip'
    with zipfile.ZipFile(windows,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        z.write(exe,'卫星轨道模拟仿真教学软件/卫星轨道模拟仿真教学软件.exe')
        for p in sorted((ROOT/'docs').glob('*.md')):z.write(p,'卫星轨道模拟仿真教学软件/'+p.name)
        for p in sorted((ROOT/'orbitlaser/licenses').glob('*.txt')):z.write(p,'卫星轨道模拟仿真教学软件/许可/'+p.name)
        for name in ['LEO-GEO.json','example-measurements.csv','example-report.html','OrbitLaser-workbench.png','OrbitLaser-data.png','OrbitLaser-network.png','ui-validation.json']:
            p=BUILD/'validation'/name
            if p.is_file():z.write(p,'卫星轨道模拟仿真教学软件/示例/'+name)
        for name in ['build-evidence.json','packaged-smoke.json']:
            p=BUILD/name
            if p.is_file():z.write(p,'卫星轨道模拟仿真教学软件/验证记录/'+name)
        for p in sorted((BUILD/'logs').glob('*.log')):
            if p.stat().st_size<1024*1024:z.write(p,'卫星轨道模拟仿真教学软件/验证记录/日志/'+p.name)
    excluded={'.git','.build','build','releases','__pycache__','.godot'}
    with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(ROOT.rglob('*')):
            rel=p.relative_to(ROOT)
            if p.is_file() and not excluded.intersection(rel.parts):z.write(p,'OrbitLaser-source/'+rel.as_posix())
    for p in [windows,source]:
        with zipfile.ZipFile(p) as z:
            if z.testzip() is not None:raise SystemExit('ZIP CRC failed: '+str(p))
        if p.stat().st_size>=100*1024*1024:raise SystemExit('Archive exceeds GitHub regular-file limit.')
    with zipfile.ZipFile(source) as z:
        names=set(z.namelist())
        for rel in ['orbitlaser/app.gd','orbitlaser/model.gd','orbitlaser/assets/ui.ttc','orbitlaser/export_presets.cfg','scripts/build-windows.ps1','scripts/requirements-build.txt','README.md','docs/BUILD_WINDOWS.md']:
            assert 'OrbitLaser-source/'+rel in names,rel
    records=[(windows,windows.name),(source,source.name),(exe,'卫星轨道模拟仿真教学软件/卫星轨道模拟仿真教学软件.exe')]
    (RELEASES/'SHA256SUMS.txt').write_text(''.join(digest(p)+'  '+name+'\n' for p,name in records),encoding='utf-8')
    for p,name in records:print(name,p.stat().st_size,'bytes',digest(p))
if __name__=='__main__':main()
