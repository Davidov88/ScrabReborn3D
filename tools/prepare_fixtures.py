import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/fixtures';OUT.mkdir(exist_ok=True)
for ident in ['industrial_pipe_lamp','industrial_caged_sconce']:
    source=Path('D:/GameDev/asset-downloads/lowgrid/polyhaven')/ident/(ident+'_1k.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in list(bpy.context.scene.objects):
        if obj.type!='MESH':continue
        obj.select_set(True);bpy.context.view_layer.objects.active=obj
        for modifier in list(obj.modifiers):
            if modifier.type=='SUBSURF':obj.modifiers.remove(modifier)
        if len(obj.data.polygons)>4000:
            modifier=obj.modifiers.new('Game LOD0','DECIMATE');modifier.ratio=.4;bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(ident+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
    print('FIXTURE_EXPORTED',ident,flush=True)
