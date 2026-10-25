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
var wrecks: Array=[]

func material(color: Color,metal: float=.55,rough: float=.65) -> StandardMaterial3D:
	var key=str(color)+str(metal)
	if materials.has(key):return materials[key]
	var m=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=rough;materials[key]=m;return m

func box(pos: Vector3,size: Vector3,color: Color,solid: bool=true,occluder: bool=false) -> Node3D:
	var root=StaticBody3D.new() if solid else Node3D.new()
	if solid:root.collision_layer=1;root.collision_mask=2
	if solid:root.set_meta("surface_type","metal" if game!=null and game.story.prologue==5 else "concrete")
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

func practical_fixture(id: String,pos: Vector3,height: float=.6):
	var path="res://assets/models/fixtures/"+id+".glb"
	if not ResourceLoader.exists(path):return
	var model=load(path).instantiate();add_child(model);model.position=pos
	var bounds=AABB()
	for n in all_children(model):
		if n is MeshInstance3D:bounds=bounds.merge((model.global_transform.affine_inverse()*n.global_transform)*n.get_aabb())
	var factor=height/maxf(bounds.size.y,.01);model.scale=Vector3.ONE*factor
	var light=OmniLight3D.new();light.position=pos+Vector3(0,height*.7,0);light.omni_range=5;light.light_energy=1.7;light.light_color=Color("ffce92");add_child(light)

func prop(file: String,pos: Vector3,height: float=1.0,angle: float=0.0) -> Node3D:
	var path="res://assets/models/"+(file if "/" in file else "space-station-kit/"+file)+".glb"
	if not ResourceLoader.exists(path):
		var missing=Node3D.new();add_child(missing);push_warning("Missing environment asset: "+path);return missing
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
	n.set_meta("interaction_radius",clampf(maxf(bounds.size.x,bounds.size.z)*factor*.5+1.1,2.6,4.5))
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
	item["radius"]=float(n.get_meta("interaction_radius",2.6))
	var sign=plaque(title+"\n[E]",pos+Vector3(0,1.7,0),24)
	sign.pixel_size=.0028
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;item.label=sign
	interactions.append(item)
	return item

func build(g: Node3D,index: int,training: bool=false):
	game=g
	if game.story.location=="hub":build_hub();return
	if game.story.location=="prologue":build_prologue();return
	if index<2 and not training:build_early_sector(index);return
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

func room(center: Vector3,size: Vector3,open_front: bool=true):
	for z in range(int(-size.z/2),int(size.z/2),6):
		box(center+Vector3(0,-.2,z+3),Vector3(size.x,.4,6),Color("62696a"))
	for x in [-size.x/2,size.x/2]:box(center+Vector3(x,2,0),Vector3(.3,4,size.z),Color("2c363a"),true,true)
	if not open_front:box(center+Vector3(0,2,size.z/2),Vector3(size.x,4,.3),Color("2c363a"),true,true)
	for z in range(int(-size.z/2)+3,int(size.z/2),7):
		for x in [-size.x*.28,size.x*.28]:ceiling_fixture(center+Vector3(x,3.6,z),true)

func resident(id: String,pos: Vector3,job: String="Idle_Talking"):
	var npc=LowGridResident.new();add_child(npc);npc.setup(game,id,pos,job)
	if id in ["steel","mira","yan","seam"]:
		var sign=plaque({"steel":"Стальной / ремонт и сборка","mira":"Мира / грузовые маршруты","yan":"Ян / маркировки MaintCore","seam":"Шов / восстановление тела"}[id]+"\n[E] разговор",pos+Vector3(0,2.3,0),20)
		sign.pixel_size=.002;sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		interactions.append({"id":"npc_"+id,"kind":"npc","position":[pos.x,pos.y,pos.z],"title":sign.text,"data":{"id":id},"used":false,"label":sign,"node":npc})

