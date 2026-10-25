class_name LowGridMotion
extends Node3D

signal foot_contact(side: String)
signal reload_commit
var skeleton: Skeleton3D
var player: AnimationPlayer
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var rig: Node3D
var current="Idle"
var action_time=0.0
var action=""
var speed_scale=1.0
var local_velocity=Vector3.ZERO
var grip_hands: Array=[]
const HUMAN_MAP={"pelvis":"DEF-hips","spine_01":"DEF-spine.001","spine_02":"DEF-spine.002","spine_03":"DEF-spine.003","neck_01":"DEF-neck","head":"DEF-head","clavicle":"DEF-shoulder","upperarm":"DEF-upper_arm","lowerarm":"DEF-forearm","hand":"DEF-hand","thigh":"DEF-thigh","calf":"DEF-shin","foot":"DEF-foot","ball":"DEF-toe","index":"DEF-f_index","middle":"DEF-f_middle","ring":"DEF-f_ring","pinky":"DEF-f_pinky","thumb":"DEF-thumb"}
const SOURCE="res://assets/animations/quaternius-ual1/AnimationLibrary_Godot_Standard.glb"

func _ready():
	rig=load(SOURCE).instantiate();add_child(rig)
	for n in walk(rig):
		if n is MeshInstance3D:n.visible=false
		elif n is Skeleton3D:skeleton=n
		elif n is AnimationPlayer:player=n
	# Imported library resources are shared. Events and root translation edits are local.
	var library=player.get_animation_library("").duplicate(true)
	player.remove_animation_library("");player.add_animation_library("",library)
	if ResourceLoader.exists("res://assets/animations/kaykit_adapted.glb"):
		var extra=load("res://assets/animations/kaykit_adapted.glb").instantiate()
		for node in walk(extra):
			if not node is AnimationPlayer:continue
			for clip_name in node.get_animation_list():
				if not str(clip_name).begins_with("KK_"):continue
				var animation=node.get_animation(clip_name).duplicate(true)
				for index in range(animation.get_track_count()-1,-1,-1):
					var path=str(animation.track_get_path(index))
					if ":" not in path:animation.remove_track(index)
					else:animation.track_set_path(index,NodePath(str(rig.get_path_to(skeleton))+":"+path.get_slice(":",1)))
				library.add_animation(clip_name,animation)
		extra.free()
	for name in library.get_animation_list():
		var clip=library.get_animation(name)
		for i in range(clip.get_track_count()-1,-1,-1):
			var path=str(clip.track_get_path(i))
			if path.ends_with(":root") and clip.track_get_type(i)==Animation.TYPE_POSITION_3D:clip.remove_track(i)
		if name in ["Walk","Walk_Formal","Jog_Fwd","Sprint","KK_Walking_Backwards","KK_Running_Strafe_Left","KK_Running_Strafe_Right"]:
			clip.loop_mode=Animation.LOOP_LINEAR
			var track=clip.add_track(Animation.TYPE_METHOD);clip.track_set_path(track,NodePath(".."))
			clip.track_insert_key(track,.03,{"method":"contact","args":["left"]})
			clip.track_insert_key(track,clip.length*.5,{"method":"contact","args":["right"]})
		if name=="Pistol_Reload":
			var track=clip.add_track(Animation.TYPE_METHOD);clip.track_set_path(track,NodePath(".."));clip.track_insert_key(track,clip.length*.65,{"method":"commit_reload","args":[]})
	var machine=AnimationNodeStateMachine.new()
	for name in library.get_animation_list():
		var node=AnimationNodeAnimation.new();node.animation=name;machine.add_node(name,node)
	for name in library.get_animation_list():
		if name=="Idle":continue
		var transition=AnimationNodeStateMachineTransition.new();transition.xfade_time=.16
		machine.add_transition("Idle",name,transition)
		machine.add_transition(name,"Idle",transition.duplicate())
	tree=AnimationTree.new();tree.anim_player=tree.get_path_to(player) if tree.is_inside_tree() else NodePath("../"+str(rig.name)+"/AnimationPlayer")
	var blend=AnimationNodeBlendTree.new();blend.add_node("Body",machine);blend.add_node("Cadence",AnimationNodeTimeScale.new());blend.connect_node("Cadence",0,"Body")
	var previous="Cadence"
	for side in ["L","R"]:
		var grip=AnimationNodeAnimation.new();grip.animation="Pistol_Idle";blend.add_node("GripPose"+side,grip)
		var filter=AnimationNodeBlend2.new();filter.filter_enabled=true
		for index in range(skeleton.get_bone_count()):
			var bone=str(skeleton.get_bone_name(index))
			if bone.ends_with("."+side) and (bone.begins_with("DEF-f_") or bone.begins_with("DEF-thumb") or bone.begins_with("DEF-hand")):filter.set_filter_path(NodePath(str(rig.get_path_to(skeleton))+":"+bone),true)
		var name="Grip"+side;blend.add_node(name,filter);blend.connect_node(name,0,previous);blend.connect_node(name,1,"GripPose"+side);previous=name
	blend.connect_node("output",0,previous)
	tree.tree_root=blend;add_child(tree);tree.anim_player=tree.get_path_to(player);tree.active=true
	playback=tree.get("parameters/Body/playback");playback.start("Idle")

