class_name ScrapWorld
extends Node3D

var game: Node3D
var interactions: Array = []
var walls: Array = []
var props: Array = []
var materials = {}
var navigation: NavigationRegion3D
var nav_mesh_vertices=PackedVector3Array()
var nav_mesh_faces=PackedInt32Array()
var batch_candidates: Array=[]

func material(color: Color,metal: float=.55,rough: float=.65) -> StandardMaterial3D:
	var key=str(color)+str(metal)
	if materials.has(key):return materials[key]
	var m=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=rough;materials[key]=m;return m

func box(pos: Vector3,size: Vector3,color: Color,solid: bool=true,occluder: bool=false) -> Node3D:
	var root=StaticBody3D.new() if solid else Node3D.new()
	if solid:root.collision_layer=1;root.collision_mask=2
	root.position=pos;add_child(root)
	var mesh=MeshInstance3D.new();var shape=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.material_override=material(color);root.add_child(mesh)
	if (size.y<.5 and size.x>6) or (size.y>2.8 and maxf(size.x,size.z)>4):
		var ident="Concrete034"
		var path="res://assets/materials/"+ident+"/"+ident+"_1K-JPG_"
		if ResourceLoader.exists(path+"Color.jpg"):
			var pbr=material(color).duplicate();pbr.albedo_texture=load(path+"Color.jpg");pbr.normal_enabled=true;pbr.normal_texture=load(path+"NormalGL.jpg");pbr.normal_scale=.28;pbr.roughness_texture=load(path+"Roughness.jpg");pbr.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
			pbr.uv1_scale=Vector3(size.x/2,size.z/2,1) if size.y<.5 else Vector3(maxf(size.x,size.z)/2,size.y/2,1)
			if ident=="Metal040":pbr.metallic=.22;pbr.metallic_texture=load(path+"Metalness.jpg");pbr.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
			else:pbr.metallic=.05
			pbr.roughness=.95
			mesh.material_override=pbr
	if solid:
		var cs=CollisionShape3D.new();var bs=BoxShape3D.new();bs.size=size;cs.shape=bs;root.add_child(cs)
	if occluder:walls.append(mesh)
	if not solid and not occluder:batch_candidates.append(mesh)
	return root

func strip(pos: Vector3,size: Vector3,color: Color):
	var n=box(pos,size,color,false)
	var m=material(color).duplicate();m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=1.4
	n.get_child(0).material_override=m

func ceiling_fixture(pos: Vector3,warm: bool=false):
	# Housing, diffuser and real light share the same mounting point.
	box(pos+Vector3(0,.07,0),Vector3(.55,.16,1.5),Color("11191c"),false)
	for x in [-.27,.27]:box(pos+Vector3(x,-.025,0),Vector3(.035,.06,1.5),Color("6b6c62"),false)
	var tint=Color("ffdab0") if warm else Color("c9e1e5")
	strip(pos+Vector3(0,-.025,0),Vector3(.42,.025,1.35),tint)
	var lamp=SpotLight3D.new();lamp.position=pos+Vector3(0,-.16,0);lamp.rotation.x=-PI/2;lamp.light_color=tint;lamp.light_energy=8.0;lamp.spot_range=11;lamp.spot_angle=74;lamp.spot_attenuation=1.0;lamp.spot_angle_attenuation=.65;lamp.shadow_enabled=pos.x<0 and posmod(int(pos.z)-1,14)==0;add_child(lamp)
	lamp.distance_fade_enabled=true;lamp.distance_fade_begin=17;lamp.distance_fade_length=7;lamp.distance_fade_shadow=12

func prop(file: String,pos: Vector3,height: float=1.0,angle: float=0.0) -> Node3D:
	var path="res://assets/models/"+(file if "/" in file else "space-station-kit/"+file)+".glb"
	if not ResourceLoader.exists(path):return Node3D.new()
	var scene=ScrapRobotVisual.model_cache.get(path)
	if scene==null:scene=load(path);ScrapRobotVisual.model_cache[path]=scene
	var n=scene.instantiate();add_child(n);n.position=pos;n.rotation.y=angle
	var bounds=AABB()
	for child in all_children(n):
		if child is MeshInstance3D:
			bounds=bounds.merge((n.global_transform.affine_inverse()*child.global_transform)*child.get_aabb())
			for surface in range(child.mesh.get_surface_count()):
				var source_material=child.get_active_material(surface)
				if source_material is StandardMaterial3D:
					var adjusted=source_material.duplicate();adjusted.albedo_color=Color(.34,.38,.37);adjusted.roughness=.72;adjusted.metallic=.45;child.set_surface_override_material(surface,adjusted)
	var factor=height/maxf(bounds.size.y,.1)
	n.scale=Vector3.ONE*factor
	props.append(n)
	return n