func build_hub():
	room(Vector3(0,0,-12),Vector3(30,4,36),false)
	box(Vector3(0,2,-30),Vector3(30,4,.3),Color("394144"),true,true)
	# Workshops flank an open, walkable courtyard; human routes do not cross the benches.
	for x in [-11,11]:
		for z in [-5,-16,-25]:prop("factory-kit/box-wide",Vector3(x,0,z),.7)
	interaction("hub_bench","bench",Vector3(-10,0,-8),"МАСТЕРСКАЯ / СБОРКА L.R.-01")
	practical_fixture("industrial_pipe_lamp",Vector3(-10,.9,-8),.65)
	for x in [-14,14]:
		for z in [-3,-14,-25]:practical_fixture("industrial_caged_sconce",Vector3(x,2,z),.55)
	interaction("hub_charge","charge",Vector3(-10,0,-2),"ЗАРЯДНАЯ СТАНЦИЯ")
	interaction("hub_market","market",Vector3(8,0,-25),"РЫНОК / ДЕТАЛИ И БОЕПРИПАСЫ")
	interaction("hub_sorting","hub_exit",Vector3(0,0,-27),"ГРУЗОВАЯ ЛИНИЯ / СОРТИРОВКА")
	interaction("hub_dump","hub_dump",Vector3(0,0,3),"ВЕРНУТЬСЯ НА СВАЛКУ")
	resident("steel",Vector3(-7,0,-8),"Fixing_Kneeling")
	resident("mira",Vector3(6,0,-17),"Idle_FoldArms")
	resident("yan",Vector3(9,0,-5),"Sitting_Idle")
	resident("seam",Vector3(-8,0,-21),"Fixing_Kneeling")
	for i in range(4):resident("resident_"+str(i),Vector3(-5+i*3,0,-23),"Sitting_Idle" if i<2 else "Idle")
	resident("cargo",Vector3(7,0,-11),"Push")
	for pos in [Vector3(-2,0,-23),Vector3(9,0,-5)]:prop("factory-kit/box-wide",pos,.48)
	# Visible overhead gantry and a single shadowed courtyard lamp anchor the figures.
	box(Vector3(0,4.1,-10),Vector3(28,.28,.32),Color("394346"),false)
	for x in [-13,13]:box(Vector3(x,2,-10),Vector3(.3,4,.3),Color("394346"))
	box(Vector3(0,3.8,-10),Vector3(1,.12,.6),Color("263237"),false)
	strip(Vector3(0,3.71,-10),Vector3(.8,.025,.4),Color("cddbd6"))
	var yard_light=OmniLight3D.new();yard_light.position=Vector3(0,3.5,-10);yard_light.omni_range=12;yard_light.light_energy=3;yard_light.light_color=Color("cddbd6");yard_light.shadow_enabled=true;add_child(yard_light)
	for x in [-12,12]:
		for z in [-5,-20]:
			prop("factory-kit/pipe-glass-large-long",Vector3(x,2.7,z),1.3,PI/2)
			prop("factory-kit/machine-connection-pipe",Vector3(x,0,z),1.7)
	prop("factory-kit/robot-arm-a",Vector3(-11,0,-16),2)
	prop("factory-kit/conveyor-long-stripe-sides",Vector3(10,0,-23),.8)
	for x in [-8,8]:
		var color=Color("d6a467") if x<0 else Color("78a8bc")
		strip(Vector3(x,2.9,-29.7),Vector3(5,.07,.06),color)
		var neon=OmniLight3D.new();neon.position=Vector3(x,2.7,-28.8);neon.omni_range=6;neon.light_color=color;neon.light_energy=1.8;add_child(neon)
	plaque("НУЛЕВАЯ СТАНЦИЯ\nSCRAP UNION / РЕМОНТ · ЛЮДИ · ДЕТАЛИ",Vector3(0,3,-29.6),35,Color("c8ac7d"))
	for i in range(12):
		var x=-30+i*5.7;var height=9+(i*7)%16
		box(Vector3(x,height/2,-42-i%3*4),Vector3(4,height,5),Color("18252e"),false)
		for y in range(4,height,3):strip(Vector3(x,y,-39.4-i%3*4),Vector3(1.4,.16,.02),Color("846e44"))
	batch_static_details()

