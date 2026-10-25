"""Distinctive drone hardware, service modules and non-firearm held tools."""
import bpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/models/devices';OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color,metal=.65,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.46
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
steel=mat('Steel',(.17,.21,.23));dark=mat('Rubber',(.025,.032,.035),.2);armor=mat('Industrial paint',(.22,.26,.23));brass=mat('Contacts',(.47,.3,.1));glow=mat('Status',(.04,.45,.57),.3,2);copper=mat('Heat exchanger',(.32,.14,.07));orange=mat('Tool paint',(.47,.25,.07))
def box(pos,size,m):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m);mod=o.modifiers.new('Chamfer','BEVEL');mod.width=min(min(size)/4,.025);mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name);return o
def cyl(pos,r,d,m,axis=(0,0,1),vertices=16):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d,location=pos);o=bpy.context.object;o.data.materials.append(m);o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector(axis).to_track_quat('Z','Y');return o
def export(name):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True)
 for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
for kind in ['cpu','controller','memory','comm_module','adapter','power_core','cooling','drone_engine','drone_body']:
 box((0,0,0),(.23,.16,.035),dark)
 for x in [-.095,.095]:
  for y in [-.06,.06]:cyl((x,y,.025),.009,.012,steel,vertices=6)
 if kind in ('cpu','controller','memory','adapter','comm_module'):
  box((0,0,.03),(.12,.10,.035),steel)
  for i in range(10):box((-.1+i*.021,-.085,.002),(.012,.025,.009),brass)
  box((.065,.055,.03),(.04,.012,.014),glow)
  if kind in ('cpu','controller'):
   for i in range(8):box((-.05+i*.014,0,.06),(.006,.1,.024),steel)
  if kind=='memory':
   for x in [-.065,0,.065]:box((x,0,.03),(.045,.065,.02),dark)
  if kind=='comm_module':cyl((.07,.04,.12),.006,.20,steel)
 elif kind=='power_core':
  for x in [-.07,0,.07]:cyl((x,0,.08),.03,.12,steel)
  box((0,0,.15),(.22,.07,.025),orange);box((0,.043,.15),(.08,.006,.012),glow)
 elif kind=='cooling':
  for i in range(12):box((-.1+i*.018,0,.07),(.008,.16,.1),copper)
 else:
  cyl((0,0,.07),.1,.08,steel);cyl((0,0,.12),.065,.02,dark)
  for i in range(8):
   blade=box((0,0,.135),(.16,.018,.008),armor);blade.rotation_euler.z=i*math.pi/8
 export('internal_'+kind)
for heavy in (False,True):
 box((0,0,0),(.56 if heavy else .42,.42,.18),armor)
 box((0,.1,.09),(.3,.20,.12),steel)
 for s in (-1,1):
  x=s*(.43 if heavy else .35)
  box((s*.25,0,0),(.30,.09,.055),steel)
  for z in [-.05,.05]:
   bpy.ops.mesh.primitive_torus_add(major_radius=.19,minor_radius=.025,major_segments=24,minor_segments=6,location=(x,0,z));bpy.context.object.data.materials.append(steel)
  cyl((x,0,0),.055,.1,dark)
  for j in range(6):
   blade=box((x,0,0),(.31,.03,.015),armor);blade.rotation_euler.z=j*math.pi/6
  for y in [-.12,.12]:cyl((x,y,.06),.012,.015,brass,vertices=6)
 for x in [-.08,.08]:cyl((x,.225,0),.035,.035,dark,(0,1,0));cyl((x,.248,0),.021,.008,glow,(0,1,0))
 if heavy:
  box((0,.02,-.14),(.18,.3,.09),dark);cyl((0,.25,-.14),.04,.32,steel,(0,1,0));cyl((0,.42,-.14),.047,.04,dark,(0,1,0))
 for y in [-.17,-.13,-.09,-.05]:box((0,y,.11),(.23,.015,.012),dark)
 export('drone_E06' if heavy else 'drone_E05')
for kind in ('pipe','knife','baton','cutter','saw'):
 # Tool origin is at the gripping hand; forward points +Y in Blender / -Z in Godot.
 if kind=='pipe':
  cyl((0,.20,0),.027,.7,steel,(0,1,0));cyl((0,.50,0),.038,.05,copper,(0,1,0));cyl((0,-.09,0),.035,.15,dark,(0,1,0))
 elif kind=='knife':
  box((0,0,0),(.035,.15,.04),dark);box((0,.09,0),(.11,.02,.06),steel)
  blade=box((0,.23,0),(.055,.27,.007),steel);blade.rotation_euler.z=.12
 elif kind=='baton':
  cyl((0,.17,0),.035,.5,dark,(0,1,0));cyl((0,-.08,0),.045,.15,dark,(0,1,0))
  for y in [.1,.16,.22,.28,.34]:cyl((0,y,0),.042,.016,glow,(0,1,0))
 elif kind=='cutter':
  box((0,.1,0),(.14,.22,.1),orange);box((0,-.04,-.05),(.07,.14,.09),dark);cyl((0,.29,0),.032,.2,steel,(0,1,0));cyl((0,.395,0),.024,.012,glow,(0,1,0))
 else:
  box((0,.08,0),(.14,.2,.12),orange);cyl((0,.29,0),.14,.025,steel,(1,0,0),32)
  for j in range(16):
   a=j*math.pi/8;tooth=box((0,.29+math.sin(a)*.14,math.cos(a)*.14),(.03,.025,.035),copper);tooth.rotation_euler.x=-a
 export('held_'+kind)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/device_sources.blend'))
print('DEVICES_EXPORTED')
