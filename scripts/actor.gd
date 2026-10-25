class_name ScrapActor
extends CharacterBody3D

var game: Node3D
var sim: ScrapSimulation
var state: Dictionary
var visual: ScrapRobotVisual
var is_player=false
var hitboxes={}
var forearm_shapes={}
var cooldown={"left_arm":0.0,"right_arm":0.0}
var ai_phase=0.0
var awareness=0.0
var patrol_origin=Vector3.ZERO
var nav: NavigationAgent3D
var attack_timer=0.0
var disabled_timer=0.0
var reload_until={}
var drone=false
var enemy_name=""
var alerted=false
var uuid=""

func setup(g: Node3D,s: Dictionary,player: bool=false):
	game=g;sim=g.sim;state=s.duplicate(true);is_player=player;drone=state.archetype in ["E05","E06"]
	collision_layer=2;collision_mask=1|2
	var body=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.28;capsule.height=1.75 if not drone else .55;body.shape=capsule;body.position.y=.88 if not drone else 0;add_child(body)
	visual=ScrapRobotVisual.new();add_child(visual);visual.setup(game.catalog,sim,state)
	if not is_player:
		nav=NavigationAgent3D.new();nav.path_desired_distance=.4;nav.target_desired_distance=1;add_child(nav)
		enemy_name=game.catalog.enemies[state.archetype].enemy_name
	build_hitboxes()

func build_hitboxes():
	for area in hitboxes.values():area.queue_free()
	hitboxes.clear()
	forearm_shapes.clear()
	var positions={"sensor":Vector3(0,1.68,0),"torso":Vector3(0,1.25,0),"left_arm":Vector3(-.34,1.25,0),"right_arm":Vector3(.34,1.25,0),"legs":Vector3(0,.5,0),"cpu":Vector3(-.10,1.3,.02),"power_core":Vector3(.12,1.2,.02),"cooling":Vector3(0,1.15,.12),"controller":Vector3(.12,1.4,.1),"memory":Vector3(-.12,1.4,.1),"comm_module":Vector3(0,1.75,.1),"drone_body":Vector3.ZERO,"drone_engine":Vector3(.28,0,0)}
	for slot in state.assembly:
		if not positions.has(slot):continue
		var area=Area3D.new();area.collision_layer=4;area.collision_mask=0;area.set_meta("actor",self);area.set_meta("zone",slot)
		var shape=CollisionShape3D.new();var box=BoxShape3D.new()
		box.size=Vector3(.22,.23,.25) if slot=="sensor" else Vector3(.43,.48,.28) if slot=="torso" else Vector3(.18,.55,.22) if slot in ["left_arm","right_arm"] else Vector3(.48,.8,.3) if slot=="legs" else Vector3(.55,.35,.5) if drone else Vector3(.10,.1,.10)
		shape.shape=box;area.position=positions[slot];area.add_child(shape);add_child(area);hitboxes[slot]=area
		if slot in ["left_arm","right_arm"]:
			box.size=Vector3(.18,.28,.20)
			var lower=CollisionShape3D.new();var lower_box=BoxShape3D.new();lower_box.size=Vector3(.18,.32,.22);lower.shape=lower_box;area.add_child(lower);forearm_shapes[slot]=lower

