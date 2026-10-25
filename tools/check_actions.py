import bpy
bpy.ops.wm.open_mainfile(filepath='D:/GameDev/Projects/ScrapReborn3D/art_source/kaykit_adult_motion.blend')
for action in bpy.data.actions:
    print('ACTION',action.name,tuple(action.frame_range),'slots',[(s.identifier,s.target_id_type) for s in action.slots],flush=True)
for p in bpy.ops.export_scene.gltf.get_rna_type().properties:
    if 'anim' in p.identifier:print('OPTION',p.identifier,str(p.default) if hasattr(p,'default') else '',flush=True)
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.animation_data_create();rig.animation_data.action=list(bpy.data.actions)[0]
rig.animation_data.action_slot=rig.animation_data.action.slots[0]
bpy.ops.export_scene.gltf(filepath='D:/GameDev/Projects/ScrapReborn3D/assets/animations/kaykit_adapted.glb',export_format='GLB',export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_single_armature=True)