func all_children(n: Node) -> Array:
	var list=[]
	for c in n.get_children():list.append(c);list.append_array(all_children(c))
	return list

func plaque(text: String,pos: Vector3,size: int=32,color: Color=Color("b8b4a3")) -> Label3D:
	var l=Label3D.new();l.text=text;l.font_size=size;l.pixel_size=.009;l.position=pos;l.modulate=color;l.no_depth_test=false;add_child(l);return l

func interaction(id: String,kind: String,pos: Vector3,title: String,data: Dictionary={}) -> Dictionary:
	var item={"id":id,"kind":kind,"position":[pos.x,pos.y,pos.z],"title":title,"data":data,"used":false}
	var model="factory-kit/machine-window" if kind=="terminal" else "factory-kit/machine-bed" if kind=="bench" else "factory-kit/door-wide-open" if kind=="exit" else "factory-kit/box-large"
	var n=prop(model,pos,1.2 if kind=="terminal" else 2.3 if kind=="exit" else .85)
	if kind=="bench":prop("factory-kit/robot-arm-a",pos+Vector3(.5,.7,.1),1.0)
	if kind=="terminal":prop("factory-kit/screen-panel-wide",pos+Vector3(0,.9,-.05),.4)
	item.node=n
	var sign=plaque(title+"\n[E]",pos+Vector3(0,1.7,0),24)
	sign.pixel_size=.0028
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;item.label=sign
	interactions.append(item)
	return item

func build(g: Node3D,index: int,training: bool=false):
	game=g
	var sector=ScrapCampaign.SECTORS[index]
	var accent=Color(sector.accent)
	var floor_color=Color("687172")
	# Compatibility limits lights per mesh; short floor sections receive their local fixtures.
	for tile in range(18):box(Vector3(0,-.2,1.5-tile*6),Vector3(14,.4,6),floor_color)
	# Slab seams, cable runs and guidance markings keep the architecture readable.
	for z in range(2,-105,-3):
		box(Vector3(0,.006,z),Vector3(13.7,.012,.025),Color("10181d"),false)
		for x in [-5.7,5.7]:
			box(Vector3(x,.012,z-1),Vector3(.42,.015,2.8),Color("171e22"),false)
			strip(Vector3(x,.026,z-1),Vector3(.045,.012,1.4),accent*.5)
		for x in [-2,2]:box(Vector3(x,.013,z-1),Vector3(.035,.012,1.0),Color("5c5e55"),false)
	for z in range(3,-105,-5):
		for x in [-7.2,7.2]:
			if x>0 and z in range(-55,-44):continue
			box(Vector3(x,1.7,z),Vector3(.35,3.4,4.9),Color("323b3f"),true,true)
			box(Vector3(x-0.20*signf(x),.4,z),Vector3(.08,.5,4.8),Color("111a1e"),false)
			box(Vector3(x-0.20*signf(x),2.7,z),Vector3(.10,.06,4.6),accent*.6,false)
	box(Vector3(0,1.7,5),Vector3(14.7,3.4,.3),Color("343d40"),true,true)
	box(Vector3(0,1.7,-104),Vector3(14.7,3.4,.3),Color("343d40"),true,true)
	for z in [-12,-37,-67,-96]:
		for x in [-6.3,6.3]:
			box(Vector3(x,1.5,z),Vector3(.65,3,.8),Color("1a2429"),true,true)
			strip(Vector3(x-signf(x)*.34,2.5,z),Vector3(.05,.30,.35),accent)
		box(Vector3(0,3.25,z),Vector3(13.0,.35,.7),Color("263136"),false,true)
	for z in [-20,-50,-80]:
		for s in [-1,1]:
			var x=s*4.1
			var file="container-tall" if index in [0,1] else "computer-system" if index==3 else "container-wide"
			prop(file,Vector3(x,0,z+3),1.8,index*.5)
			box(Vector3(x,.65,z+3),Vector3(1.4,1.3,1.2),Color("303a3f"),true,false).get_child(0).visible=false
			prop("container",Vector3(x+s*.9,0,z-3),.8)
			prop("computer-screen",Vector3(s*6.9,1.5,z),.6,s*PI/2)
	for z in range(1,-103,-7):
		for x in [-3.8,3.8]:ceiling_fixture(Vector3(x,3.0,z),index in [0,1,4])
	ceiling_fixture(Vector3(12,3,-49),true)
	# Optional maintenance room, a full-height opening in the east wall.
	box(Vector3(12,-.2,-50),Vector3(10,.4,12),floor_color)
	box(Vector3(17,1.7,-50),Vector3(.3,3.4,12),Color("2c363b"),true,true)
	for z in [-44,-56]:box(Vector3(12,1.7,z),Vector3(10,3.4,.25),Color("2c363b"),true,true)
	prop("computer-system",Vector3(15,0,-54),1.4)
	for z in [-15,-45,-75]:
		if index in [1,4]:
			for x in [-3,3]:
				prop("factory-kit/conveyor-long-stripe-sides",Vector3(x,0,z),.65)
				box(Vector3(x,.28,z),Vector3(1.4,.5,6),Color("313737"),true).get_child(0).visible=false
			prop("factory-kit/crane-magnet",Vector3(4.6,1.7,z-2),1.5)
		if index in [0,1,4]:
			prop("factory-kit/box-large",Vector3(-5,0,z-5),.85)
			prop("factory-kit/box-wide",Vector3(5.8,0,z+5),.6)
		if index==3:
			for x in [-5.8,5.8]:
				for offset in [-2,0,2]:
					box(Vector3(x,1,z+offset),Vector3(.65,2.0,1.2),Color("16242d"),true)
					for y in [.4,.7,1,1.3,1.6]:strip(Vector3(x-signf(x)*.34,y,z+offset),Vector3(.015,.03,.7),Color("4c8994"))
	interaction("bench_start","bench",Vector3(-4,0,0),"РЕМОНТНАЯ СТАНЦИЯ")
	interaction("bench_mid","bench",Vector3(13,0,-48),"СЕРВИСНЫЙ ВЕРСТАК")
	for i in range(3):
		interaction("terminal_"+str(i),"terminal",Vector3(-5.7,0,-22-i*30),sector.objectives[i],{"objective":i,"text":sector.texts[i]})
	interaction("cache_optional","cache",Vector3(14,0,-51),"ТЕХНИЧЕСКОЕ ХРАНИЛИЩЕ",{"partition":index})
	interaction("cache_supply","supply",Vector3(4.9,0,-6),"РЕЗЕРВ СНАРЯЖЕНИЯ")
	interaction("exit","exit",Vector3(0,0,-100),"ГРУЗОВОЙ ШЛЮЗ")
	if index>0:interaction("return","return",Vector3(0,0,3),"ОБРАТНЫЙ СЕРВИСНЫЙ МАРШРУТ")
	strip(Vector3(0,.02,-100),Vector3(3,.02,2),accent)
	var entrance_sign=plaque("S-%02d  /  SERVICE ACCESS" % (index+1),Vector3(0,2.6,4.7),24,accent)
	entrance_sign.pixel_size=.003
	entrance_sign.rotation.y=PI
	for i in range(3):plaque("КОНТУР 0%d" % (i+1),Vector3(0,2.8,-29-i*30),36,accent)
	if training:
		interaction("training_catalog","catalog",Vector3(4,0,0),"ИСПЫТАТЕЛЬНЫЙ КАТАЛОГ")
	batch_static_details()
	build_navigation()

