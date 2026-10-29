#!/usr/bin/env python3
"""Extract pinned official Godot templates over verified HTTPS, with ZIP CRC checks.
Python standard library only. HTTP Range avoids downloading unrelated platforms.
"""
import argparse, hashlib, io, json, os, urllib.request, zipfile
from pathlib import Path
VERSION = '4.6.3-stable'
URL = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}/Godot_v{VERSION}_export_templates.tpz'
TARGETS = {'windows': 'windows_release_x86_64.exe', 'linux': 'linux_release.x86_64'}
class RemoteZip(io.RawIOBase):
    def __init__(self):
        with urllib.request.urlopen(urllib.request.Request(URL, method='HEAD'), timeout=60) as r:
            self.url = r.url
            self.size = int(r.headers['Content-Length'])
        self.pos = 0
    def seek(self, n, whence=0):
        self.pos = n if whence == 0 else self.pos + n if whence == 1 else self.size + n
        if self.pos < 0: raise ValueError('Negative file offset')
        return self.pos
    def tell(self): return self.pos
    def read(self, n=-1):
        if n < 0: n = self.size-self.pos
        n = min(n, self.size-self.pos)
        if n <= 0: return b''
        request = urllib.request.Request(self.url, headers={'Range': f'bytes={self.pos}-{self.pos+n-1}'})
        with urllib.request.urlopen(request, timeout=180) as r:
            if r.status != 206: raise RuntimeError('Server did not honor HTTP Range; install official templates manually.')
            data = r.read()
        if len(data) != n: raise RuntimeError('Truncated download')
        self.pos += n
        return data

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--dest', default='.build/templates')
    ap.add_argument('--targets', nargs='+', choices=TARGETS, default=['windows'])
    args = ap.parse_args()
    dest = Path(args.dest); dest.mkdir(parents=True, exist_ok=True)
    records = {'version': VERSION, 'official_source': URL, 'integrity': 'HTTPS + ZIP CRC32; extracted SHA256 recorded (not a vendor signature)', 'files': {}}
    with zipfile.ZipFile(RemoteZip()) as archive:
        for target in args.targets:
            name = TARGETS[target]
            print('Downloading official template:', name, flush=True)
            # ZipFile.read verifies the CRC and decompressed length.
            data = archive.read('templates/'+name)
            path = dest/name
            temporary = path.with_suffix(path.suffix+'.part')
            temporary.write_bytes(data); os.replace(temporary, path)
            if target == 'linux': path.chmod(0o755)
            records['files'][name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
            print('ZIP CRC verified:', path, len(data), 'bytes', flush=True)
    (dest/'provenance.json').write_text(json.dumps(records, indent=2), encoding='utf-8')
if __name__ == '__main__': main()
