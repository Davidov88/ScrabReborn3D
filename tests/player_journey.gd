extends SceneTree

var checks=[]
var scene

func _initialize():call_deferred("run")

func frames(n: int):
	for i in range(n):await physics_frame

func key(code: int,pressed: bool):
	var e=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e)

func require(value: bool,message: String):
	if not value:push_error(message);quit(1)
	checks.append(message)

func run():
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	scene.ui.close();scene.new_game(false);scene.ui.close();scene.automation=false
	await frames(10)
	var start=scene.player.position
	key(KEY_W,true);await frames(65);key(KEY_W,false);await frames(10)
	require(scene.player.position.z<start.z-1,"WASD input moves CharacterBody3D")
	for cycle in range(4):
		for mode in [1,2,0]:
			key(KEY_V,true);await frames(2)
			var noise=InputEventMouseMotion.new();noise.relative=Vector2(1,0);Input.parse_input_event(noise)
			await frames(2);key(KEY_V,false);await frames(2)
			require(scene.camera_mode==mode,"V repeated cycle %d mode %d ignores unrelated mouse events" % [cycle,mode])
	scene.set_camera_mode(2);await frames(50)
	require(scene.spring.spring_length<.02,"First person camera reaches head mount")
	var canopy=scene.world.box(scene.player.position+Vector3(0,2.3,0),Vector3(5,.2,7),Color.GRAY,true)
	await frames(4)
	for mode in [0,2]:
		scene.set_camera_mode(mode);await frames(35)
		var old_yaw=scene.yaw
		var motion=InputEventMouseMotion.new();motion.relative=Vector2(90,-20);Input.parse_input_event(motion)
		await frames(6)
		require(absf(scene.yaw-old_yaw)>.1,"Mouse rotates camera beneath canopy in mode %d" % mode)
	canopy.queue_free();scene.set_camera_mode(0)
	var supply=scene.world.interactions.filter(func(i):return i.kind=="supply")[0]
	scene.player.position=Vector3(supply.position[0],.05,supply.position[2]);await frames(3)
	key(KEY_E,true);await frames(2);key(KEY_E,false)
	require(scene.ui.modal_kind=="inventory","E opens real supply inventory")
	scene.ui.close()
	var weapon=scene.sim.item("LIGHT_PISTOL");scene.player.state.weapons.append(weapon)
	var index=scene.player.state.weapons.size()-1
	require(scene.sim.equip_weapon(scene.player.state,index,"right_arm")=="","Equip held pistol")
	scene.player.refresh();scene.ui.pause_menu()
	var enemy=scene.enemies[0]
	enemy.position=Vector3(0,.05,-8);scene.player.position=Vector3(0,.05,-4);scene.player.rotation.y=0
	scene.player.visual.animate(1,0,true,false)
	await frames(4)
	var hp=enemy.state.assembly.sensor.durability
	scene.aim_position=enemy.hitboxes.sensor.global_position
	scene.attack_mode="precision"
	scene.perform_attack(scene.player,"right_arm")
	await frames(3)
	require(enemy.state.assembly.sensor.durability<hp,"Muzzle ray physically hits the sensor")
	var wall=scene.world.box(Vector3(0,1.1,-6),Vector3(2,2.2,.3),Color.GRAY,true)
	await frames(4)
	hp=enemy.state.assembly.sensor.durability
	scene.player.state.peak_used=0;scene.player.state.energy=40
	scene.perform_attack(scene.player,"right_arm")
	await frames(3)
	require(enemy.state.assembly.sensor.durability==hp,"Wall blocks physical projectile damage")
	wall.queue_free();await frames(3)
	scene.ui.close();scene.player.position=Vector3(-4,.05,0);await frames(2)
	key(KEY_B,true);await frames(2);key(KEY_B,false)
	require(scene.ui.modal_kind=="workshop","B opens workshop only near service bench")
	scene.ui.close()
	ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/player-journey.json",{"passed":true,"checks":checks})
	print("PLAYER_JOURNEY_OK ",checks)
	scene.queue_free();await process_frame;quit()
