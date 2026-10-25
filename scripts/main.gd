extends Node3D

var catalog: ScrapCatalog
var sim: ScrapSimulation
var player: ScrapActor
var enemies: Array = []
var active_enemies: Array=[]
var world: ScrapWorld
var ui: ScrapUI
var camera: Camera3D
var camera_pivot: Node3D
var spring: SpringArm3D
var yaw=0.0
var pitch=-.23
var top_view=false
var camera_mode=0 # 0 third person, 1 overhead, 2 first person
var top_distance=13.0
var aiming=false
var aim_position=Vector3(0,1,-10)
var target_actor: ScrapActor
var target_zone="torso"
var aim_lock=false
var attack_mode="normal"
var menu_open=true
var training=false
var sector=0
var sector_records={}
var journal: Array=[]
var objectives: Array=[]
var used_objects: Array=[]
var event_until=0.0
var wall_clock=0.0
var autosave_clock=0.0
var camera_shake=0.0
var pending_actions: Array=[]
var effects: Array=[]
var ambience: AudioStreamPlayer
var music: AudioStreamPlayer
var key_actions={"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"run":KEY_SHIFT,"dash":KEY_SPACE,"camera":KEY_V,"block":KEY_Q,"interact":KEY_E,"scan":KEY_F,"reload":KEY_R,"mode":KEY_C,"inventory":KEY_I,"workshop":KEY_B,"tactical":KEY_TAB,"program_1":KEY_1,"program_2":KEY_2,"program_3":KEY_3,"program_4":KEY_4}
var automation=false
var automation_stage=0
var automation_timer=0.0
var perf_frames=0
var perf_seconds=0.0
var performance=[]
var automated_results=[]

func _ready():
	setup_input()
	catalog=ScrapCatalog.new();sim=ScrapSimulation.new(catalog)
	ui=ScrapUI.new();add_child(ui);ui.setup(self)
	setup_environment()
	load_settings()
	player=create_actor(sim.starter(),Vector3(0,.05,1),true)
	enter_sector(0,false)
	if camera!=null:set_camera_mode(0)
	setup_camera()
	setup_audio()
	var args=OS.get_cmdline_user_args()
	if "--manual-qa" in args:DisplayServer.window_set_title("SCRAP REBORN - INPUT TEST")
	automation="--acceptance" in args
	if automation:new_game(false)
	else:ui.menu()
	if "--regression" in args:
		var runner=load("res://tests/export_regression.gd").new();add_child(runner);runner.call_deferred("run",self)
	print("SCRAP_REBORN_READY catalog=",catalog.parts.size()," external=",catalog.visuals.size()," weapons=",catalog.weapons.size()," programs=",catalog.programs.size())

func setup_input():
	key_actions["vision"]=KEY_N
	for action in key_actions:
		if not InputMap.has_action(action):InputMap.add_action(action)
		var key=InputEventKey.new();key.physical_keycode=key_actions[action];InputMap.action_add_event(action,key)
	for pair in [["fire_right",MOUSE_BUTTON_LEFT],["fire_left",MOUSE_BUTTON_RIGHT],["aim",MOUSE_BUTTON_MIDDLE]]:
		InputMap.add_action(pair[0]);var mouse=InputEventMouseButton.new();mouse.button_index=pair[1];InputMap.action_add_event(pair[0],mouse)

func setup_environment():
	var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("080d12");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("63727e");e.ambient_light_energy=.045;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=e;add_child(env)

func setup_camera():
	camera_pivot=Node3D.new();add_child(camera_pivot)
	spring=SpringArm3D.new();spring.collision_mask=1;spring.spring_length=4.5;spring.margin=.22;camera_pivot.add_child(spring)
	var sphere=SphereShape3D.new();sphere.radius=.15;spring.shape=sphere
	camera=Camera3D.new();camera.fov=70;camera.near=.07;camera.far=150;spring.add_child(camera);camera.current=true
	camera_pivot.position=player.global_position+Vector3(0,1.4,0)

func setup_audio():
	if DisplayServer.get_name()=="headless":return
	ambience=AudioStreamPlayer.new();add_child(ambience)
	var path="res://assets/audio/spaceEngineLow_000.ogg"
	if ResourceLoader.exists(path):
		ambience.stream=load(path);ambience.finished.connect(func():ambience.play());ambience.volume_db=-24;ambience.play()
	music=AudioStreamPlayer.new();add_child(music)

func play_sound(kind: String,pos=null):
	if DisplayServer.get_name()=="headless":return
	var choices={"shot":"laserSmall_000.ogg","heavy":"laserLarge_000.ogg","impact":"impactMetal_000.ogg","emp":"forceField_000.ogg","door":"doorOpen_000.ogg","click":"click_001.ogg","scan":"computerNoise_000.ogg","death":"explosionCrunch_000.ogg"}
	var path="res://assets/audio/"+str(choices.get(kind,"impactMetal_000.ogg"))
	if not ResourceLoader.exists(path):return
	var volume=float(ui.settings.ui_volume if kind=="click" else ui.settings.volume)
	if pos!=null:
		var audio=AudioStreamPlayer3D.new();add_child(audio);audio.global_position=pos;audio.stream=load(path);audio.max_distance=35;audio.volume_db=linear_to_db(maxf(.001,volume)) - 7;audio.finished.connect(audio.queue_free);audio.play()
	else:
		var audio=AudioStreamPlayer.new();add_child(audio);audio.stream=load(path);audio.volume_db=linear_to_db(maxf(.001,volume))-8;audio.finished.connect(audio.queue_free);audio.play()

func create_actor(state: Dictionary,pos: Vector3,is_player: bool=false) -> ScrapActor:
	var a=ScrapActor.new();add_child(a);a.position=pos;a.patrol_origin=pos;a.setup(self,state,is_player);return a

func new_game(test_ground: bool):
	training=test_ground;menu_open=false;sector_records.clear();journal.clear();used_objects.clear();objectives.clear()
	if player!=null:remove_child(player);player.queue_free()
	player=create_actor(sim.starter(),Vector3(0,.05,1),true)
	enter_sector(0,false)
	set_camera_mode(0)
	if training:
		grant_catalog()
		notice("Полигон: весь каталог доступен. E возле каталога создаёт новые цели.")
	else:
		ui.message("ВОССТАНОВЛЕНИЕ СОЗНАНИЯ",ScrapCampaign.SECTORS[0].intro+"\n\nWASD — движение. V — смена камеры. E — взаимодействие. F — сканирование. Tab — тактическое замедление.")
	update_mouse()

func snapshot_sector() -> Dictionary:
	var actors=[]
	for a in enemies:
		if is_instance_valid(a):actors.append({"uuid":a.uuid,"state":a.state,"position":[a.position.x,a.position.y,a.position.z],"rotation":a.rotation.y,"patrol":[a.patrol_origin.x,a.patrol_origin.y,a.patrol_origin.z]})
	return {"enemies":actors,"used":used_objects.duplicate(),"objectives":objectives.duplicate()}

func enter_sector(index: int,preserve: bool=true):
	if preserve and world!=null:sector_records[str(sector)]=snapshot_sector()
	pending_actions.clear();active_enemies.clear()
	sector=index;target_actor=null;target_zone="torso";aim_lock=false
	for a in enemies:remove_child(a);a.queue_free()
	enemies.clear()
	if world!=null:remove_child(world);world.queue_free()
	world=ScrapWorld.new();add_child(world);world.build(self,index,training)
	used_objects=[];objectives=[]
	if sector_records.has(str(index)):
		var record=sector_records[str(index)];used_objects=record.used;objectives=record.objectives
		if index==0 and record.enemies.size()>1:record.enemies=record.enemies.slice(0,1)
		for data in record.enemies:
			var a=create_actor(data.state,Vector3(data.position[0],data.position[1],data.position[2]));a.uuid=data.uuid;a.rotation.y=data.rotation;a.patrol_origin=Vector3(data.patrol[0],data.patrol[1],data.patrol[2]);enemies.append(a)
	else:
		var roster=[["E01"]] if index==0 else ScrapCampaign.SECTORS[index].enemies
		for group in range(roster.size()):
			for j in range(roster[group].size()):
				var id=roster[group][j]
				var a=create_actor(sim.robot(id),Vector3(-1.9+j*3.8,2.2 if id in ["E05","E06"] else .05,-16-group*30))
				a.uuid="%d-%d-%d" % [index,group,j];enemies.append(a)
	for item in world.interactions:
		if item.id in used_objects:item.used=true;item.label.modulate=Color("435b58")
	player.position=Vector3(0,.05,1);player.patrol_origin=player.position;player.velocity=Vector3.ZERO
	if camera_pivot!=null:camera_pivot.position=player.global_position+Vector3(0,1.4,0)
	if not training and preserve:save_game()
	print("SECTOR_LOADED ",index," enemies=",enemies.size())

func completed_objectives() -> int:
	return objectives.size()

func update_mouse():
	var wanted=Input.MOUSE_MODE_VISIBLE if menu_open or ui.modal_open or top_view or Input.is_action_pressed("tactical") else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode!=wanted:Input.mouse_mode=wanted

func _input(event):
	if ui!=null and ui.rebind_action!="":return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if ui.modal_open:
			if menu_open:ui.menu()
			else:ui.close()
		else:ui.pause_menu()
		return
	if menu_open or ui.modal_open:return
	if event is InputEventMouseMotion and not top_view and not Input.is_action_pressed("tactical"):
		yaw-=event.relative.x*float(ui.settings.sensitivity);pitch=clampf(pitch-event.relative.y*float(ui.settings.sensitivity),-1.0,.6)
	if event is InputEventMouseButton and top_view:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:top_distance=clampf(top_distance-1,8,20)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:top_distance=clampf(top_distance+1,8,20)
	if event.is_action_pressed("camera") and not event.is_echo():
		set_camera_mode((camera_mode+1)%3)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("vision") and not event.is_echo():
		toggle_vision();get_viewport().set_input_as_handled();return
	if Input.is_action_just_pressed("interact"):interact()
	if Input.is_action_just_pressed("scan"):scan_target()
	if Input.is_action_just_pressed("inventory"):ui.inventory(false)
	if Input.is_action_just_pressed("workshop"):
		var near=world.near(player.position)
		if near.get("kind","")=="bench":ui.inventory(true)
		else:notice("Для замены узлов подойдите к верстаку")
	if Input.is_action_just_pressed("mode"):
		var modes=ScrapSimulation.MODES.keys();attack_mode=modes[(modes.find(attack_mode)+1)%modes.size()];notice(ScrapSimulation.MODE_NAMES[attack_mode])
	if Input.is_action_just_pressed("reload"):
		for hand in ["left_arm","right_arm"]:
			var error=sim.reload(player.state,hand)
			if error!="":notice(error)
			player.reload_until[hand]=player.state.time+1.2
		play_sound("click")
	for i in range(4):
		if Input.is_action_just_pressed("program_"+str(i+1)):start_program(i)
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_F5:save_game();notice("Контрольная точка сохранена")
		if event.keycode==KEY_F9:continue_game()
	if event is InputEventMouseButton and event.pressed and Input.is_action_pressed("tactical") and target_actor!=null:
		if event.button_index==MOUSE_BUTTON_LEFT:ui.scan(target_actor);get_viewport().set_input_as_handled()

func _process(delta):
	var real_dt=delta/maxf(Engine.time_scale,.01)
	wall_clock+=real_dt
	if camera==null or player==null:return
	var tactical=Input.is_action_pressed("tactical") and not ui.modal_open and not menu_open
	Engine.time_scale=.15 if tactical else 1.0
	update_mouse()
	aiming=Input.is_action_pressed("aim") or tactical or Input.is_action_pressed("fire_right") or Input.is_action_pressed("fire_left") or camera_mode==2
	var focus=player.global_position+Vector3(0,1.69 if camera_mode==2 else 1.4,0)
	camera_pivot.position=camera_pivot.position.lerp(focus,clampf(real_dt*14,0,1))
	var target_rot=Vector3(-PI/3,0,0) if top_view else Vector3(pitch,yaw,0)
	camera_pivot.quaternion=camera_pivot.quaternion.slerp(Quaternion.from_euler(target_rot),clampf(real_dt*9,0,1))
	spring.spring_length=lerpf(spring.spring_length,0.0 if camera_mode==2 else top_distance if top_view else 2.6 if Input.is_action_pressed("aim") else 4.3,clampf(real_dt*12,0,1))
	camera.fov=lerpf(camera.fov,75 if camera_mode==2 else 50 if top_view else 55 if Input.is_action_pressed("aim") else 70,clampf(real_dt*9,0,1))
	if ui.settings.shake and camera_shake>0:
		camera.h_offset=sin(wall_clock*61)*camera_shake*.025;camera.v_offset=cos(wall_clock*47)*camera_shake*.025;camera_shake=maxf(0,camera_shake-real_dt*5)
	else:camera.h_offset=0;camera.v_offset=0
	if not menu_open and not ui.modal_open:update_aim()
	player.visual.aim_pitch=clampf(atan2(aim_position.y-player.position.y-1.45,Vector2(aim_position.x-player.position.x,aim_position.z-player.position.z).length()),-.8,.8)
	world.update_occlusion(top_view,player.position)
	ui.update_hud()
	if wall_clock>event_until:ui.event_label.text=""
	if not menu_open and not ui.modal_open:
		active_enemies=enemies.filter(func(a):return is_instance_valid(a) and a.state.alive)
		active_enemies.sort_custom(func(a,b):return a.position.distance_squared_to(player.position)<b.position.distance_squared_to(player.position))
		if active_enemies.size()>6:active_enemies.resize(6)
		process_pending(delta)
		if not player.state.alive:
			ui.message("СВЯЗЬ С КОРПУСОМ ПОТЕРЯНА","Критический узел отключён. Восстановите последнюю контрольную точку.",continue_game)
	for e in effects.duplicate():
		e.life-=delta
		if e.life<=0:e.node.queue_free();effects.erase(e)
	if automation:acceptance_step(real_dt)
	perf_frames+=1;perf_seconds+=real_dt
	if perf_seconds>=2:
		performance.append({"sector":sector,"fps":perf_frames/perf_seconds,"memory":OS.get_static_memory_usage(),"time":wall_clock});perf_frames=0;perf_seconds=0

func set_camera_mode(mode: int):
	camera_mode=posmod(mode,3)
	top_view=camera_mode==1
	player.visual.set_first_person(camera_mode==2)
	if camera_mode==2:pitch=clampf(pitch,-.9,.9)
	update_mouse()
	notice(["Камера от третьего лица","Камера сверху","Камера от первого лица"][camera_mode])

func toggle_vision():
	var r=player.state
	if not sim.functional(r,"sensor"):notice("Сенсор отключён — усиление зрения недоступно");return
	if "LOW_LIGHT_VISION" not in r.programs:r.programs.append("LOW_LIGHT_VISION")
	if "LOW_LIGHT_VISION" not in r.loaded and sim.stats(r).cpu_load+1>sim.stats(r).cpu_cap:notice("Нужен 1 свободный CPU для усиления зрения");return
	var error=sim.load_program(r,"LOW_LIGHT_VISION")
	if error!="":notice(error);return
	ui.update_hud()
	notice("УСИЛЕННОЕ ЗРЕНИЕ / N — отключить / 1 CPU, 0,5 энергии в сек" if "LOW_LIGHT_VISION" in r.loaded else "Обычный сенсорный режим")

func update_aim():
	var screen=get_viewport().get_visible_rect().size/2
	if top_view or Input.is_action_pressed("tactical"):screen=get_viewport().get_mouse_position()
	var start=camera.project_ray_origin(screen);var direction=camera.project_ray_normal(screen)
	var query=PhysicsRayQueryParameters3D.create(start,start+direction*120,1|4)
	query.collide_with_areas=true
	var exclude: Array[RID]=[]
	for a in player.hitboxes.values():exclude.append(a.get_rid())
	query.exclude=exclude
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		aim_position=hit.position
		if hit.collider.has_meta("actor"):
			var actor=hit.collider.get_meta("actor")
			if actor!=player:
				if target_actor!=actor:aim_lock=false
				target_actor=actor
				if not aim_lock:target_zone=hit.collider.get_meta("zone")
	else:aim_position=start+direction*60
	if aim_lock and target_actor!=null and is_instance_valid(target_actor) and target_actor.hitboxes.has(target_zone) and (Input.is_action_pressed("aim") or Input.is_action_pressed("tactical")):
		var locked_position=target_actor.hitboxes[target_zone].global_position
		if direction.dot((locked_position-start).normalized())>.97 and player.line_of_sight(target_actor):aim_position=locked_position
	if target_actor!=null and (not is_instance_valid(target_actor) or player.position.distance_to(target_actor.position)>35):target_actor=null

func attack_profile(actor: ScrapActor,hand: String) -> Dictionary:
	if actor.drone:
		var d=catalog.parts.DRONE_GUNPOD_GP4.duplicate(true);d.attack_delivery="projectile";return d
	return sim.action_profile(actor.state,hand)

func perform_attack(actor: ScrapActor,hand: String,ai_target: ScrapActor=null):
	if not actor.state.alive:return
	var mode=attack_mode if actor.is_player else "normal"
	var profile=attack_profile(actor,hand)
	if not actor.drone:
		var error=sim.can_attack(actor.state,hand,mode)
		if error!="":
			if actor.is_player:notice(error)
			return
		sim.spend_attack(actor.state,hand,mode)
	actor.visual.flash=1
	var origin=actor.visual.muzzle(hand)
	var point=aim_position if ai_target==null else ai_target.global_position+Vector3(0,.1 if ai_target.drone else 1.25,0)
	var delivery=str(profile.get("attack_delivery","melee"))
	actor.visual.kick(hand,"melee" if delivery in ["melee","tool","shield_bash"] else delivery)
	if mode=="hack" or delivery=="hack":
		var target=ai_target if ai_target!=null else target_actor
		if target!=null and origin.distance_to(target.position)<10:
			queue_hack(actor,target)
		return
	var distance={"melee":1.8,"short":9.0,"medium":25.0,"long":65.0}.get(str(profile.get("range_band",profile.get("range","medium"))),25.0)
	if delivery in ["melee","tool","shield_bash"]:distance=2.1
	var direction=(point-origin).normalized()
	if not actor.is_player and ai_target!=null and not sim.functional(actor.state,"sensor"):direction=direction.rotated(Vector3.UP,sin(actor.state.time*2)*.18)
	var accuracy=float(profile.get("attack_accuracy",70))
	accuracy+=sim.hardware(actor.state,"accuracy_bonus")
	accuracy+=float(sim.slot_def(actor.state,"sensor").get("accuracy_bonus",0))*sim.condition(actor.state.assembly.get("sensor"))
	var dispersion=maxf(0,(100-accuracy))*.0007
	if not sim.functional(actor.state,"sensor"):dispersion*=4
	var resource_stats=sim.stats(actor.state)
	dispersion*=1.0+maxf(0,resource_stats.cpu_ratio-1)+maxf(0,resource_stats.load_ratio-1)
	if sim.active(actor.state,"SERVO_SYNC"):dispersion*=.8
	if sim.active(actor.state,"RECOIL_CONTROL"):dispersion*=.7
	if mode=="precision" or (actor.is_player and Input.is_action_pressed("aim")):dispersion*=.3
	if sim.active(actor.state,"PRECISION_STRIKE"):dispersion*=.3
	if actor.state.heat>70:dispersion*=1.8
	direction=direction.rotated(Vector3.UP,sin(float(actor.state.shot_index)*2.399)*dispersion)
	var rays=6 if delivery=="cone" else 3 if mode=="burst" else 1
	var hit_any=false
	for i in range(rays):
		var raydir=direction.rotated(Vector3.UP,(float(i)-float(rays-1)*.5)*(.055 if delivery=="cone" else .01))
		var end=origin+raydir*float(distance)
		var query=PhysicsRayQueryParameters3D.create(origin,end,1|4);query.collide_with_areas=true
		var exclude: Array[RID]=[]
		for a in actor.hitboxes.values():exclude.append(a.get_rid())
		query.exclude=exclude
		var hit=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end=hit.position
			ScrapEffects.sparks(self,end,Color("ffcb72"),18)
			if hit.collider.has_meta("actor"):
				var victim=hit.collider.get_meta("actor");var zone=hit.collider.get_meta("zone")
				if victim!=actor:apply_hit(actor,victim,zone,profile,mode,.45 if delivery=="cone" else .6 if rays==3 else 1.0);hit_any=true
		if delivery not in ["melee","tool","shield_bash"]:beam(origin,end,Color("74c2d0") if profile.get("damage_type","") in ["emp","energy"] else Color("e5b878"),.06 if delivery in ["beam","arc"] else .018,.16 if delivery in ["beam","arc"] else .07)
	if delivery in ["pulse","arc"]:
		ScrapEffects.pulse(self,origin,Color("69aebd"),4)
		for victim in [player]+enemies:
			if victim!=actor and victim.state.alive and origin.distance_to(victim.global_position)<5 and actor.line_of_sight(victim):
				apply_hit(actor,victim,"torso" if victim.state.assembly.has("torso") else "drone_body",profile,mode,.45)
	play_sound("impact" if delivery in ["melee","tool","shield_bash"] else "emp" if delivery=="pulse" else "heavy" if delivery in ["beam","cone","arc"] else "shot",origin)
	if actor.is_player and ui.settings.shake:camera_shake=.7 if hit_any else .3

func apply_hit(attacker: ScrapActor,victim: ScrapActor,zone: String,profile: Dictionary,mode: String,scale: float):
	if not victim.is_player and victim.state.archetype in ["E03","E07","E10"] and sim.functional(victim.state,"left_arm") and victim.state.heat<70:
		var toward=(attacker.position-victim.position).normalized()
		if (-victim.global_basis.z).dot(toward)>.4 and not (victim.state.archetype=="E10" and objectives.size()>=2):zone="left_arm";scale*=.45
	if victim==player and Input.is_action_pressed("block"):
		var shield=sim.slot_def(player.state,"left_arm")
		if shield.get("is_shield_arm",false) and sim.functional(player.state,"left_arm"):
			var toward=(attacker.position-player.position).normalized()
			if (-player.global_basis.z).dot(toward)>.25:zone="left_arm";scale*=.35*(1-sim.hardware(player.state,"shield_bonus")/100.0)
	if sim.active(victim.state,"AUTO_PARRY") and float(victim.state.time)-float(victim.state.get("last_parry",-5))>4:
		victim.state["last_parry"]=victim.state.time;scale*=.5
	var alive_before=victim.state.alive
	var result=sim.damage(attacker.state,victim.state,zone,profile,mode,scale)
	victim.visual.hurt=1;victim.alerted=true;victim.awareness=3
	if attacker.is_player:notice("%s / %s  −%.0f  %s" % [victim.enemy_name,ScrapCatalog.zone_label(result.zone),result.damage,"РАЗРУШЕН" if result.get("destroyed",false) else "ОТКЛЮЧЁН" if result.get("disabled",false) else ""])
	play_sound("impact",victim.global_position+Vector3.UP)
	if result.get("destroyed",false):victim.refresh()
	if alive_before and not victim.state.alive:
		ScrapEffects.smoke(self,victim.position+Vector3.UP)
		play_sound("death",victim.position)
		if attacker.is_player:player.state.credits+=8
		victim.visual.rebuild()

func beam(start: Vector3,end: Vector3,color: Color,width: float,life: float):
	var length=start.distance_to(end)
	if length<.01:return
	var mesh=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=width;cylinder.bottom_radius=width;cylinder.height=length;cylinder.radial_segments=6;mesh.mesh=cylinder
	var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=mat;add_child(mesh);mesh.global_position=(start+end)/2;mesh.quaternion=Quaternion(Vector3.UP,(end-start).normalized());effects.append({"node":mesh,"life":life})

func queue_hack(attacker: ScrapActor,target: ScrapActor):
	if not attacker.drone and not sim.has_hack_port(attacker.state):
		if attacker.is_player:notice("Для взлома нужен хакерский манипулятор")
		return
	if attacker.position.distance_to(target.position)>11 or not attacker.line_of_sight(target):return
	pending_actions.append({"kind":"hack","remaining":2.5,"actor":attacker,"target":target,"origin":attacker.position,"program":""})
	beam(attacker.visual.muzzle("right_arm"),target.position+Vector3.UP,Color("a78dbd"),.025,2.5)
	if target==player:notice("ВНЕШНЕЕ ПОДКЛЮЧЕНИЕ: прервите контакт или уничтожьте хакера")

func start_program(index: int):
	if index>=player.state.hotbar.size():return
	var id=player.state.hotbar[index]
	var def=catalog.programs[id]
	var target=target_actor
	if def.type=="hack" and (target==null or not target.state.alive):notice("Нужна активная цель");return
	if def.type=="hack" and (not player.line_of_sight(target) or player.position.distance_to(target.position)>11):notice("Нет связи с целью");return
	pending_actions.append({"kind":"program","remaining":maxf(.1,float(def.boot_time)),"actor":player,"target":target,"program":id,"origin":player.position})
	notice("Запуск: "+catalog.program_label(id))

func process_pending(dt: float):
	for action in pending_actions.duplicate():
		if not is_instance_valid(action.actor) or not action.actor.state.alive:pending_actions.erase(action);continue
		if action.kind in ["hack","program"] and action.get("target")!=null:
			if not is_instance_valid(action.target) or action.actor.position.distance_to(action.target.position)>11 or not action.actor.line_of_sight(action.target):notice("Соединение прервано");pending_actions.erase(action);continue
		if action.kind=="salvage" and (not is_instance_valid(action.target) or action.actor.position.distance_to(action.origin)>1.0):notice("Демонтаж прерван перемещением");pending_actions.erase(action);continue
		action.remaining-=dt
		if action.remaining>0:continue
		if action.kind=="hack":action.target.state.disabled["right_arm"]=action.target.state.time+4;action.target.state.disabled["sensor"]=action.target.state.time+4
		elif action.kind=="program":
			var target=action.target.state if action.get("target")!=null and is_instance_valid(action.target) else {}
			notice(sim.activate_program(action.actor.state,action.program,target))
		elif action.kind=="salvage":
			var result=sim.extract(player.state,action.target.state,action.zone,action.method)
			if result.has("error"):notice(result.error)
			else:notice("Деталь снята: "+catalog.label(result.item.id));action.target.refresh()
		pending_actions.erase(action)

func begin_salvage(actor: ScrapActor,zone: String,method: String,seconds: float):
	ui.close();pending_actions.append({"kind":"salvage","remaining":seconds,"actor":player,"target":actor,"zone":zone,"method":method,"origin":player.position})
	notice("Демонтаж %s / %.1f с" % [ScrapCatalog.zone_label(zone),seconds],seconds)

func scan_target():
	if not sim.functional(player.state,"sensor"):notice("Сенсор отключён. Нужен ремонт.");return
	if player.state.energy<2:notice("Недостаточно энергии для сканирования");return
	player.state.energy-=2
	if target_actor==null:
		var best=float(sim.slot_def(player.state,"sensor").get("scan_range",18))*(1+sim.hardware(player.state,"scan_bonus")/100.0)
		for a in enemies:
			var dist=a.position.distance_to(player.position)
			if dist<best and player.line_of_sight(a):best=dist;target_actor=a
	if target_actor!=null:
		play_sound("scan");target_actor.state.scan_until=target_actor.state.time+30;ui.scan(target_actor)

func interact():
	var near=world.near(player.position)
	if near.is_empty():
		var corpse: ScrapActor
		var best=2.8
		for a in enemies:
			if not a.state.alive and a.position.distance_to(player.position)<best:corpse=a;best=a.position.distance_to(player.position)
		if corpse!=null:ui.salvage(corpse)
		return
	match near.kind:
		"return":
			var threat=false
			for a in enemies:
				if a.state.alive and a.alerted and a.position.distance_to(player.position)<12:threat=true
			if threat:notice("Маршрут закрыт до выхода из боя");return
			enter_sector(maxi(0,sector-1));player.position=Vector3(0,.05,-98)
		"bench":
			if not training:save_game()
			ui.inventory(true)
		"terminal":
			var objective_index=int(near.data.objective)
			if objective_index not in objectives:objectives.append(objective_index)
			near.used=true;used_objects.append(near.id);near.label.modulate=Color("526b62");journal.append(near.data.text)
			if not training:save_game()
			ui.message(near.title,near.data.text)
		"cache":
			grant_partition(sector);near.used=true;used_objects.append(near.id);notice("Оборудование и программы добавлены. I — инвентарь.")
		"supply":
			var loadouts=[["PIPE_CLUB","SCRAP_KNIFE","LIGHT_PISTOL"],["STUN_BATON","CUTTER_TOOL","NAIL_GUN"],["COIL_PISTOL","PULSE_SHOTGUN","EMP_THROWER"],["THERMAL_SAW","RAIL_RIFLE","SMART_NEEDLE"],["ARC_SPIKER_PROTOTYPE"]]
			for id in loadouts[sector]:player.state.weapons.append(sim.item(id))
			if sector==0 and player.state.held.right_arm==null:
				sim.equip_weapon(player.state,player.state.weapons.size()-1,"right_arm");player.refresh()
			for id in player.state.ammo:player.state.ammo[id]+=36
			player.state.credits+=45;near.used=true;used_objects.append(near.id);ui.inventory(false,"weapons")
		"catalog":grant_catalog();respawn_training();ui.inventory(true)
		"exit":
			if objectives.size()<3:notice("Сначала восстановите три управляющих контура");return
			var alive=false
			for a in enemies:
				if a.state.alive:alive=true
			if alive:notice("Шлюз заблокирован: активные боевые системы в секторе");return
			if sector==4:
				player.state["chapter_complete"]=true;save_game();ui.message("ГЛАВА 01 ЗАВЕРШЕНА","Внешний приказ прерван. У вас есть подтверждение, что авария была организована.\n\nКорпус покидает комплекс. Корпоративная подпись сохранена в журнале.",func():ui.menu())
			else:enter_sector(sector+1);ui.message(ScrapCampaign.SECTORS[sector].title,ScrapCampaign.SECTORS[sector].intro)

func grant_partition(index: int):
	var part_ids=catalog.parts.keys();part_ids.sort()
	for id in ScrapCampaign.reward_partition(part_ids,index):player.state.inventory.append(sim.item(id))
	for p in player.state.inventory:
		if p.get("location","")=="installed":p.location="storage"
	var program_ids=catalog.programs.keys()
	for id in ScrapCampaign.reward_partition(program_ids,index):
		if id not in player.state.programs:player.state.programs.append(id)
	player.state.credits+=120

func grant_catalog():
	player.state.inventory.clear();player.state.weapons.clear()
	for id in catalog.parts:player.state.inventory.append(sim.item(id))
	for id in catalog.weapons:player.state.weapons.append(sim.item(id))
	for p in player.state.inventory+player.state.weapons:p.location="storage"
	player.state.programs=catalog.programs.keys();player.state.credits=10000
	for id in player.state.ammo:player.state.ammo[id]=999

func respawn_training():
	for a in enemies:a.queue_free()
	enemies.clear()
	for i in range(10):
		var id="E%02d" % (i+1);var a=create_actor(sim.robot(id),Vector3((i%2)*4-2,2.2 if id in ["E05","E06"] else .05,-12-floori(i/2.0)*17));a.uuid="training-"+id;enemies.append(a)

func raise_alarm(pos: Vector3):
	var active_count=0
	for a in enemies:
		if a.state.alive and a.position.distance_to(player.position)<30:active_count+=1
	if active_count<6 and not used_objects.has("alarm_reserve"):
		var a=create_actor(sim.robot("E03"),pos+Vector3(3,-pos.y+.05,-5));a.uuid="alarm-reserve";a.awareness=3;enemies.append(a);used_objects.append("alarm_reserve");notice("ТРЕВОГА: резерв охраны получил координаты")

func enemy_pulse(actor: ScrapActor):
	if actor.position.distance_to(player.position)<9 and actor.line_of_sight(player):
		var profile={"attack_damage":15,"damage_type":"impulse","stability_damage":40,"crit_destroy_risk":6}
		apply_hit(actor,player,"legs",profile,"disable",1)
		beam(actor.position+Vector3.UP,player.position+Vector3.UP,Color("a6bed0"),.12,.3)

func notice(text: String,duration: float=3.0):
	if text=="":return
	ui.event_label.text=text;event_until=wall_clock+duration

func save_game(path: String="") -> bool:
	if training:return false
	if path=="":path=ScrapPersistence.DIRECTORY+"/acceptance-campaign.json" if automation else ScrapPersistence.SAVE
	for a in enemies:
		if a.state.alive and a.alerted and a.position.distance_to(player.position)<12:notice("Нельзя сохранить во время боя");return false
	sector_records[str(sector)]=snapshot_sector()
	var data={"version":1,"player":player.state,"sector":sector,"sectors":sector_records,"journal":journal,"position":[player.position.x,player.position.y,player.position.z],"camera":{"mode":camera_mode,"top":top_view,"yaw":yaw,"pitch":pitch,"distance":top_distance},"serial":sim.serial,"saved_at":Time.get_datetime_string_from_system()}
	return ScrapPersistence.write(path,data)==OK

func continue_game(path: String=""):
	if path=="":path=ScrapPersistence.DIRECTORY+"/acceptance-campaign.json" if automation else ScrapPersistence.SAVE
	var data=ScrapPersistence.read(path)
	if data.is_empty():notice("Сохранение не найдено");ui.menu();return
	menu_open=false;training=false;ui.close();sim.serial=int(data.serial);sector_records=data.sectors;journal=data.journal
	if player!=null:remove_child(player);player.queue_free()
	player=create_actor(data.player,Vector3.ZERO,true)
	enter_sector(int(data.sector),false)
	player.position=Vector3(data.position[0],data.position[1],data.position[2]);top_view=data.camera.top;yaw=data.camera.yaw;pitch=data.camera.pitch;top_distance=data.camera.distance
	set_camera_mode(int(data.camera.get("mode",1 if top_view else 0)))
	if data.get("recovered_backup",false):notice("Основной файл повреждён. Восстановлена резервная копия.")
	update_mouse()

func load_settings():
	var path=ScrapPersistence.DIRECTORY+"/settings.json"
	if FileAccess.file_exists(path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			ui.settings.merge(data.get("settings",{}),true)
			for action in data.get("keys",{}):
				if InputMap.has_action(action):
					InputMap.action_erase_events(action);var k=InputEventKey.new();k.physical_keycode=int(data.keys[action]);InputMap.action_add_event(action,k)

func apply_settings():
	var keys={}
	for action in key_actions:
		var events=InputMap.action_get_events(action)
		if not events.is_empty():keys[action]=events[0].physical_keycode
	ScrapPersistence.write(ScrapPersistence.DIRECTORY+"/settings.json",{"settings":ui.settings,"keys":keys})
	get_viewport().msaa_3d=Viewport.MSAA_DISABLED if int(ui.settings.quality)==0 else Viewport.MSAA_2X
	if ambience!=null:ambience.volume_db=linear_to_db(maxf(.001,float(ui.settings.ambience)))-14

func acceptance_step(dt: float):
	# Exported integration runner: normal UI/world/simulation paths, no fake completion flag.
	automation_timer+=dt
	if automation_timer<1:return
	automation_timer=0
	if ui.modal_open:ui.close()
	match automation_stage:
		0:
			for mode in [1,2,0,1,2,0]:set_camera_mode(mode);assert(camera_mode==mode)
			automated_results.append("three_camera_modes_repeated")
		1:
			top_view=false;automated_results.append("third_person_camera")
		2:
			var enemy=enemies[0]
			var p=enemy.state.assembly.left_arm
			var uid=p.uid;var durability=p.durability
			enemy.state.alive=false
			var result=sim.extract(player.state,enemy.state,"left_arm","careful")
			assert(result.item.uid==uid and result.item.durability==durability)
			assert(sim.extract(player.state,enemy.state,"left_arm","careful").has("error"))
			automated_results.append("exact_salvage_no_duplicate")
		3,4,5,6,7:
			var index=automation_stage-3
			enter_sector(index,false)
			for enemy in enemies:
				while enemy.state.alive:
					var profile={"attack_damage":40,"armor_pen":100,"damage_type":"kinetic","crit_destroy_risk":0}
					apply_hit(player,enemy,"cpu",profile,"precision",1)
			for item in world.interactions:
				if item.kind=="terminal":
					player.position=Vector3(item.position[0],.05,item.position[2]);interact();ui.close()
			assert(objectives.size()==3)
			grant_partition(index)
			automated_results.append("sector_"+str(index)+"_objectives_and_combat")
		8:
			player.position=Vector3(0,.05,-100);interact();ui.close()
			assert(player.state.get("chapter_complete",false));automated_results.append("chapter_complete")
		9:
			set_camera_mode(2);assert(save_game());continue_game();assert(player.state.get("chapter_complete",false));assert(camera_mode==2);automated_results.append("save_reload_completed_chapter_and_first_person_camera")
		10:
			automation=false
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("D:/GameDev/Projects/ScrapReborn3D/test-results/acceptance.png")
			ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/exported-acceptance.json",{"checks":automated_results,"performance":performance,"elapsed_seconds":wall_clock,"note":"Automated world/combat integration; does not replace manual 60–90 minute playthrough, visual approval or hour-long soak."})
			print("EXPORTED_ACCEPTANCE_OK ",automated_results)
			set_process(false)
			pending_actions.clear();effects.clear();target_actor=null;enemies.clear()
			for child in get_children():child.queue_free()
			ScrapRobotVisual.model_cache.clear();ScrapRobotVisual.wear_cache.clear()
			get_tree().create_timer(.1).timeout.connect(get_tree().quit)
	automation_stage+=1