func build_prologue():
	var stage=game.story.prologue
	room(Vector3(0,0,-6),Vector3(12,4,24),false)
	box(Vector3(0,2,-18),Vector3(12,4,.3),Color("303a40"),true,true)
	var titles=["НЕИЗВЕСТНЫЙ МАРШРУТ","HELIX DOMINION / ОЧИСТКА","КОНТЕЙНЕР К-63","НЕСАНКЦИОНИРОВАННЫЙ ПЕРЕНОС","МАСТЕРСКАЯ ЛЕИ РЕНН","АВАРИЙНЫЙ ГРУЗОВОЙ МОСТ"]
	plaque(titles[stage],Vector3(0,2.6,-17.6),28)
	if stage in [1,3,4]:
		prop("factory-kit/machine-bed",Vector3(-2,0,-5),1.2)
		prop("factory-kit/robot-arm-a",Vector3(-3,0,-5),1.9)
		prop("computer-system",Vector3(3,0,-5),1.5)
		prop("factory-kit/screen-panel-wide",Vector3(2,1,-6),.7)
		practical_fixture("industrial_pipe_lamp",Vector3(2,1,-6),.55)
		for z in [-3,-8]:prop("factory-kit/machine-connection-pipe",Vector3(-5,0,z),2.5)
		if stage==1:
			var body=ScrapRobotVisual.new();add_child(body);body.position=Vector3(-1,0,-5);body.rotation.y=PI;body.setup(game.catalog,game.sim,game.sim.starter())
			plaque("К-63 / ОЧИСТКА ПРЕРВАНА\nСОХРАНЕНО 63% / БРАК",Vector3(2,1.8,-6),22,Color("cc8065"))
	if stage in [2,3]:
		for x in [-4,4]:prop("container-tall",Vector3(x,0,-8),2.2)
	if stage>=3:resident("leya",Vector3(1.7,0,-4),"Idle_Talking")
	if stage==0:
		var rain_path="res://assets/audio/rain_on_window_loop.wav"
		if ResourceLoader.exists(rain_path) and DisplayServer.get_name()!="headless":
			var audio=AudioStreamPlayer.new();audio.bus="Ambience";audio.stream=load(rain_path);audio.volume_db=-7;add_child(audio);audio.finished.connect(audio.play);audio.play()
		var rain=CPUParticles3D.new();rain.position=Vector3(0,5,-7);rain.amount=260;rain.lifetime=.7;rain.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;rain.emission_box_extents=Vector3(5,1,10);rain.direction=Vector3.DOWN;rain.spread=3;rain.initial_velocity_min=12;rain.initial_velocity_max=17
		var drop=BoxMesh.new();drop.size=Vector3(.006,.16,.006);rain.mesh=drop;var water=StandardMaterial3D.new();water.albedo_color=Color(.6,.72,.78,.4);water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;drop.material=water;add_child(rain)
		for z in range(-2,-18,-4):
			for x in [-4,4]:prop("factory-kit/conveyor-bars-fence",Vector3(x,0,z),1)
		prop("container-tall",Vector3(0,0,-16),3.0)
		for x in [-2,2]:
			var headlamp=SpotLight3D.new();headlamp.position=Vector3(x,.8,-13);headlamp.light_energy=7;headlamp.spot_range=20;headlamp.spot_angle=35;headlamp.rotation.y=PI;add_child(headlamp)
	if stage==5:
		for x in [-3.5,3.5]:
			box(Vector3(x,.75,-8),Vector3(.1,1.5,16),Color("424d50"),true,true)
			strip(Vector3(x,1.6,-8),Vector3(.13,.06,16),Color("bba064"))
		var alarm=OmniLight3D.new();alarm.position=Vector3(0,2.6,-1);alarm.light_color=Color("e43823");alarm.omni_range=10;alarm.light_energy=2;add_child(alarm)
		for z in range(0,-16,-3):
			strip(Vector3(-3,.04,z),Vector3(.2,.04,1.2),Color("c9a65d"))
			prop("factory-kit/box-large",Vector3(3,0,z),.8)
	batch_static_details()

