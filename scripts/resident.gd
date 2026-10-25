class_name LowGridResident
extends CharacterBody3D

var game: Node3D
var identity=""
var home=Vector3.ZERO
var destination=Vector3.ZERO
var motion: LowGridMotion
var model: Node3D
var clock=0.0
var activity="Idle_Talking"
var target_skeleton: Skeleton3D

func setup(g,id: String,pos: Vector3,job: String="Idle_Talking"):
	game=g;identity=id;home=pos;position=pos;destination=pos;activity=job
	collision_layer=2;collision_mask=1|2
	var collision=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.8;collision.shape=capsule;collision.position.y=.9;add_child(collision)
	var path="res://assets/models/residents/"+id+".glb"
	if ResourceLoader.exists(path):
		model=load(path).instantiate();add_child(model);model.rotation.y=PI
		for n in descendants(model):
			if n is Skeleton3D:target_skeleton=n
		motion=LowGridMotion.new();add_child(motion)
		motion.foot_contact.connect(human_foot_contact)
		if id=="leya" and game.story.prologue==3 and target_skeleton!=null:
			activity="PickUp_Table"
			var hand=BoneAttachment3D.new();hand.bone_name="hand_r";target_skeleton.add_child(hand)
			var head=load("res://assets/models/parts/heads_01.glb").instantiate();hand.add_child(head);head.position=Vector3(0,.07,0);head.rotation.x=-PI/2
	elif id in ["seam","cargo"]:
		var visual=ScrapRobotVisual.new();add_child(visual);visual.setup(game.catalog,game.sim,game.sim.robot("E02" if id=="seam" else "E04"));visual.occupation="Fixing_Kneeling" if id=="seam" else "Push";model=visual
	var sign=Label3D.new();sign.text={"steel":"СТАЛЬНОЙ","mira":"МИРА","yan":"ЯН","seam":"ШОВ","leya":"ЛЕЯ РЕНН"}.get(id,"");sign.position.y=2.05;sign.font_size=22;sign.pixel_size=.0025;sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(sign)
	if game.story.npc_states.has(id):
		var state=game.story.npc_states[id];clock=float(state.get("clock",0));position=Vector3(state.position[0],state.position[1],state.position[2])

func _physics_process(dt):
	if game==null or game.menu_open:return
	if game.ui.modal_open:
		velocity=Vector3.ZERO
		if game.ui.modal_kind=="dialogue":update_visual(dt,0,position.distance_to(game.player.position))
		return
	clock+=dt
	var distance=position.distance_to(game.player.position)
	if distance<3.5:
		var direction=game.player.position-position
		rotation.y=lerp_angle(rotation.y,atan2(-direction.x,-direction.z),dt*3)
		velocity=Vector3.ZERO
	elif identity in ["mira","cargo","resident_2","resident_3"]:
		if destination.distance_to(position)<.2:
			destination=home+Vector3(3 if int(clock/12)%2==0 else 0,0,-3 if int(clock/12)%2==0 else 0)
		var direction=destination-position;direction.y=0;velocity=direction.normalized()*.65 if direction.length()>.15 else Vector3.ZERO
		if velocity.length()>.1:rotation.y=lerp_angle(rotation.y,atan2(-velocity.x,-velocity.z),dt*3)
	if not is_on_floor():velocity.y-=9.8*dt
	move_and_slide()
	update_visual(dt,Vector2(velocity.x,velocity.z).length(),distance)
	game.story.npc_states[identity]={"position":[position.x,position.y,position.z],"clock":clock,"activity":activity}

func update_visual(dt: float,speed: float,distance: float):
	if model is ScrapRobotVisual:model.animate(dt,speed,false,false)
	else:
		if motion!=null and target_skeleton!=null:
			var wanted="Idle_Talking" if distance<3.5 else activity
			if not motion.player.has_animation(wanted):wanted="Idle"
			motion.update(dt,speed,true,wanted if speed<.15 else "")
			motion.retarget(target_skeleton)

func descendants(n) -> Array:
	var result=[]
	if n==null:return result
	for child in n.get_children():result.append(child);result.append_array(descendants(child))
	return result

func human_foot_contact(side: String):
	if velocity.length()<.15 or DisplayServer.get_name()=="headless":return
	var sound=AudioStreamPlayer3D.new();sound.bus="Movement";sound.stream=load("res://assets/audio/movement/footstep_concrete_00"+("1" if side=="left" else "2")+".ogg");sound.volume_db=-21;sound.max_distance=12;add_child(sound);sound.finished.connect(sound.queue_free);sound.play()