func _physics_process(dt):
	if game==null or game.menu_open or game.ui.modal_open:return
	sim.tick(state,dt)
	for hand in cooldown:cooldown[hand]=maxf(0,float(cooldown[hand])-dt)
	for slot in hitboxes:
		if not state.assembly.has(slot):hitboxes[slot].collision_layer=0;continue
		if slot in ["left_arm","right_arm"] and visual.mounts.has(slot):
			var upper=visual.joints.get(slot+"UpperArm",visual.mounts[slot])
			var fore=visual.joints.get(slot+"Forearm",upper)
			var upper_basis=upper.global_basis.orthonormalized()
			if upper_basis.determinant()<0:upper_basis.x=-upper_basis.x
			hitboxes[slot].global_transform=Transform3D(upper_basis,upper.to_global(Vector3(0,-.14,0)))
			var fore_basis=fore.global_basis.orthonormalized()
			if fore_basis.determinant()<0:fore_basis.x=-fore_basis.x
			forearm_shapes[slot].global_transform=Transform3D(fore_basis,fore.to_global(Vector3(0,-.14,0)))
		var internal=slot in ["cpu","power_core","cooling","controller","memory"]
		var exposed=not state.assembly.has("torso") or float(state.assembly.torso.durability)/float(state.assembly.torso.max_durability)<=.4
		hitboxes[slot].collision_layer=4 if not state.assembly[slot].destroyed and (not internal or exposed) else 0
	if state.assembly.has("torso") and float(state.assembly.torso.durability)/float(state.assembly.torso.max_durability)<=.4:visual.inspect_internals(true)
	if not state.alive:
		velocity=Vector3.ZERO
		visual.animate(dt,0,false,false)
		return
	if not is_player and not game.active_enemies.has(self):
		velocity=Vector3.ZERO;visual.animate(dt,0,false,false);return
	if is_player:player_movement(dt)
	else:enemy_movement(dt)
	var ranged=str(sim.action_profile(state,"right_arm").get("attack_delivery","melee")) not in ["melee","tool","shield_bash"]
	var ready_to_aim=game.aiming and (ranged or Input.is_action_pressed("aim")) if is_player else alerted and ranged
	visual.animate(dt,Vector2(velocity.x,velocity.z).length(),ready_to_aim,is_player and Input.is_action_pressed("block"))
	if global_position.y < -10:global_position=patrol_origin+Vector3.UP

func player_movement(dt):
	var axis=Input.get_vector("left","right","forward","back")
	var basis=Basis(Vector3.UP,game.yaw if not game.top_view else 0)
	var direction=basis*Vector3(axis.x,0,axis.y)
	var s=sim.stats(state)
	var speed=(4.7 if Input.is_action_pressed("run") else 2.8)*s.speed*clampf(s.mobility/35.0,.55,1.65)
	if not sim.functional(state,"legs"):speed=.45
	if state.energy<=0:speed*=.5
	if Input.is_action_just_pressed("dash") and state.energy>=8 and sim.functional(state,"legs"):
		state.energy-=8;state.heat+=3;disabled_timer=.22
		if direction.length()<.1:direction=-global_basis.z
	if disabled_timer>0:disabled_timer-=dt;speed=11*s.speed*(1+sim.hardware(state,"dash_bonus")/100.0)
	if sim.active(state,"BATTERY_SAVER") and direction.length()>.1:state.energy=maxf(0,state.energy-dt*.25)
	elif direction.length()>.1:state.energy=maxf(0,state.energy-dt*.4*(1-sim.hardware(state,"movement_saving")/100.0))
	velocity.x=move_toward(velocity.x,direction.x*speed,dt*18)
	velocity.z=move_toward(velocity.z,direction.z*speed,dt*18)
	velocity.y-=20*dt
	move_and_slide()
	var target=game.aim_position
	var facing=Vector3(target.x,global_position.y,target.z)-global_position if game.aiming or game.top_view or direction.length_squared()<.01 else direction
	if facing.length_squared()>.01:
		rotation.y=lerp_angle(rotation.y,atan2(-facing.x,-facing.z),clampf(dt*14,0,1))
	if Input.is_action_pressed("fire_right"):shoot("right_arm")
	if Input.is_action_pressed("fire_left"):shoot("left_arm")

