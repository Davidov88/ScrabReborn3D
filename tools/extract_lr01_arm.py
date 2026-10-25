"""Einar-derived mechanical arm variant for L.R.-01. CC-BY Blender Foundation."""
import bpy,bmesh
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art_source/steel_einar_game.blend'))
body=next(o for o in bpy.context.scene.objects if o.type=='MESH')
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
groups={g.index for g in body.vertex_groups if g.name.endswith('.L') and any(x in g.name for x in ['upper_arm','forearm','hand','f_','thumb','shoulder'])}
remove=[]
for vertex in body.data.vertices:
    weight=sum(g.weight for g in vertex.groups if g.group in groups)
    if weight<.55:remove.append(vertex.index)
mesh=bmesh.new();mesh.from_mesh(body.data);mesh.verts.ensure_lookup_table()
bmesh.ops.delete(mesh,geom=[mesh.verts[i] for i in remove],context='VERTS');mesh.to_mesh(body.data);mesh.free()
body.name='LR01_Einar_Mechanical_Arm'
bpy.context.view_layer.objects.active=body
modifier=body.modifiers.new('LR01 arm game budget','DECIMATE');modifier.ratio=min(1,6000/max(1,len(body.data.polygons)));bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/lr01_mechanical_arm.blend'))
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/parts/lr01_mechanical_arm.glb'),export_format='GLB',use_selection=True,export_animations=False)
print('LR01_ARM_EXPORTED',len(body.data.polygons),flush=True)
