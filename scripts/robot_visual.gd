class_name ScrapRobotVisual
extends Node3D

var catalog: ScrapCatalog
var sim: ScrapSimulation
var state: Dictionary
var mounts = {}
var joints = {}
var held_nodes = {}
var damage_materials = {}
var cycle = 0.0
var hurt = 0.0
var flash = 0.0
var aim_pitch = 0.0
var attacks = {"left_arm":0.0,"right_arm":0.0}
var attack_kinds = {}
var first_person = false
var weapon_list: Array = []
var motion: LowGridMotion
var occupation=""
var detailed_arm: Skeleton3D
static var model_cache: Dictionary = {}
static var wear_cache: Dictionary = {}
static var torso_mesh_cache: Dictionary = {}

func setup(c: ScrapCatalog,s: ScrapSimulation,r: Dictionary):
	catalog=c;sim=s;state=r
	var dir = DirAccess.open("res://assets/models/blaster-kit")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".glb") or f.ends_with(".glb.remap"):weapon_list.append("res://assets/models/blaster-kit/"+f.trim_suffix(".remap"))
	weapon_list.sort()
	rebuild()

func instance_model(path: String) -> Node3D:
	if not model_cache.has(path):model_cache[path]=load(path)
	if model_cache[path] == null:return Node3D.new()
	return model_cache[path].instantiate()

func rebuild():
	detailed_arm=null
	for child in get_children():remove_child(child);child.queue_free()
	mounts.clear();joints.clear();held_nodes.clear();damage_materials.clear()
	if state.archetype in ["E05","E06"]:
		build_drone();return
	var positions = {"legs":Vector3(0,.90,0),"torso":Vector3(0,1.2,0),"sensor":Vector3(0,1.67,0),"left_arm":Vector3(-.32,1.43,0),"right_arm":Vector3(.32,1.43,0)}
	for slot in positions:
		if not state.assembly.has(slot):continue
		var p=state.assembly[slot]
		if p.destroyed and not state.get("wreck_shell",false):continue
		var d=sim.definition(p)
		var id=d.get("visual_id","")
		if id.begins_with("internal"):continue
		var mount=Node3D.new();mount.position=positions[slot];add_child(mount)
		var model=instance_model("res://assets/models/parts/"+id+".glb")
		if slot=="left_arm":model.scale.x=-1
		mount.add_child(model);mounts[slot]=mount
		if slot=="torso":split_torso_shell(model)
		for n in descendants(model):
			if n is MeshInstance3D:
				for surface in range(n.mesh.get_surface_count()):
					var material=n.get_active_material(surface)
					if material is StandardMaterial3D and "armor" in material.resource_name.to_lower():
						var key=material.resource_name
						if not wear_cache.has(key):
							var worn=ShaderMaterial.new();worn.shader=load("res://assets/materials/worn_metal.gdshader");worn.set_shader_parameter("base_color",material.albedo_color)
							var base="res://assets/materials/Metal040/Metal040_1K-JPG_"
							if ResourceLoader.exists(base+"Color.jpg"):worn.set_shader_parameter("surface_color",load(base+"Color.jpg"));worn.set_shader_parameter("surface_normal",load(base+"NormalGL.jpg"))
							wear_cache[key]=worn
						var local_material=wear_cache[key].duplicate()
						n.set_surface_override_material(surface,local_material)
						if not damage_materials.has(slot):damage_materials[slot]=[]
						damage_materials[slot].append(local_material)
			for joint in ["UpperArm","Forearm","LeftThigh","RightThigh","LeftShin","RightShin"]:
				if n.name.begins_with(joint) and not n.name.contains("Geometry"):joints[slot+joint]=n
			if n.name.begins_with("Finger") and not n.name.contains("Geometry"):joints[slot+str(n.name)]=n
		if slot in ["left_arm","right_arm"] and state.held.get(slot)!=null and not weapon_list.is_empty():
			var w=sim.definition(state.held[slot])
			var hand=Node3D.new()
			if joints.has(slot+"Forearm"):
				joints[slot+"Forearm"].add_child(hand);hand.position=Vector3(0,-.31,-.02)
			else:mount.add_child(hand);hand.position=Vector3(0,-.63,-.04)
			var tools={"PIPE_CLUB":"pipe","SCRAP_KNIFE":"knife","STUN_BATON":"baton","CUTTER_TOOL":"cutter","THERMAL_SAW":"saw"}
			var tool=tools.get(w.id,"")
			var gun=instance_model("res://assets/models/devices/held_"+tool+".glb" if tool!="" else weapon_list[int(w.get("model_index",0))%weapon_list.size()])
			gun.scale=Vector3.ONE if tool!="" else Vector3.ONE*.36
			gun.rotation.x=-1.4
			if tool=="":gun.rotation.y=PI
			hand.add_child(gun);held_nodes[slot]=hand
		if sim.condition(p)<.75:
			var smoke=MeshInstance3D.new();var m=SphereMesh.new();m.radius=.022;m.height=.045;smoke.mesh=m
			var mat=StandardMaterial3D.new();mat.albedo_color=Color("a75924");mat.emission_enabled=true;mat.emission=Color("c76522");smoke.material_override=mat;smoke.position=Vector3(0,.06,-.05);mount.add_child(smoke)

	var exposed=state.assembly.has("torso") and float(state.assembly.torso.durability)/float(state.assembly.torso.max_durability)<=.4
	for slot in ["cpu","power_core","cooling","controller","memory","comm_module","adapter"]:
		if not state.assembly.has(slot):continue
		var path="res://assets/models/devices/internal_"+slot+".glb"
		if not ResourceLoader.exists(path):continue
		var module=instance_model(path);module.position=Vector3(-.10 if slot in ["cpu","memory"] else .10,1.35 if slot in ["cpu","controller","comm_module"] else 1.12,.02);module.rotation.x=PI/2;module.scale=Vector3.ONE*.7;module.visible=exposed;add_child(module);mounts["internal_"+slot]=module
	set_first_person(first_person,true)
	motion=LowGridMotion.new();add_child(motion)
	motion.foot_contact.connect(play_foot_contact)
	motion.reload_commit.connect(func():
		if get_parent() is ScrapActor:get_parent().commit_reload())
	var detailed_path="res://assets/models/parts/lr01_mechanical_arm.glb"
	if state.get("presentation","")=="lr01" and mounts.has("left_arm") and sim.definition(state.assembly.left_arm).get("visual_id","")=="arms_01" and ResourceLoader.exists(detailed_path):
		var arm=instance_model(detailed_path);add_child(arm);arm.rotation.y=PI;arm.position.x=-.129
		for n in descendants(arm):
			if n is Skeleton3D:detailed_arm=n
		for n in descendants(mounts.left_arm):
			if n is MeshInstance3D and (not held_nodes.has("left_arm") or not held_nodes.left_arm.is_ancestor_of(n)):n.visible=false