func build_early_sector(index: int):
	var sector=ScrapCampaign.SECTORS[index]
	if index==0:
		room(Vector3(0,0,-15),Vector3(22,4,42),false)
		box(Vector3(0,2,-36),Vector3(22,4,.3),Color("303b40"),true,true)
		for z in [-9,-21,-30]:
			for x in [-8,8]:prop("container-tall",Vector3(x,0,z),1.8)
		resident("seam",Vector3(-3,0,-4),"Fixing_Kneeling")
		wreck("service_donor",Vector3(-7,.05,-4),["right_arm","legs","power_core"])
		wreck("sensor_donor",Vector3(7,.05,-10),["sensor","cpu","left_arm"])
		interaction("bench_start","bench",Vector3(-4,0,0),"ВОССТАНОВЛЕНИЕ / ВЕРСТАК")
		practical_fixture("industrial_pipe_lamp",Vector3(-4,.9,0),.65)
		interaction("cache_supply","supply",Vector3(4.9,0,-6),"ОРУЖЕЙНЫЙ ЯЩИК / ПИСТОЛЕТ И ИНСТРУМЕНТЫ")
		for i in range(3):interaction("terminal_"+str(i),"terminal",Vector3(-7,0,-10-i*8),sector.objectives[i],{"objective":i,"text":sector.texts[i]})
		interaction("exit","exit",Vector3(0,0,-33),"К НУЛЕВОЙ СТАНЦИИ / SCRAP UNION")
	else:
		for i in range(3):
			var center=Vector3(0,0,-14-i*30)
			room(center,Vector3(24 if i==1 else 18,4,36 if i==0 else 30),true)
			for x in [-4,4]:
				prop("factory-kit/conveyor-long-stripe-sides",center+Vector3(x,0,0),.75)
				box(center+Vector3(x,.35,0),Vector3(1.5,.7,6),Color("303739"),true).get_child(0).visible=false
			prop("factory-kit/crane-magnet",center+Vector3(6,1.7,-5),1.7)
			interaction("terminal_"+str(i),"terminal",Vector3(-6.5,0,-22-i*30),sector.objectives[i],{"objective":i,"text":sector.texts[i]})
		room(Vector3(0,0,-95),Vector3(18,4,12))
		for x in [-5.5,5.5]:box(Vector3(x,2,5),Vector3(7,4,.3),Color("303b40"),true,true)
		box(Vector3(0,2,-101),Vector3(18,4,.3),Color("303b40"),true,true)
		interaction("return","return",Vector3(0,0,3),"НУЛЕВАЯ СТАНЦИЯ")
		interaction("exit","exit",Vector3(0,0,-98),"СЕРВИСНЫЙ ТУННЕЛЬ")
		interaction("bench_start","bench",Vector3(-4,0,0),"СЕРВИСНЫЙ ВЕРСТАК")
		interaction("cache_supply","supply",Vector3(4.9,0,-6),"ИНСТРУМЕНТЫ ГРУЗОВОЙ ЛИНИИ")
		interaction("cache_optional","cache",Vector3(8,0,-49),"СКЛАД СЕРВИСНЫХ УЗЛОВ")
	batch_static_details();build_navigation()

func wreck(id: String,pos: Vector3,recoverable: Array):
	var state=game.sim.robot("E02")
	var saved=game.sector_records.get("0",{}).get("wrecks",{})
	if saved.has(id):state=saved[id]
	else:
		for slot in state.assembly:
			var part=state.assembly[slot]
			if slot in recoverable:part.durability=floorf(part.max_durability*.84)
			else:part.durability=0;part.destroyed=true
		state.alive=false;state["wreck_shell"]=true
	var body=ScrapActor.new();add_child(body);body.position=pos;body.patrol_origin=pos;body.setup(game,state);body.uuid=id;body.enemy_name="СПИСАННЫЙ СЕРВИСНЫЙ КОРПУС";wrecks.append(body)
	var sign=plaque("СПИСАННОЕ ТЕЛО / ЕСТЬ РАБОЧИЕ УЗЛЫ\n[E] осмотр и демонтаж",pos+Vector3(0,1.2,0),22,Color("9db8aa"));sign.pixel_size=.002;sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	interactions.append({"id":id,"kind":"wreck","position":[pos.x,pos.y,pos.z],"title":"СПИСАННОЕ ТЕЛО / СНЯТЬ РАБОЧИЕ УЗЛЫ","data":{},"node":body,"label":sign,"used":false})

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
	var best={};var score=1.0
	for x in interactions:
		if x.used and x.kind not in ["bench","catalog","exit"]:continue
		var p=Vector3(x.position[0],x.position[1],x.position[2])
		var d=Vector2(p.x-pos.x,p.z-pos.z).length()
		var candidate=d/float(x.get("radius",2.6))
		if candidate<score:score=candidate;best=x
	return best

func update_occlusion(top: bool,focus: Vector3):
	for mesh in walls:
		mesh.visible=not top or mesh.global_position.z < focus.z-2 or absf(mesh.global_position.x-focus.x)>8
	for entry in interactions:
		if entry.kind=="npc" and is_instance_valid(entry.node):
			var pos=entry.node.position;entry.position=[pos.x,pos.y,pos.z];entry.label.position=pos+Vector3(0,2.3,0)
		entry.label.visible=entry.label.global_position.distance_to(focus)<7 and (not entry.used or entry.kind in ["bench","catalog","exit"])
