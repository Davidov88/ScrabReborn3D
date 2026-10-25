import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='D:/GameDev/Projects/ScrapReborn3D/art_source/lr01_mechanical_arm.blend')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH')
points=[body.matrix_world@v.co for v in body.data.vertices]
print('ARM_BOUNDS',[(min(v[i] for v in points),max(v[i] for v in points)) for i in range(3)],flush=True)
print('GROUPS',[g.name for g in body.vertex_groups][:20],flush=True)
