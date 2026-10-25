import bpy,json
from pathlib import Path
path='D:/GameDev/asset-downloads/charge/pro/lib/char/einar/publish/einar.v004.blend'
with bpy.data.libraries.load(path,link=False) as (source,target):
    print('COLLECTIONS',source.collections,flush=True)
    target.collections=[name for name in source.collections if name.startswith('CH-einar')]
for collection in target.collections:
    if collection:bpy.context.scene.collection.children.link(collection)
report=[]
for obj in bpy.context.scene.objects:
    if obj.type=='MESH':report.append({'name':obj.name,'verts':len(obj.data.vertices),'polygons':len(obj.data.polygons),'hide':obj.hide_render,'modifiers':[(m.name,m.type) for m in obj.modifiers],'materials':[m.name if m else '' for m in obj.data.materials]})
print('MESH_REPORT',json.dumps(report),flush=True)
Path('D:/GameDev/checks/charge-meshes.json').write_text(json.dumps(report,indent=2))