func batch_static_details():
	var groups={}
	for mesh in batch_candidates:
		var mat=mesh.material_override
		var key=str(mesh.mesh.size)+str(mat.albedo_color)+str(mat.emission_enabled)
		if not groups.has(key):groups[key]=[]
		groups[key].append(mesh)
	for group in groups.values():
		if group.size()<3:continue
		var renderer=MultiMeshInstance3D.new();var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=group[0].mesh;batch.instance_count=group.size();renderer.multimesh=batch;renderer.material_override=group[0].material_override;add_child(renderer)
		for i in range(group.size()):
			batch.set_instance_transform(i,group[i].get_parent().transform*group[i].transform)
			group[i].visible=false

func build_navigation():
	navigation=NavigationRegion3D.new()
	var mesh=NavigationMesh.new();mesh.agent_radius=.4;mesh.agent_height=1.8
	var vertices=PackedVector3Array([Vector3(-6.8,.03,4),Vector3(6.8,.03,4),Vector3(6.8,.03,-103),Vector3(-6.8,.03,-103),Vector3(6.8,.03,-44),Vector3(16.7,.03,-44),Vector3(16.7,.03,-56),Vector3(6.8,.03,-56)])
	mesh.set_vertices(vertices);mesh.add_polygon(PackedInt32Array([0,1,2,3]));mesh.add_polygon(PackedInt32Array([4,5,6,7]));navigation.navigation_mesh=mesh;add_child(navigation)

func near(pos: Vector3) -> Dictionary:
	var best={};var distance=2.6
	for x in interactions:
		if x.used and x.kind not in ["bench","catalog","exit"]:continue
		var p=Vector3(x.position[0],x.position[1],x.position[2])
		var d=Vector2(p.x-pos.x,p.z-pos.z).length()
		if d<distance:distance=d;best=x
	return best

func update_occlusion(top: bool,focus: Vector3):
	for mesh in walls:
		mesh.visible=not top or mesh.global_position.z < focus.z-2 or absf(mesh.global_position.x-focus.x)>8
	for entry in interactions:
		entry.label.visible=entry.label.global_position.distance_to(focus)<7 and (not entry.used or entry.kind in ["bench","catalog","exit"])
