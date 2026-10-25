import json,hashlib,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DOWNLOAD=Path('D:/GameDev/asset-downloads/lowgrid')
registry=ROOT/'third_party/asset-register.json'
records=json.loads(registry.read_text(encoding='utf8'))
def digest(path):
    value=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(8*1024*1024),b''):value.update(chunk)
    return value.hexdigest()
def add(ident,path,source,author,license,changes,download=None):
    entry={'id':ident,'source':source,'author':author,'license':license,'original_archive':str(path),'sha256':digest(path),'modifications':changes}
    if download:entry['download']=download
    records[:]=[record for record in records if record.get('id')!=ident];records.append(entry)
add('makehuman-system-cc0',DOWNLOAD/'makehuman_system_assets_cc0.zip','https://download.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html','MakeHuman Community','CC0-1.0','Adult human bases, system skins, eyes, hair and casual clothing; helper masks baked, MPFB game-engine rig retained, textures reduced to 1K, exported GLB.')
add('mpfb-2.0.18-source',DOWNLOAD/'mpfb2-v2.0.18.zip','https://github.com/makehumancommunity/mpfb2/releases/tag/v2.0.18','MakeHuman Community','GPL-3.0 (tool code), CC0-1.0 (core graphic assets)','External authoring tool only; GPL tool code is not included in game runtime.')
add('kaykit-animations-free-1.1',DOWNLOAD/'kaykit-animations-free-1.1.zip','https://kaylousberg.itch.io/kaykit-character-animations','Kay Lousberg','CC0-1.0','Free 1.1; selected backward, strafe and dodge clips retargeted to adult Quaternius skeleton, root translation removed. Originals retained.')
if (DOWNLOAD/'rain_on_window_loop.wav').exists():add('rain-window-alxl',DOWNLOAD/'rain_on_window_loop.wav','https://opengameart.org/content/rain-on-window-loop','alxl','CC0-1.0','Looped rain ambience for the accident scene; playback gain adjusted.')
add('einar-charge-3.4',Path('D:/GameDev/asset-downloads/blender-charge-source.zip'),'https://www.blender.org/download/demo-files/','Blender Foundation / Blender Studio','CC-BY (as distributed by Blender Studio)','Einar extracted from public Charge scene. Cinema controls/helper geometry removed; original materials baked into 2K atlas, mesh reduced and rebound to game rig. Mechanical arm extracted for L.R.-01. Einar Rig (CC-BY) Blender Foundation | studio.blender.org','https://download.blender.org/demo/splash/blender-3.4-splash.zip')
fixtures=json.loads((DOWNLOAD/'polyhaven/manifest.json').read_text())
for fixture in fixtures:
    file=Path(fixture['file'])
    if file.suffix=='.blend':add(file.parent.name,file,fixture['source'],'Poly Haven','CC0-1.0','Original 1K models and dependencies retained, subdivision removed, denser meshes reduced, exported GLB. Real game lights added at fixture locations.',fixture['url'])
registry.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
shutil.copy2(DOWNLOAD/'mpfb/mpfb2-2.0.18/LICENSE.ASSETS.md',ROOT/'third_party/MakeHuman-assets-CC0.md')
(ROOT/'third_party/Einar-ATTRIBUTION.txt').write_text('Einar Rig (CC-BY) Blender Foundation | studio.blender.org\n\nSource: https://studio.blender.org/characters/einar/v1/\nPublic source scene: https://www.blender.org/download/demo-files/ (Blender 3.4 Charge)\n\nModified for Low Grid: game mesh reduction, removal of cinema control geometry, baked materials, game skeleton and extracted mechanical arm. Original scene retained on D.\n',encoding='utf8')
outputs={}
for folder in ['assets/models/residents','assets/models/fixtures']:
    for path in (ROOT/folder).glob('*.glb'):outputs[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
path=ROOT/'assets/models/parts/lr01_mechanical_arm.glb';outputs[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
(ROOT/'third_party/lowgrid-derived-models.json').write_text(json.dumps(outputs,indent=2),encoding='utf8')
print('PROVENANCE_UPDATED',len(outputs),'derived models')
