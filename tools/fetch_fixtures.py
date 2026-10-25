"""Fetch original CC0 fixtures from Poly Haven's documented file API."""
import urllib.request,json,hashlib,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=Path('D:/GameDev/asset-downloads/lowgrid/polyhaven');OUT.mkdir(exist_ok=True)
records=[]
for asset in ['industrial_pipe_lamp','industrial_caged_sconce']:
    metadata=OUT/(asset+'.json')
    subprocess.run(['curl.exe','-L','--fail','--silent','--show-error','-o',str(metadata),'https://api.polyhaven.com/files/'+asset],check=True)
    files=json.loads(metadata.read_text())
    entry=files['blend']['1k']['blend'];folder=OUT/asset;folder.mkdir(exist_ok=True)
    downloads={asset+'_1k.blend':entry,**entry.get('include',{})}
    for name,info in downloads.items():
        target=folder/name;target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists():subprocess.run(['curl.exe','-L','--fail','--silent','--show-error','-o',str(target),info['url']],check=True)
        if hashlib.md5(target.read_bytes()).hexdigest()!=info['md5']:raise ValueError('Hash mismatch: '+str(target))
        records.append({'file':str(target),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'url':info['url'],'source':'https://polyhaven.com/a/'+asset,'author':'Poly Haven','license':'CC0-1.0','resolution':'1K'})
(OUT/'manifest.json').write_text(json.dumps(records,indent=2),encoding='utf8')
print('FIXTURES_VERIFIED',len(records))
