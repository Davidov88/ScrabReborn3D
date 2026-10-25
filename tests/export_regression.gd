extends Node

var failures=[]
var checks=[]

func require(value: bool,message: String):
	checks.append(message)
	if not value:failures.append(message);push_error(message)

func frames(n: int):
	for i in range(n):await get_tree().physics_frame

func key(code: int,pressed: bool):
	var e=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e)

func descendants(n: Node) -> Array:
	var all=[]
	for child in n.get_children():all.append(child);all.append_array(descendants(child))
	return all

func run(game):
	game.ui.close();game.new_game(false);game.ui.close();await frames(5)
	require(game.enemies.size()==1,"Exactly one opponent in first sector")
	for cycle in range(4):
		for mode in [1,2,0]:
			key(KEY_V,true);await frames(2)
			var mouse=InputEventMouseMotion.new();mouse.relative=Vector2(1,0);Input.parse_input_event(mouse)
			await frames(2);key(KEY_V,false);await frames(2)
			require(game.camera_mode==mode,"Camera cycle %d mode %d" % [cycle,mode])
	var canopy=game.world.box(game.player.position+Vector3(0,2.3,0),Vector3(5,.2,7),Color.GRAY,true)
	for mode in [0,2]:
		game.set_camera_mode(mode);await frames(30)
		var yaw=game.yaw;var mouse=InputEventMouseMotion.new();mouse.relative=Vector2(90,-20);Input.parse_input_event(mouse);await frames(5)
		require(absf(game.yaw-yaw)>.1,"Mouse motion beneath canopy, mode %d" % mode)
	canopy.queue_free()
	require(game.spring.spring_length<.05,"First person reaches sensor position")
	var enemy=game.enemies[0];var before=JSON.stringify(enemy.state);var mesh_id=enemy.visual.mounts.right_arm.get_instance_id()
	var item=game.sim.item("S17_PISTOL_ARM");item.location="storage";game.player.state.inventory.append(item)
	require(game.sim.install(game.player.state,game.player.state.inventory.size()-1,"left_arm")=="","Equip player component")
	game.player.refresh()
	require(JSON.stringify(enemy.state)==before,"Player installation leaves enemy state untouched")
	require(enemy.visual.mounts.right_arm.get_instance_id()==mesh_id,"Player installation leaves enemy visual untouched")
	game.player.visual.animate(.15,3,false,false)
	var upper=game.player.visual.joints.right_armUpperArm.rotation.x;var fore=game.player.visual.joints.right_armForearm.rotation.x
	game.player.visual.animate(.15,3,false,false)
	require(not is_equal_approx(upper,game.player.visual.joints.right_armUpperArm.rotation.x),"Shoulder animation")
	require(not is_equal_approx(fore,game.player.visual.joints.right_armForearm.rotation.x),"Elbow animation")
	game.set_camera_mode(0)
	var supply=game.world.interactions.filter(func(i):return i.kind=="supply")[0]
	game.player.position=Vector3(supply.position[0],.05,supply.position[2]);game.interact();game.ui.close()
	require(game.player.state.held.right_arm!=null and game.player.state.held.right_arm.id=="LIGHT_PISTOL","Opening supply equips pistol")
	for i in range(1,game.enemies.size()):game.enemies[i].position=Vector3(5,.05,-95)
	enemy.position=Vector3(0,.05,-7);enemy.patrol_origin=enemy.position;enemy.awareness=3;game.player.position=Vector3(0,.05,-3);game.yaw=0;game.pitch=-.15
	var battery_uid=enemy.state.assembly.power_core.uid;var shots=0
	while enemy.state.alive and shots<12 and game.player.state.alive:
		await frames(40);game.player.rotation.y=0;game.player.visual.animate(1,0,true,false);game.aim_position=enemy.global_position+Vector3(0,1.22,0);game.perform_attack(game.player,"right_arm");shots+=1
		if shots==1 and DisplayServer.get_name()!="headless":
			await frames(5);await RenderingServer.frame_post_draw;game.get_viewport().get_texture().get_image().save_png("D:/GameDev/Projects/ScrapReborn3D/test-results/exported-impact.png")
	require(not enemy.state.alive,"Physical opening encounter defeated in one magazine")
	require(game.player.state.alive,"Player survives opening encounter")
	require(enemy.state.assembly.power_core.uid==battery_uid,"Real battery identity preserved")
	var result=game.sim.extract(game.player.state,enemy.state,"right_arm","careful")
	require(not result.has("error") and not enemy.state.assembly.has("right_arm"),"Actual arm salvaged once")
	game.ui.selected_slot="right_arm";game.ui.workshop_candidate="";game.ui.inventory(true);await frames(2)
	var installs=descendants(game.ui.overlay).filter(func(n):return n is Button and n.text=="УСТАНОВИТЬ" and not n.disabled)
	require(not installs.is_empty(),"Workshop filters compatible components")
	if not installs.is_empty():
		var previous=game.player.state.assembly.right_arm.uid
		installs[0].pressed.emit();await frames(2)
		require(game.ui.modal_kind=="workshop" and game.player.state.assembly.right_arm.uid!=previous,"One-click installation has no confirmation screen")
		var undo=descendants(game.ui.overlay).filter(func(n):return n is Button and n.text=="ОТМЕНИТЬ ПОСЛЕДНЮЮ ЗАМЕНУ")
		require(not undo.is_empty(),"Workshop offers undo")
		if not undo.is_empty():undo[0].pressed.emit();await frames(2);require(game.player.state.assembly.right_arm.uid==previous,"Undo restores exact previous component")
	game.ui.close();game.toggle_vision();await frames(2)
	require(game.sim.active(game.player.state,"LOW_LIGHT_VISION") and game.ui.vision_filter.visible,"Low-light program enables screen filter")
	game.set_camera_mode(2)
	var path="D:/GameDev/Projects/ScrapReborn3D/test-results/regression-camera-save.json"
	require(game.save_game(path),"Regression save is independent of player campaign")
	game.set_camera_mode(0);game.continue_game(path);await frames(3)
	require(game.camera_mode==2,"Save and load restore first-person camera")
	require(not game.enemies[0].state.assembly.has("right_arm"),"Reload does not duplicate salvaged component")
	game.ui.modal_open=true
	if DisplayServer.get_name()!="headless":
		game.set_camera_mode(2);await frames(40);await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png("D:/GameDev/Projects/ScrapReborn3D/test-results/exported-first-person.png")
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"shots":shots,"exported":not OS.has_feature("editor"),"rendered":DisplayServer.get_name()!="headless","version":ProjectSettings.get_setting("application/config/version")}
	ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/export-regression.json",report)
	print("EXPORT_REGRESSION ",report)
	game.set_process(false);get_tree().quit(0 if failures.is_empty() else 1)
