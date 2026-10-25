"""Retarget CC0 KayKit locomotion onto the adult Quaternius game rig; no root motion."""
import bpy,math
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/animations/quaternius-ual1/AnimationLibrary_Godot_Standard.glb'))
target=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');target.name='Rig';target.animation_data_clear()
old=set(bpy.data.objects);old_actions=set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/animations/kaykit/Rig_Medium_MovementAdvanced.glb'))
source=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE' and o!=target)
actions=[a for a in bpy.data.actions if a not in old_actions]
for action in list(bpy.data.actions):
    if action not in actions:bpy.data.actions.remove(action)
mapping={'DEF-hips':'hips','DEF-spine.001':'spine','DEF-spine.002':'chest','DEF-spine.003':'chest','DEF-head':'head'}
for side in ['L','R']:
    for adult,kay in [('upper_arm','upperarm'),('forearm','lowerarm'),('hand','hand'),('thigh','upperleg'),('shin','lowerleg'),('foot','foot'),('toe','toes')]:mapping['DEF-'+adult+'.'+side]=kay+'.'+side.lower()
height=target.data.bones['DEF-hips'].head_local.z/max(.01,source.data.bones['hips'].head_local.z)
outputs=[]
for original in actions:
    name=original.name.split('|')[-1]
    if name=='T-Pose':continue
    source.animation_data_create();source.animation_data.action=original
    if original.slots:source.animation_data.action_slot=original.slots[0]
    clip=bpy.data.actions.new('KK_'+name);target.animation_data_create();target.animation_data.action=clip
    first,last=map(int,original.frame_range)
    for frame in range(first,last+1):
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();desired={}
        for bone in target.data.bones:
            parent=bone.parent
            rest=bone.matrix_local.to_3x3()
            local_rest=(parent.matrix_local.inverted()@bone.matrix_local).to_3x3() if parent else rest
            previous=desired[parent.name] if parent else Matrix.Identity(3)
            key=mapping.get(bone.name)
            if key and key in source.pose.bones:
                source_rest=source.data.bones[key].matrix_local.to_3x3()
                source_pose=source.pose.bones[key].matrix.to_3x3().normalized()
                correction=rest.col[1].rotation_difference(source_rest.col[1]).to_matrix()
                orientation=source_pose@source_rest.inverted()@correction@rest
            else:orientation=previous@local_rest
            desired[bone.name]=orientation
            pose=target.pose.bones[bone.name];pose.rotation_mode='QUATERNION'
            pose.rotation_quaternion=(local_rest.inverted()@previous.inverted()@orientation).to_quaternion()
            pose.location=(0,0,0);pose.scale=(1,1,1)
            if bone.name=='DEF-hips':
                displacement=source.pose.bones['hips'].matrix.translation-source.data.bones['hips'].head_local
                displacement.x=0;displacement.y=0
                pose.location=rest.inverted()@(displacement*height)
            pose.keyframe_insert('rotation_quaternion',frame=frame-first)
            if bone.name=='DEF-hips':pose.keyframe_insert('location',frame=frame-first)
    outputs.append(clip);print('RETARGETED',clip.name,first,last,flush=True)
target.animation_data_clear()
for obj in list(bpy.data.objects):
    if obj not in old:bpy.data.objects.remove(obj,do_unlink=True)
for action in actions:bpy.data.actions.remove(action)
for clip in outputs:clip.use_fake_user=True
target.animation_data_create();target.animation_data.action=outputs[0];target.animation_data.action_slot=outputs[0].slots[0]
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/kaykit_adult_motion.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/animations/kaykit_adapted.glb'),export_format='GLB',export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_single_armature=True)
print('KAYKIT_RETARGET_COMPLETE',len(outputs),flush=True)