func align_detail_bone(name: String,joint: Node3D):
	var index=detailed_arm.find_bone(name)
	if index<0:return
	var pose=detailed_arm.get_bone_global_pose(index)
	var direction=detailed_arm.global_basis.inverse()*(joint.global_basis*Vector3.DOWN)
	var desired=Basis(Quaternion(pose.basis.y.normalized(),direction.normalized()))*pose.basis
	var parent=detailed_arm.get_bone_parent(index)
	var basis=detailed_arm.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	detailed_arm.set_bone_pose_rotation(index,(basis.inverse()*desired).orthonormalized().get_rotation_quaternion())

func set_first_person(enabled: bool,force: bool=false):
	if first_person==enabled and not force:return
	first_person=enabled
	for slot in ["sensor","torso","legs"]:
		if not mounts.has(slot):continue
		for mesh in descendants(mounts[slot]):
			if mesh is MeshInstance3D:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func kick(hand: String,kind: String="projectile"):
	attacks[hand]=1.0;attack_kinds[hand]=kind
	if motion!=null:motion.play_action(("Punch_Jab" if hand=="left_arm" else "Punch_Cross") if kind=="melee" else "Pistol_Shoot")

func play_foot_contact(side: String):
	if not state.alive or DisplayServer.get_name()=="headless":return
	var actor=get_parent()
	if not actor is ScrapActor and not actor is LowGridResident:return
	if actor.velocity.length()<.15:return
	var mass=float(sim.stats(state).mass)
	var index=1 if side=="left" else 2
	var ground=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.global_position+Vector3(0,.3,0),actor.global_position+Vector3(0,-.5,0),1))
	var metal=not ground.is_empty() and ground.collider.get_meta("surface_type","concrete")=="metal"
	for layer in ["robotstomp.wav" if mass>100 else "robotstep%d.wav" % index,"impactPlate_light_001.ogg" if metal else "footstep_concrete_00%d.ogg" % index,"robot1.wav"]:
		var path="res://assets/audio/movement/"+layer
		if not ResourceLoader.exists(path):continue
		var audio=AudioStreamPlayer3D.new();add_child(audio);audio.stream=load(path)
		audio.bus="Movement"
		audio.max_distance=18;audio.volume_db=-14+clampf((mass-63)/12,-5,5)
		if layer=="robot1.wav":audio.volume_db-=12
		audio.pitch_scale=clampf(1.05-(mass-63)/250,.65,1.2)
		var query=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,actor.game.camera.global_position,1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():audio.volume_db-=12
		audio.finished.connect(audio.queue_free);audio.play()

