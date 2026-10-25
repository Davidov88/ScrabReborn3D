"""Restage relative textures and invalidate first-import material caches safely."""
from pathlib import Path
import json,struct,shutil
root=Path(__file__).resolve().parents[1]
for pack in ('space-station-kit','blaster-kit','factory-kit'):
 for source in (Path('D:/GameDev/asset-downloads')/pack).rglob('*.glb'):
  original=source.read_bytes();n=struct.unpack_from('<I',original,12)[0];data=json.loads(original[20:20+n])
  for image in data.get('images',[]):
   uri=image.get('uri','')
   if uri and not uri.startswith('data:'):
    dest=root/'assets/models'/pack/uri;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source.parent/uri,dest)
  data['asset']['extras']={'scrap_reborn_pipeline':'relative textures restored v2'}
  encoded=json.dumps(data,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
  other=original[20+n:]
  result=struct.pack('<4sII',b'glTF',2,20+len(encoded)+len(other))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+other
  (root/'assets/models'/pack/source.name).write_bytes(result)
 print('REPAIRED_AND_INVALIDATED',pack)