func line_of_sight(other: ScrapActor) -> bool:
	if not is_inside_tree() or not is_instance_valid(other) or not other.is_inside_tree():return false
	var start=global_position+Vector3.UP*(0 if drone else 1.4)
	var end=other.global_position+Vector3.UP
	var q=PhysicsRayQueryParameters3D.create(start,end,1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func enemy_movement(dt):
	if game.player==null:return
	ai_phase+=dt;attack_timer-=dt
	var captured=float(state.captured_until)>float(state.time)
	var target=game.player
	if captured:
		var best=1000.0
		for e in game.enemies:
			if e!=self and e.state.alive and e.global_position.distance_to(global_position)<best:target=e;best=e.global_position.distance_to(global_position)
		if target==game.player:velocity=Vector3.ZERO;return
	var dist=global_position.distance_to(target.global_position)
	var sight=line_of_sight(target)
	var sense=18 if sim.functional(state,"sensor") else 4
	if sight and dist<sense:awareness=minf(3,awareness+dt*2*(1-sim.hardware(target.state,"reaction_suppression")/100.0))
	else:awareness=maxf(0,awareness-dt*.3)
	alerted=awareness>0.8
	var destination=patrol_origin+Vector3(sin(ai_phase*.35)*2,0,cos(ai_phase*.35)*2)
	if alerted:destination=target.global_position
	var range_m=2.0 if state.archetype in ["E01","E02","E04"] else 8.0
	if state.archetype=="E09":range_m=13.0
	var dir=Vector3.ZERO
	if alerted and dist<range_m and sight:
		if state.archetype in ["E03","E07","E09"]:dir=global_basis.x*sin(ai_phase*.9)
	else:dir=(destination-global_position).normalized()
	if not drone and nav!=null and NavigationServer3D.map_get_iteration_id(nav.get_navigation_map())>0:
		nav.target_position=destination
		if not (alerted and dist<range_m and sight):dir=(nav.get_next_path_position()-global_position).normalized()
	var separation=Vector3.ZERO
	for other in game.enemies:
		if other==self or not is_instance_valid(other) or not other.state.alive:continue
		var offset=global_position-other.global_position;offset.y=0
		var gap=offset.length()
		if gap>0.01 and gap<1.05:separation+=offset/gap*(1.05-gap)*2.5
	dir=(dir+separation).limit_length(1.0)
	var speed=(1.1 if state.archetype=="E04" else 2.2)*sim.stats(state).speed
	if state.archetype=="E09":speed=3.4
	if not sim.functional(state,"legs") and not drone:speed=0
	if float(state.disabled.get("stagger",0))>float(state.time):speed=0
	if drone:
		velocity=dir*2.0
		velocity.y=clampf((2.2+sin(ai_phase)*.3-global_position.y)*2,-1,1)
		if not sim.functional(state,"drone_engine"):velocity.x=0;velocity.z=0;velocity.y=-3 if global_position.y>.35 else 0
	else:
		velocity.x=dir.x*speed;velocity.z=dir.z*speed;velocity.y-=20*dt
	move_and_slide()
	var face=target.global_position-global_position if alerted else dir
	face.y=0
	if face.length_squared()>.01:rotation.y=lerp_angle(rotation.y,atan2(-face.x,-face.z),dt*5)
	if not alerted or not sight:return
	if state.archetype=="E05":
		if captured:return
		if awareness>=2 and not state.get("alarm_sent",false):state["alarm_sent"]=true;game.raise_alarm(global_position)
		return
	if state.archetype=="E02" and int(state.time)%8==0:
		for e in game.enemies:
			if e!=self and e.state.alive and global_position.distance_to(e.global_position)<4:
				for p in e.state.assembly.values():p.durability=minf(p.max_durability,p.durability+dt*5)
	if state.archetype=="E08" and attack_timer<=0 and dist<11:
		game.queue_hack(self,target);attack_timer=7;return
	if state.archetype=="E10" and attack_timer<=0 and dist<14:
		state.heat=maxf(0,state.heat-15);game.enemy_pulse(self);attack_timer=6
	if dist<range_m+.5:
		if drone:
			if attack_timer<=0:game.perform_attack(self,"right_arm",target);attack_timer=1.4
		else:
			var hand="right_arm" if sim.functional(state,"right_arm") else "left_arm"
			if attack_timer<=0:
				game.perform_attack(self,hand,target);attack_timer=2.3 if state.archetype=="E04" else 1.1

func shoot(hand: String):
	if cooldown[hand]>0 or float(reload_until.get(hand,0))>float(state.time):return
	var error=sim.can_attack(state,hand,game.attack_mode)
	if error!="":game.notice(error);cooldown[hand]=.3;return
	var profile=sim.action_profile(state,hand)
	cooldown[hand]=clampf(1.4-float(profile.get("attack_speed",50))*.013,.18,1.3)
	game.perform_attack(self,hand,null)

func refresh():
	visual.rebuild();build_hitboxes()