func pose_segment(key: String,direction: Vector3):
	if not joints.has(key):return
	var joint=joints[key]
	var local=joint.get_parent().global_basis.inverse()*(global_basis*direction)
	joint.quaternion=Quaternion(Vector3.DOWN,local.normalized())

func inspect_internals(enabled: bool):
	if mounts.has("torso"):
		for mesh in descendants(mounts.torso):
			if mesh.has_meta("armor_shell"):mesh.visible=not enabled
	for slot in mounts:
		if slot.begins_with("internal_"):mounts[slot].visible=enabled

func split_torso_shell(model: Node3D):
	for n in descendants(model):
		if not n is MeshInstance3D:continue
		var source=n.mesh;var key=source.get_rid()
		if not torso_mesh_cache.has(key):
			var frame=ArrayMesh.new();var shell=ArrayMesh.new()
			for i in range(source.get_surface_count()):
				var material=source.surface_get_material(i)
				var mesh=shell if material!=null and "armor" in material.resource_name.to_lower() else frame
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(i))
				mesh.surface_set_material(mesh.get_surface_count()-1,material)
			torso_mesh_cache[key]={"frame":frame,"shell":shell}
		var split=torso_mesh_cache[key]
		if split.shell.get_surface_count()==0:continue
		n.mesh=split.frame
		var shell=MeshInstance3D.new();shell.mesh=split.shell;shell.set_meta("armor_shell",true);n.add_child(shell)

func descendants(root: Node) -> Array:
	var result=[]
	for child in root.get_children():result.append(child);result.append_array(descendants(child))
	return result

func build_drone():
	var path="res://assets/models/devices/drone_"+state.archetype+".glb"
	if ResourceLoader.exists(path):
		var model=instance_model(path);add_child(model);mounts.drone_body=model;return
	var heavy=state.archetype=="E06"
	var hull=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.34 if heavy else .24;sphere.height=sphere.radius*1.1;hull.mesh=sphere
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("303d44");mat.metallic=.8;mat.roughness=.38;hull.material_override=mat;add_child(hull);mounts.drone_body=hull
	for x in [-.35,.35]:
		var fan=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=.17;cylinder.bottom_radius=.17;cylinder.height=.08;fan.mesh=cylinder;fan.material_override=mat;fan.position=Vector3(x,0,0);add_child(fan)
	var eye=MeshInstance3D.new();var lens=SphereMesh.new();lens.radius=.07;lens.height=.1;eye.mesh=lens;eye.position=Vector3(0,0,-.24);var glow=StandardMaterial3D.new();glow.albedo_color=Color("db7137");glow.emission_enabled=true;glow.emission=Color("db7137");eye.material_override=glow;add_child(eye)
	if heavy and not weapon_list.is_empty():
		var gun=instance_model(weapon_list[4%weapon_list.size()]);gun.scale=Vector3.ONE*.4;gun.position=Vector3(0,-.18,0);gun.rotation.y=PI;add_child(gun)