func contact(side: String):foot_contact.emit(side)
func commit_reload():reload_commit.emit()

func play_action(name: String):
	if player==null or not player.has_animation(name):return
	action=name;action_time=player.get_animation(name).length
	playback.start(name,true);current=name

func update(dt: float,speed: float,alive: bool=true,occupation: String=""):
	if playback==null:return
	for side in ["L","R"]:tree.set("parameters/Grip"+side+"/blend_amount",1.0 if side in grip_hands and action_time<=0 else 0.0)
	tree.set("parameters/Cadence/scale",clampf(speed/(3.9 if speed>3.5 else 2.2),.55,1.45) if speed>.15 and action_time<=0 else 1.0)
	action_time=maxf(0,action_time-dt)
	var wanted="Death01" if not alive else occupation if occupation!="" else "Sprint" if speed>3.5 else "Walk" if speed>.15 else "Idle"
	if alive and occupation=="" and speed>.2:
		if local_velocity.z>.25:wanted="KK_Walking_Backwards"
		elif absf(local_velocity.x)>absf(local_velocity.z)*1.2:wanted="KK_Running_Strafe_Left" if local_velocity.x<0 else "KK_Running_Strafe_Right"
		if not player.has_animation(wanted):wanted="Walk"
	if action_time>0 and alive:wanted=action
	if wanted!=current:
		playback.travel(wanted);current=wanted

func direction(a: String,b: String) -> Vector3:
	var first=skeleton.find_bone(a);var last=skeleton.find_bone(b)
	if first<0 or last<0:return Vector3.DOWN
	return (Basis(Vector3.UP,PI)*(skeleton.get_bone_global_pose(last).origin-skeleton.get_bone_global_pose(first).origin)).normalized()

func retarget(target: Skeleton3D):
	for i in range(target.get_bone_count()):
		var name=str(target.get_bone_name(i));var source_name=name
		if name.begins_with("DEF-"):
			var exact=skeleton.find_bone(name)
			if exact>=0:
				target.set_bone_pose_position(i,skeleton.get_bone_pose_position(exact))
				target.set_bone_pose_rotation(i,skeleton.get_bone_pose_rotation(exact))
			continue
		if not name.begins_with("DEF-"):
			var tokens=name.split("_");var side=""
			if tokens[-1] in ["l","r"]:side="."+tokens[-1].to_upper()
			if tokens[0] in ["spine","neck"]:source_name=HUMAN_MAP.get(name,"")
			else:
				source_name=HUMAN_MAP.get(tokens[0],"")
				if tokens.size()==3 and tokens[1].is_valid_int():source_name+="."+tokens[1]
				source_name+=side
		var source=skeleton.find_bone(source_name)
		if source<0:continue
		var source_rest=skeleton.get_bone_global_rest(source)
		var source_pose=skeleton.get_bone_global_pose(source)
		var target_rest=target.get_bone_global_rest(i)
		var correction=Basis(Quaternion(target_rest.basis.y.normalized(),source_rest.basis.y.normalized()))
		var desired=source_pose.basis*source_rest.basis.inverse()*correction*target_rest.basis
		var parent=target.get_bone_parent(i)
		var parent_pose=target.get_bone_global_pose(parent) if parent>=0 else Transform3D.IDENTITY
		target.set_bone_pose_rotation(i,(parent_pose.basis.inverse()*desired).orthonormalized().get_rotation_quaternion())
		target.set_bone_pose_position(i,target.get_bone_rest(i).origin)
		if name=="pelvis":
			var displacement=source_pose.origin-source_rest.origin
			target.set_bone_pose_position(i,target.get_bone_rest(i).origin+parent_pose.basis.inverse()*displacement)

func walk(n: Node) -> Array:
	var result=[]
	for child in n.get_children():result.append(child);result.append_array(walk(child))
	return result
