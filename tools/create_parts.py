"""Reference-driven modular hard-surface geometry; rigid mechanical pivots exported to GLB."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
CAT=json.loads((ROOT/'data/catalog.json').read_text(encoding='utf8'))
OUT=ROOT/'assets/models/parts';OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name,color,metal=.6,rough=.42,emission=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
    return m

dark=mat('Rubber and joints',(.022,.028,.033),.25,.7)
steel=mat('Machined steel',(.24,.29,.32),.82,.3)
edge=mat('Worn alloy edges',(.5,.51,.48),.85,.36)
black=mat('Sensor glass',(.012,.022,.025),.3,.15)
brass=mat('Brass connectors',(.32,.19,.065),.75,.3)
palettes=[(.72,.73,.67),(.71,.64,.43),(.10,.13,.14),(.075,.085,.11),(.78,.76,.65),(.23,.25,.12),(.16,.20,.11),(.095,.13,.16),(.57,.57,.54),(.32,.27,.19),(.055,.065,.07),(.59,.63,.60)]
lights=[(.04,.52,.65),(.8,.38,.08),(.8,.06,.03),(.38,.15,.6),(.65,.48,.16),(.7,.38,.05),(.55,.12,.06),(.06,.35,.7),(.45,.1,.7),(.7,.4,.09),(.05,.4,.45),(.12,.55,.6)]

def empty(name,pos=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=pos;o.parent=parent;return o

def cube(name,pos,size,material,parent=None,bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Machined chamfer','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.append(material);o.parent=parent
    return o

def cyl(name,pos,radius,depth,material,parent=None,direction=(0,0,1),vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=pos)
    o=bpy.context.object;o.name=name;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector(direction).to_track_quat('Z','Y');o.data.materials.append(material);o.parent=parent
    mod=o.modifiers.new('Edge break','BEVEL');mod.width=.006;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons:p.use_smooth=True
    return o

def strut(a,b,r=.014,material=steel,parent=None):
    a,b=Vector(a),Vector(b);return cyl('Hydraulic line',(a+b)/2,r,(b-a).length,material,parent,b-a)

def bolts(parent,points):
    for x,y,z in points:cyl('Fastener',(x,y,z),.009,.009,edge,parent,(0,1,0),6)

def vents(parent,x,y,z,count=5,width=.16):
    for i in range(count):cube('Recessed vent',(x,y,z+i*.027),(width,.013,.009),dark,parent,bevel=.002)

def shell(name,pos,rings,material,parent,segments=16):
    """Elliptical stamped shell with a tapered silhouette, rather than a box."""
    vertices=[];faces=[]
    for z,rx,ry in rings:
        for j in range(segments):
            a=2*math.pi*j/segments
            vertices.append((rx*math.cos(a),ry*math.sin(a),z))
    for k in range(len(rings)-1):
        for j in range(segments):
            n=(j+1)%segments;a=k*segments
            faces.append((a+j,a+n,a+n+segments,a+j+segments))
    faces.extend([tuple(reversed(range(segments))),tuple((len(rings)-1)*segments+j for j in range(segments))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=pos;o.parent=parent;o.data.materials.append(material)
    bevel=o.modifiers.new('Stamped edge radius','BEVEL');bevel.width=.007;bevel.segments=2
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
    normals=o.modifiers.new('Panel normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=normals.name)
    return o

def torso(i,armor,glow,root):
    heavy=i in (3,6,7,8,10);w=.56 if heavy else .46
    shell('Tapered thoracic load frame',(0,0,0),[(-.24,.125,.10),(-.13,.16,.12),(.09,w*.48,.145),(.22,w*.40,.12)],dark,root)
    # Broad upper chest narrows toward the exposed segmented abdomen.
    shell('Upper sternum shell',(0,.015,0),[(.025,w*.38,.145),(.105,w*.49,.16),(.21,w*.42,.135),(.245,w*.28,.09)],armor,root)
    for sign in (-1,1):
        plate=shell('Split pectoral panel',(sign*w*.235,.07,.02),[(-.075,w*.17,.085),(.01,w*.235,.11),(.13,w*.20,.085)],armor,root,10)
        plate.rotation_euler.y=sign*-.12
        shell('Lateral rib armor',(sign*w*.29,.015,-.12),[(-.06,.065,.10),(.02,.085,.125),(.095,.075,.10)],armor,root,10)
        cyl('Shoulder socket',(sign*(w/2+.017),0,.12),.08,.07,steel,root,(1,0,0))
        cyl('Socket bearing',(sign*(w/2+.054),0,.12),.05,.008,dark,root,(1,0,0))
        cyl('Concentric shoulder ring',(sign*(w/2+.060),0,.12),.037,.012,edge,root,(1,0,0),24)
        cube('Rear scapular shell',(sign*w*.24,-.115,.10),(w*.40,.075,.24),armor,root,.035)
        strut((sign*.11,-.12,-.19),(sign*.17,-.12,.18),.016,steel,root)
    cube('Waist actuator',(0,0,-.245),(.27,.22,.12),dark,root,.025)
    for j,z in enumerate((-.20,-.15,-.10)):
        cube('Overlapping abdominal vertebra',(0,.125,z),(.16+j*.025,.07,.038),steel,root,.012)
    cube('Status spine',(0,.208,.11),(.025,.015,.18),glow,root,.005)
    cube('Dorsal service hatch',(0,-.151,.015),(.20,.035,.28),dark,root,.018)
    vents(root,0,-.174,-.07,6,.14)
    for s in (-1,1):
        for j in range(3):cube('Dorsal heat exchanger',(s*.085,-.18,-.17+j*.035),(.045,.03,.017),steel,root,.004)
    bolts(root,[(x,.202,z) for x in (-w*.35,w*.35) for z in (-.12,.02,.2)])
    cyl('Neck collar',(0,0,.29),.082,.06,dark,root)
    if i in (9,12):
        cyl('Reactor housing',(0,.19,-.015),.078,.045,steel,root,(0,1,0),20)
        cyl('Energy aperture',(0,.221,-.015),.048,.012,glow,root,(0,1,0),20)
    if i in (6,10):
        for s in (-1,1):strut((s*.21,-.12,-.2),(s*.22,-.12,.23),.027,brass,root)
    if i in (7,8):cube('Ballistic upper plate',(0,.17,.21),(.31,.12,.12),armor,root,.025)

def head(i,armor,glow,root):
    cyl('Neck articulation',(0,0,-.12),.055,.09,steel,root)
    wide=1.10 if i in (5,6) else 1.0
    shell('Cranial carapace',(0,0,0),[(-.115,.073,.083),(-.075,.108*wide,.114),(.01,.126*wide,.132),(.08,.12*wide,.123),(.135,.079,.083),(.15,.025,.03)],armor,root,24)
    mask=shell('Inset face shield',(0,.102,-.005),[(-.066,.064,.03),(-.015,.085,.041),(.052,.088,.037),(.074,.062,.024)],black,root,16)
    for x in (-.048,.048):
        strut((x,-.094,.075),(x,-.045,.137),.004,dark,root)
        cube('Crown panel seam',(x,.027,.139),(.004,.11,.006),dark,root,.001)
    shell('Jaw guard',(0,.067,-.075),[(-.042,.054,.033),(-.015,.077,.048),(.013,.085,.041)],armor,root,12)
    if i in (1,3,5):
        cube('Optical sensor slit',(0,.143,.04),(.135,.009,.018),glow,root,.005)
    else:
        for x in (-.052,.052):
            cyl('Camera housing',(x,.14,.045),.034,.025,dark,root,(0,1,0),16)
            cyl('Optical lens',(x,.156,.045),.021,.008,glow,root,(0,1,0),16)
    for s in (-1,1):
        cyl('Aural scanner',(s*.126,-.018,.025),.058,.025,dark,root,(1,0,0),16)
        cyl('Bearing inset',(s*.142,-.018,.025),.032,.006,steel,root,(1,0,0),16)
    vents(root,0,-.122,-.055,4,.085)
    if i in (2,4):cyl('Comms mast',(.08,-.055,.18),.008,.15,steel,root)
    if i==6:
        for s in (-1,1):strut((s*.07,-.1,.08),(s*.12,-.14,.19),.012,glow,root)
    bolts(root,[(x,.12,z) for x in (-.09,.09) for z in (-.075,.1)])

def arm(i,armor,glow,root):
    heavy=i in (3,11);r=.085 if heavy else .064
    cyl('Shoulder bearing',(0,0,0),r+.015,.14,steel,root,(1,0,0),16)
    upper=empty('UpperArm',parent=root)
    shell('Deltoid shell',(0,0,0),[(-.095,r*.95,.075),(-.025,r*1.3,.09),(.045,r*1.05,.075)],armor,upper,16)
    shell('Upper arm clamshell',(0,.012,0),[(-.24,r*.70,.056),(-.17,r*.9,.068),(-.10,r*.8,.063)],armor,upper,12)
    for s in (-1,1):strut((s*r*.72,-.048,-.09),(s*r*.72,-.048,-.25),.009,steel,upper)
    strut((-.034,-.06,-.03),(-.034,-.06,-.24),.013,steel,upper)
    cyl('Elbow',(0,0,-.285),r*.78,.14,dark,upper,(1,0,0))
    fore=empty('Forearm',(0,0,-.285),upper)
    shell('Forearm tapered clamshell',(0,0,0),[(-.235,r*.66,.05),(-.16,r*.99,.078),(-.055,r*1.12,.081),(-.025,r*.78,.059)],armor,fore,12)
    cyl('Elbow bearing cover',(.077,0,0),r*.64,.018,armor,fore,(1,0,0),20)
    cyl('Elbow bearing centre',(.088,0,0),r*.28,.009,edge,fore,(1,0,0),16)
    strut((-.04,-.055,-.025),(-.04,-.055,-.22),.012,steel,fore)
    cyl('Wrist coupler',(0,0,-.245),.043,.035,steel,fore)
    cube('Diagnostic strip',(.04,.079,-.10),(.014,.008,.09),glow,fore,.003)
    vents(fore,0,-.08,-.19,4,.09)
    bolts(fore,[(x,.08,z) for x in (-.045,.045) for z in (-.04,-.19)])
    gun=i in (5,6,8,9,10,12)
    if gun:
        length={5:.25,6:.49,8:.27,9:.24,10:.25,12:.32}[i]
        cube('Integrated receiver',(0,.08,-.23),(.13,.18,.13),dark,fore,.015)
        barrels=2 if i==10 else 1
        for j in range(barrels):
            x=(j-(barrels-1)/2)*.07
            cyl('Barrel shroud',(x,.16+length/2,-.23),.036,length,steel,fore,(0,1,0),12)
            cyl('Muzzle',(x,.17+length,-.23),.042,.05,dark,fore,(0,1,0),12)
            cyl('Bore',(x,.197+length,-.23),.02,.004,glow if i in (8,9,12) else black,fore,(0,1,0),12)
        if i in (9,12):
            for j in range(4):cyl('Induction ring',(0,.2+j*.05,-.23),.055,.017,glow,fore,(0,1,0),16)
    elif i==4:
        shield=cube('Ballistic shield',(0,.16,-.16),(.33,.08,.64),armor,fore,.035)
        for z in (-.38,-.2,-.02):cube('Shield rib',(0,.21,z),(.32,.025,.026),steel,fore,.005)
        cube('Shield optical window',(0,.207,.035),(.16,.008,.045),glow,fore,.006)
    elif i==11:
        for s in (-1,1):
            cube('Claw prong',(s*.08,.06,-.31),(.045,.12,.22),steel,fore,.012)
            strut((s*.04,0,-.12),(s*.08,.03,-.3),.02,brass,fore)
    elif i==7:
        for x in (-.04,0,.04):strut((x,.02,-.23),(x,.14,-.36),.012,steel,fore)
        cube('Hack interface',(0,.09,-.19),(.095,.055,.08),glow,fore,.008)
    else:
        cube('Palm',(0,.01,-.28),(.11 if not heavy else .16,.09,.11),dark,fore,.016)
        for x in (-.035,0,.035):
            cube('Articulated finger',(x,.025,-.36),(.024,.038,.075),steel,fore,.007)
        cube('Thumb',(-.075,.025,-.29),(.035,.04,.075),armor,fore,.008)

def legs(i,armor,glow,root):
    heavy=i in (5,6,9,12);spread=.14 if not heavy else .18
    cube('Pelvic carrier',(0,0,0),(.34,.23,.17),dark,root,.025)
    for s,label in [(-1,'Left'),(1,'Right')]:
        leg=empty(label+'Thigh',(s*spread,0,-.035),root)
        cyl('Hip bearing',(0,0,0),.077,.10,steel,leg,(1,0,0),16)
        shell('Femoral armor',(0,0,0),[(-.30,.055 if not heavy else .08,.06),(-.21,.077 if not heavy else .10,.085),(-.07,.073 if not heavy else .095,.075)],armor,leg,12)
        strut((s*.055,-.07,-.04),(s*.055,-.07,-.3),.016,steel,leg)
        shin=empty(label+'Shin',(0,0,-.34),leg)
        cyl('Knee bearing',(0,0,0),.062,.15,dark,shin,(1,0,0),16)
        cube('Knee armor',(0,.087,0),(.115,.07,.10),armor,shin,.02)
        shell('Tibial tapered armor',(0,.015,0),[(-.30,.055 if not heavy else .08,.065),(-.21,.068 if not heavy else .10,.085),(-.065,.07 if not heavy else .10,.085)],armor,shin,12)
        for s2 in (-1,1):strut((s2*.05,-.055,-.06),(s2*.05,-.055,-.29),.009,steel,shin)
        cube('Running diagnostic',(s*.045,.1,-.16),(.018,.008,.12),glow,shin,.003)
        cyl('Ankle joint',(0,0,-.32),.05,.12,steel,shin,(1,0,0))
        cube('Armored foot',(0,.075,-.38),(.15 if not heavy else .22,.31,.115),armor,shin,.025)
        cube('Traction sole',(0,.075,-.438),(.16 if not heavy else .23,.32,.02),dark,shin,.005)
        for j in range(3):cube('Toe reinforcement',((j-1)*.045,.216,-.37),(.035,.05,.07),steel,shin,.007)
        if heavy:strut((s*.085,-.06,-.04),(s*.085,-.07,-.28),.022,brass,shin)
        if i==11:cyl('Jump spring',(s*.06,-.10,-.15),.027,.25,steel,shin)
        bolts(shin,[(x,.1,z) for x in (-.045,.045) for z in (-.08,-.25)])

def merge_mesh_children(root):
    # Join by mechanical parent: a handful of draw nodes instead of hundreds of bolts.
    parents=[root]+[o for o in root.children_recursive if o.type=='EMPTY']
    for parent in parents:
        meshes=[o for o in parent.children if o.type=='MESH']
        if len(meshes)<2:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in meshes:o.select_set(True)
        bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
        meshes[0].name=parent.name+'_Geometry'

for v in CAT['visuals']:
    i=v['index'];group=v['id'].split('_')[0]
    palette_index=({'arms':[0,1,5,2,2,4,3,5,2,2,5,8],'heads':[0,1,2,3,4,8],'torsos':list(range(12)),'legs':[0,1,2,2,5,9,10,2,6,4,3,8]}[group])[i-1]
    armor=mat(v['id']+' armor',palettes[palette_index],.18,.43)
    glow=mat(v['id']+' indicators',lights[palette_index],.3,.25,.45)
    root=empty(v['id'])
    {'torsos':torso,'heads':head,'arms':arm,'legs':legs}[group](i,armor,glow,root)
    merge_mesh_children(root)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for obj in root.children_recursive:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(v['id']+'.glb')),use_selection=True,export_format='GLB',export_extras=True)
    print('PART_EXPORTED',v['id'],flush=True)
    # Keep source layout separated for inspection without changing exported origins.
    root.location=((i-1)%4*1.1,{'arms':0,'heads':2,'torsos':4,'legs':6}[group]+(i-1)//4*.9,1)

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/modular_equipment.blend'))
print('ALL_42_PARTS_EXPORTED',flush=True)