func animate(dt: float,speed: float,aiming: bool,blocking: bool):
	if motion!=null:
		motion.grip_hands=[]
		if state.held.get("left_arm")!=null:motion.grip_hands.append("L")
		if state.held.get("right_arm")!=null:motion.grip_hands.append("R")
		if get_parent() is ScrapActor:motion.local_velocity=global_basis.inverse()*get_parent().velocity
		motion.update(dt,speed,state.alive,occupation if speed<.15 else "")
	cycle += dt*(7.5 if speed>3.4 else 5.6)
	hurt=maxf(0,hurt-dt*5);flash=maxf(0,flash-dt*6)
	for slot in damage_materials:
		var amount=1.0-sim.condition(state.assembly.get(slot))
		for material in damage_materials[slot]:material.set_shader_parameter("damage",amount)
	if state.archetype in ["E05","E06"]:
		position.y=sin(cycle*.8)*.045
		rotation.z=sin(cycle*.4)*.045
		if not state.alive:rotation.z=lerp_angle(rotation.z,PI/2,dt*3)
		return
	var moving=clampf(speed/3,0,1)
	for side in ["Left","Right"]:
		var sign=1 if side=="Left" else -1
		var key="legs"+side+"Thigh"
		if joints.has(key) and motion!=null:pose_segment(key,motion.direction("DEF-thigh."+("L" if side=="Left" else "R"),"DEF-shin."+("L" if side=="Left" else "R")))
		key="legs"+side+"Shin"
		if joints.has(key) and motion!=null:pose_segment(key,motion.direction("DEF-shin."+("L" if side=="Left" else "R"),"DEF-foot."+("L" if side=="Left" else "R")))
	for slot in ["left_arm","right_arm"]:
		if not mounts.has(slot):continue
		var mount=mounts[slot]
		var swing=sin(cycle+(.0 if slot=="left_arm" else PI))
		var upper=swing*.42*moving
		var elbow=.12+maxf(0,-swing)*.32*moving
		if aiming:upper=.98+aim_pitch*.65;elbow=.57+aim_pitch*.35
		if blocking and slot=="left_arm":upper=.85;elbow=1.1
		var strike=float(attacks.get(slot,0.0))
		attacks[slot]=maxf(0,strike-dt*3.5)
		if strike>0:
			if attack_kinds.get(slot,"")!="melee":upper-=strike*.16;elbow+=strike*.22
		if not state.alive or not sim.functional(state,slot):upper=-.2;elbow=.12
		mount.rotation=Vector3(0,0,sin(cycle*.5)*.02+hurt*.2)
		if joints.has(slot+"UpperArm"):joints[slot+"UpperArm"].rotation.x=lerpf(joints[slot+"UpperArm"].rotation.x,upper,clampf(dt*15,0,1))
		if joints.has(slot+"Forearm"):joints[slot+"Forearm"].rotation.x=lerpf(joints[slot+"Forearm"].rotation.x,elbow,clampf(dt*15,0,1))
		var imported_strike=strike>0 and attack_kinds.get(slot,"")=="melee"
		if motion!=null and (not aiming or imported_strike) and not blocking and state.alive and sim.functional(state,slot):
			var side="L" if slot=="left_arm" else "R"
			pose_segment(slot+"UpperArm",motion.direction("DEF-upper_arm."+side,"DEF-forearm."+side))
			pose_segment(slot+"Forearm",motion.direction("DEF-forearm."+side,"DEF-hand."+side))
		if motion!=null:
			for finger in ["Index","Middle","Ring","Pinky","Thumb"]:
				for segment in range(1,4):
					var key=slot+"Finger"+finger+str(segment)
					if not joints.has(key):continue
					var bone="DEF-"+("thumb" if finger=="Thumb" else "f_"+finger.to_lower())+".0"+str(segment)+(".L" if slot=="left_arm" else ".R")
					var index=motion.skeleton.find_bone(bone)
					if index>=0:
						var delta=motion.skeleton.get_bone_rest(index).basis.inverse()*Basis(motion.skeleton.get_bone_pose_rotation(index))
						joints[key].rotation.x=clampf(delta.get_euler().x,-1.5,1.5)
	if mounts.has("torso"):mounts.torso.rotation.z=sin(cycle)*.015*moving;mounts.torso.position.y=1.2+absf(sin(cycle))*.012*moving
	if detailed_arm!=null and motion!=null:
		motion.retarget(detailed_arm)
		if joints.has("left_armUpperArm"):align_detail_bone("DEF-upper_arm.L",joints.left_armUpperArm)
		if joints.has("left_armForearm"):align_detail_bone("DEF-forearm.L",joints.left_armForearm)
	if not state.alive:rotation.x=lerp_angle(rotation.x,-PI/2,dt*3);position.y=lerpf(position.y,.3,dt*3)

func muzzle(hand: String) -> Vector3:
	if held_nodes.has(hand):return held_nodes[hand].get_child(0).to_global(Vector3(0,0,-.45))
	if joints.has(hand+"Forearm"):return joints[hand+"Forearm"].to_global(Vector3(0,-.26,-.15))
	if mounts.has(hand):return mounts[hand].to_global(Vector3(0,-.5,-.35))
	return global_position+Vector3(0,-.1,-.5) if state.archetype in ["E05","E06"] else global_position+Vector3(0,1.3,-.4)
