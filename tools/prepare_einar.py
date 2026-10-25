"""Game adaptation of Einar, Blender Foundation / Blender Studio, CC-BY.
Strip cinema controls, reduce geometry, bake original materials and transfer to the CC0 motion rig.
"""
import bpy,math,json,sys
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
source='D:/GameDev/asset-downloads/charge/pro/lib/char/einar/publish/einar.v004.blend'
with bpy.data.libraries.load(source,link=False) as (data,target):target.collections=[n for n in data.collections if n.startswith('CH-einar')]
for collection in target.collections:
    if collection:bpy.context.scene.collection.children.link(collection)
depsgraph=bpy.context.evaluated_depsgraph_get()
parts=[]
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH' or obj.hide_render or not obj.data.materials or not obj.name.startswith('GEO-'):continue
    if any(x in obj.name for x in ['surfdef','surfacedeform','meniscus','plica','cornea']):continue
    for modifier in list(obj.modifiers):
        if modifier.type in ['SUBSURF','PARTICLE_SYSTEM','NODES']:obj.modifiers.remove(modifier)
    try:
        mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph),depsgraph=depsgraph)
        copy=bpy.data.objects.new('Game_'+obj.name,mesh);bpy.context.scene.collection.objects.link(copy);copy.matrix_world=obj.matrix_world;parts.append(copy)
    except Exception as exc:print('SKIP',obj.name,str(exc),flush=True)
for obj in list(bpy.context.scene.objects):
    if obj not in parts:bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();body=bpy.context.object;body.name='Steel_Einar_Game'
print('SOURCE_POLYGONS',len(body.data.polygons),flush=True)
modifier=body.modifiers.new('Game mesh 35000 triangles','DECIMATE');modifier.ratio=min(1,18000/max(1,len(body.data.polygons)));bpy.ops.object.modifier_apply(modifier=modifier.name)
for image in bpy.data.images:
    if image.source=='FILE':
        image.filepath=bpy.path.abspath(image.filepath,library=image.library)
        if image.size and max(image.size)>2048:
            factor=2048/max(image.size);image.scale(int(image.size[0]*factor),int(image.size[1]*factor))
    elif image.source=='TILED':
        path=bpy.path.abspath(image.filepath,library=image.library).replace('<UDIM>','1001')
        if Path(path).exists():image.source='FILE';image.filepath=path;image.reload()
# Keep the original UV for procedural/source textures; bake into a separate atlas UV.
original_uv=body.data.uv_layers.active
original_uv_name=original_uv.name if original_uv else 'UVMap'
for name in [layer.name for layer in body.data.uv_layers]:
    if name!=original_uv_name:body.data.uv_layers.remove(body.data.uv_layers[name])
body.data.uv_layers[original_uv_name].active_render=True
atlas_uv=body.data.uv_layers.new(name='GameAtlas');body.data.uv_layers.active=atlas_uv
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.008);bpy.ops.object.mode_set(mode='OBJECT')
atlas_uv=body.data.uv_layers['GameAtlas']
# Bake targets use the render-active UV. Keep texture sampling explicitly on the source UV.
visited=set()
def source_coordinates(nodes):
    if nodes.as_pointer() in visited:return
    visited.add(nodes.as_pointer())
    original=nodes.nodes.new('ShaderNodeUVMap');original.uv_map=original_uv_name
    for node in list(nodes.nodes):
        if node.type=='TEX_IMAGE' and not node.inputs['Vector'].is_linked:nodes.links.new(original.outputs['UV'],node.inputs['Vector'])
        if node.type=='TEX_COORD':
            for link in list(node.outputs['UV'].links):nodes.links.new(original.outputs['UV'],link.to_socket)
        if node.type=='GROUP' and node.node_tree:source_coordinates(node.node_tree)
for material in body.data.materials:
    if material and material.node_tree:source_coordinates(material.node_tree)
atlas_uv.active_render=True
atlas=bpy.data.images.new('Einar_game_albedo',width=2048,height=2048,alpha=False)
for material in body.data.materials:
    if not material or not material.use_nodes:continue
    for node in material.node_tree.nodes:node.select=False
    image=material.node_tree.nodes.new('ShaderNodeTexImage');image.image=atlas;image.select=True;material.node_tree.nodes.active=image
bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=4
bpy.context.scene.render.bake.use_pass_direct=False;bpy.context.scene.render.bake.use_pass_indirect=False;bpy.context.scene.render.bake.use_pass_color=True
cached=ROOT/'art_source/einar_game_albedo.png'
if cached.exists() and '--rebake' not in sys.argv:atlas=bpy.data.images.load(str(cached))
else:
    try:bpy.ops.object.bake(type='DIFFUSE',margin=4)
    except Exception as exc:print('BAKE_FAILED',exc,flush=True)
    atlas.filepath_raw=str(cached);atlas.file_format='PNG';atlas.save()
atlas.pack()
categories=[]
for face in body.data.polygons:
    name=body.data.materials[face.material_index].name.lower()
    categories.append(1 if any(k in name for k in ['metal','piston','rust']) else 2 if name.startswith('eyes') else 0)
body.data.materials.clear()
for name,metal,rough in [('Cloth and skin',0,.68),('Mechanical steel',.75,.43),('Optics',.05,.19)]:
    material=bpy.data.materials.new('Einar baked '+name);material.use_nodes=True
    shader=material.node_tree.nodes.get('Principled BSDF');shader.inputs['Roughness'].default_value=rough;shader.inputs['Metallic'].default_value=metal
    texture=material.node_tree.nodes.new('ShaderNodeTexImage');texture.image=atlas;material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color']);body.data.materials.append(material)
for face,category in zip(body.data.polygons,categories):face.material_index=category
body.data.uv_layers.active=atlas_uv;atlas_uv.active_render=True
for name in [uv.name for uv in body.data.uv_layers]:
    if name!='GameAtlas':body.data.uv_layers.remove(body.data.uv_layers[name])
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/animations/quaternius-ual1/AnimationLibrary_Godot_Standard.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');rig.animation_data_clear()
mannequin=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o!=body)
def worldbounds(obj):return [obj.matrix_world@Vector(c) for c in obj.bound_box]
target=worldbounds(body);reference=worldbounds(mannequin)
height=max(v.z for v in reference)-min(v.z for v in reference);factor=height/(max(v.z for v in target)-min(v.z for v in target))
minimum=min(v.z for v in target)
world_matrix=body.matrix_world.copy()
for vertex in body.data.vertices:vertex.co=(world_matrix@vertex.co-Vector((0,0,minimum)))*factor
body.matrix_world=Matrix.Identity(4)
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for group in list(body.vertex_groups):body.vertex_groups.remove(group)
transfer=body.modifiers.new('Game motion weights','DATA_TRANSFER');transfer.object=mannequin;transfer.use_vert_data=True;transfer.data_types_verts={'VGROUP_WEIGHTS'};transfer.vert_mapping='POLYINTERP_NEAREST'
bpy.ops.object.datalayout_transfer(modifier=transfer.name);bpy.ops.object.modifier_apply(modifier=transfer.name)
arm=body.modifiers.new('Game skeleton','ARMATURE');arm.object=rig;body.parent=rig
bpy.data.objects.remove(mannequin,do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/steel_einar_game.blend'))
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/residents/steel.glb'),export_format='GLB',use_selection=True,export_animations=False)
print('EINAR_GAME_EXPORTED',flush=True)
