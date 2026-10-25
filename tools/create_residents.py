"""Prepare CC0 MakeHuman bodies/clothes on Quaternius' CC0 game skeleton.
All sources and Blender intermediate files stay on D. No character preview art.
"""
import sys,os,json,zipfile,hashlib
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
DOWNLOAD=Path('D:/GameDev/asset-downloads/lowgrid')
MPFB=DOWNLOAD/'mpfb/mpfb2-2.0.18/src'
DATA=DOWNLOAD/'makehuman-system'
DATA.mkdir(exist_ok=True)
if not (DATA/'skins').exists():
    with zipfile.ZipFile(DOWNLOAD/'makehuman_system_assets_cc0.zip') as archive:archive.extractall(DATA)
sys.path.insert(0,str(MPFB))
bpy.utils.extension_path_user=lambda *a,**k:str(DOWNLOAD/'mpfb-user')
import mpfb
mpfb.get_preference=lambda key: {"mpfb_user_data":str(DOWNLOAD/'mpfb-user'),"mpfb_second_root":str(DATA),"mpfb_shelf_label":"MPFB","mpfb_logging_level":"WARN"}.get(key,None)
mpfb.register()
from mpfb.services.humanservice import HumanService
from mpfb.services.targetservice import TargetService
from mpfb.services.exportservice import ExportService
from mpfb.entities.objectproperties import HumanObjectProperties

OUT=ROOT/'assets/models/residents';OUT.mkdir(exist_ok=True)
def find(name):
    candidates=list(DATA.rglob(name))
    return str(candidates[0]) if candidates else None

def prepare(identity,gender,age,skin,clothing,hair):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    body=HumanService.create_human()
    for key,value in [('gender',gender),('age',age),('muscle',.48),('weight',.48)]:
        HumanObjectProperties.set_value(key,value,entity_reference=body)
    TargetService.reapply_macro_details(body)
    HumanService.add_builtin_rig(body,'game_engine')
    skin_path=find(skin)
    if skin_path:HumanService.set_character_skin(skin_path,body,skin_type='GAMEENGINE')
    for fname,kind in [('low-poly.mhclo','Eyes'),('eyebrow001.mhclo','Eyebrows'),('teeth_base.mhclo','Teeth'),(hair,'Hair'),(clothing,'Clothes')]:
        path=find(fname)
        if path:HumanService.add_mhclo_asset(path,body,asset_type=kind,material_type='GAMEENGINE')
        else:print('ASSET_MISSING',fname)
    # Preserve MPFB's anatomical skin weights and rig clothing with its asset system.
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for obj in meshes:
        bpy.context.view_layer.objects.active=obj
        obj.select_set(True)
        if obj.data.shape_keys:
            bpy.ops.object.shape_key_remove(all=True,apply_mix=True)
        for modifier in list(obj.modifiers):
            if modifier.type=='MASK':bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    rig.animation_data_clear()
    rig.name='LowGridRig'
    height=max((body.matrix_world@Vector(c)).z for c in body.bound_box)-min((body.matrix_world@Vector(c)).z for c in body.bound_box)
    rig.scale*=({'leya':1.75,'mira':1.72,'yan':1.81,'steel':1.86}[identity]/max(height,.1))
    # Limit textures to 1K for this hardware target and embed into game GLB.
    for image in bpy.data.images:
        if image.size[0]>1024 or image.size[1]>1024:
            ratio=1024/max(image.size);image.scale(max(1,int(image.size[0]*ratio)),max(1,int(image.size[1]*ratio)))
        if image.source=='FILE':image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source'/('resident_'+identity+'.blend')))
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
    for obj in meshes:obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/(identity+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
    print('RESIDENT_EXPORTED',identity,flush=True)

specs=[
 ('leya',0,.32,'young_caucasian_female.mhmat','female_casualsuit01.mhclo','ponytail01.mhclo'),
 ('mira',0,.28,'young_asian_female.mhmat','female_casualsuit01.mhclo','bob01.mhclo'),
 ('yan',1,.78,'old_caucasian_male.mhmat','male_casualsuit01.mhclo','short01.mhclo'),
 ('steel',1,.65,'middleage_caucasian_male.mhmat','male_casualsuit01.mhclo','short02.mhclo')]
for spec in specs:
    if spec[0]=='steel' and '--keep-einar' in sys.argv:continue
    prepare(*spec)
for i in range(4):
    import shutil
    shutil.copy2(OUT/('mira.glb' if i%2 else 'yan.glb'),OUT/('resident_'+str(i)+'.glb'))
