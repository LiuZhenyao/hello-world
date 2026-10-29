#!/usr/bin/env python3
"""Reproducible Windows/Linux export using Godot 4.6.3 and a staged project.
Does not edit source or tracked export settings. Python/Pillow are build-time only.
"""
import argparse, json, os, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'scripts'))

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--godot',default='godot',help='Godot 4.6.3 editor/console executable')
    ap.add_argument('--target',choices=['windows','linux'],default='windows')
    ap.add_argument('--template',type=Path,help='Use an already installed official release template')
    ap.add_argument('--skip-tests',action='store_true')
    ap.add_argument('--package',action='store_true')
    args=ap.parse_args()
    engine=shutil.which(args.godot)
    if not engine:raise SystemExit('Godot not found. Pass --godot with the full path to Godot 4.6.3.')
    engine=str(Path(engine).resolve())
    work=ROOT/'.build';build=ROOT/'build';logs=build/'logs'
    logs.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy()
    if sys.platform!='win32':
        for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
            if key not in env:
                dest=work/'xdg'/folder;dest.mkdir(parents=True,exist_ok=True);env[key]=str(dest)
    version=subprocess.run([engine,'--version'],capture_output=True,text=True,env=env,check=True).stdout.strip()
    if not version.startswith('4.6.3.'):raise SystemExit('This build is pinned to Godot 4.6.3; found '+version)
    def run(name,arguments):
        print(name,flush=True)
        with (logs/(name+'.log')).open('w',encoding='utf-8') as log:
            result=subprocess.run([engine,*map(str,arguments)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        if result.returncode:
            print((logs/(name+'.log')).read_text(encoding='utf-8',errors='replace'))
            raise SystemExit(f'{name} failed with exit code {result.returncode}')
    template=args.template
    if template is None:
        template=work/'templates'/('windows_release_x86_64.exe' if args.target=='windows' else 'linux_release.x86_64')
        if not template.is_file():
            subprocess.run([sys.executable,str(ROOT/'scripts/fetch_templates.py'),'--dest',str(template.parent),'--targets',args.target],cwd=ROOT,check=True,env=env)
    template=template.resolve()
    if not template.is_file():raise SystemExit('Official template not found: '+str(template))
    stage=work/'project'
    shutil.copytree(ROOT/'orbitlaser',stage,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.godot'))
    cfg=(ROOT/'orbitlaser/export_presets.cfg').read_text(encoding='utf-8')
    section='[preset.0.options]' if args.target=='windows' else '[preset.1.options]'
    at=cfg.index(section)
    cfg=cfg[:at]+cfg[at:].replace('custom_template/release=""','custom_template/release="'+template.as_posix()+'"',1)
    (stage/'export_presets.cfg').write_text(cfg,encoding='utf-8')
    run('import',['--headless','--editor','--path',stage,'--import','--quit'])
    if not args.skip_tests:
        run('model',['--headless','--path',stage,'--script','tests/test_model.gd'])
        run('constellation',['--headless','--path',stage,'--script','tests/test_constellation.gd'])
        run('export-tests',['--headless','--path',stage,'--script','tests/test_export.gd'])
        run('ui-headless',['--headless','--path',stage,'--script','tests/test_ui.gd','--','--output='+str(build/'validation')])
    output=build/('OrbitLaser.exe' if args.target=='windows' else 'OrbitLaser-linux.x86_64')
    output.unlink(missing_ok=True)
    run('export-'+args.target,['--headless','--path',stage,'--export-release','Windows Desktop' if args.target=='windows' else 'Linux Test',output])
    if not output.is_file() or output.stat().st_size<10_000_000:raise SystemExit('Expected executable was not produced')
    if args.target=='windows':
        from brand_windows import brand
        brand(output)
    else:output.chmod(0o755)
    smoke=build/'packaged-smoke.json';smoke.unlink(missing_ok=True)
    native=(args.target=='windows' and sys.platform=='win32') or (args.target=='linux' and sys.platform.startswith('linux'))
    command=[str(output)] if native else [engine,'--main-pack',str(output)]
    with (logs/'packaged-smoke.log').open('w',encoding='utf-8') as log:
        proc=subprocess.run([*command,'--headless','--','--smoke-test','--smoke-test-output='+str(smoke)],env=env,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=60)
    if proc.returncode or not smoke.is_file() or not json.loads(smoke.read_text(encoding='utf-8')).get('passed'):
        raise SystemExit('Packaged startup check failed; inspect build/logs/packaged-smoke.log')
    evidence={'engine':version,'target':args.target,'build_platform':sys.platform,'native_packaged_smoke':native,'executable':output.name,'smoke':json.loads(smoke.read_text(encoding='utf-8'))}
    (build/'build-evidence.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
    print('EXPORTED:',output,output.stat().st_size,'bytes')
    print('Packaged smoke:', 'native' if native else 'resource pack loaded using host editor; not native target validation')
    if args.package:
        if args.target!='windows':raise SystemExit('--package requires --target windows')
        subprocess.run([sys.executable,str(ROOT/'scripts/package.py')],cwd=ROOT,check=True,env=env)
if __name__=='__main__':main()
