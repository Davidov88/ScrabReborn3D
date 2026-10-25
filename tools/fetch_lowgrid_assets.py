"""Fetch the selected, licensed production inputs; originals stay on D:."""
import concurrent.futures, hashlib, json, shutil, urllib.request, zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DOWNLOADS=Path('D:/GameDev/asset-downloads/lowgrid')
DOWNLOADS.mkdir(parents=True,exist_ok=True)
PACKS=[
 ('quaternius-ual1','https://opengameart.org/sites/default/files/universal_animation_librarystandard.zip','https://opengameart.org/content/universal-animation-library','Quaternius','CC0-1.0'),
 ('quaternius-ual2','https://opengameart.org/sites/default/files/universal_animation_library_2standard.zip','https://opengameart.org/content/universal-animation-library-2','Quaternius','CC0-1.0'),
 ('robotic-movement','https://opengameart.org/sites/default/files/robotic.7z','https://opengameart.org/content/robotic-mechanic-step-sounds','Lee Barkovich; submitted by Iwan Gabovitch (qubodup)','CC-BY-3.0'),
 ('kenney-impact','https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip','https://kenney.nl/assets/impact-sounds','Kenney','CC0-1.0'),
]

def fetch(pack):
 ident,url,source,author,license=pack
 target=DOWNLOADS/(ident+Path(url).suffix)
 if not target.exists():
  request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
  with urllib.request.urlopen(request,timeout=120) as response,target.open('wb') as out:shutil.copyfileobj(response,out)
 folder=DOWNLOADS/ident;folder.mkdir(exist_ok=True)
 if target.suffix=='.zip':
  with zipfile.ZipFile(target) as archive:
   for entry in archive.infolist():
    destination=(folder/entry.filename).resolve()
    if not destination.is_relative_to(folder.resolve()):raise ValueError('Archive traversal')
   archive.extractall(folder)
 print('FETCHED',ident,target.stat().st_size,flush=True)
 return dict(id=ident,source=source,download=url,author=author,license=license,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),original_archive=str(target),modifications='Production input; see per-asset preparation manifests for runtime derivatives.')

records=list(concurrent.futures.ThreadPoolExecutor(max_workers=4).map(fetch,PACKS))
registry=ROOT/'third_party/asset-register.json'
existing=json.loads(registry.read_text(encoding='utf8'))
existing=[r for r in existing if r['id'] not in {v['id'] for v in records}]+records
registry.write_text(json.dumps(existing,ensure_ascii=False,indent=2),encoding='utf8')
for ident in ['quaternius-ual1','quaternius-ual2']:
 folder=DOWNLOADS/ident
 for licensefile in folder.rglob('*'):
  if licensefile.is_file() and licensefile.name.lower()=='license.txt':
   shutil.copy2(licensefile,ROOT/'third_party'/(ident+'-LICENSE.txt'))
 out=ROOT/'assets/animations'/ident;out.mkdir(parents=True,exist_ok=True)
 for path in folder.rglob('*.glb'):
  if path.name.lower().endswith('_rm.glb'):continue
  shutil.copy2(path,out/path.name)
audio=ROOT/'assets/audio/movement';audio.mkdir(exist_ok=True)
for path in (DOWNLOADS/'kenney-impact').rglob('*.ogg'):
 if 'footstep' in path.name.lower() or 'impactplate' in path.name.lower():shutil.copy2(path,audio/path.name)
(ROOT/'third_party/robotic-movement-LICENSE.txt').write_text('Robotic mechanic step sounds by Lee Barkovich, submitted by Iwan Gabovitch (qubodup).\nhttps://opengameart.org/content/robotic-mechanic-step-sounds\nCC BY 3.0: https://creativecommons.org/licenses/by/3.0/\nChanges: edited, layered, level-matched and converted for positional robot movement audio.\n',encoding='utf8')
print('LOWGRID_INPUTS_READY',flush=True)
