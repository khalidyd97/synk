from pathlib import Path
import hashlib,json,urllib.request,zipfile,io
root=Path(__file__).resolve().parents[2]
deps=root/'.tools/acoustid';deps.mkdir(parents=True,exist_ok=True)
for item in json.loads(Path(__file__).with_name('dependencies.json').read_text()):
 archive=deps/(item['name']+'-source.zip')
 if not archive.exists():archive.write_bytes(urllib.request.urlopen(item['url']).read())
 data=archive.read_bytes()
 if hashlib.sha256(data).hexdigest()!=item['sha256']:raise RuntimeError('Dependency hash mismatch: '+item['name'])
 if not (deps/item['folder']).exists():zipfile.ZipFile(io.BytesIO(data)).extractall(deps)
print('Pinned native dependencies ready.')
