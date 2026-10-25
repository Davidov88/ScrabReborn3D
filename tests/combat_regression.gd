extends SceneTree

func _initialize():call_deferred("run")

func frames(n: int):
	for i in range(n):await physics_frame

func run():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	scene.ui.close();scene.new_game(false);scene.ui.close()
	var supply=scene.world.interactions.filter(func(i):return i.kind=="supply")[0]
	scene.player.position=Vector3(supply.position[0],.05,supply.position[2])
	scene.interact();scene.ui.close()
	assert(scene.player.state.held.right_arm.id=="LIGHT_PISTOL","First supply equips a useful weapon")
	var enemy=scene.enemies[0]
	for i in range(1,scene.enemies.size()):scene.enemies[i].position=Vector3(5,.05,-95)
	enemy.position=Vector3(0,.05,-7);enemy.patrol_origin=enemy.position;enemy.awareness=3
	scene.player.position=Vector3(0,.05,-3)
	var starting_uid=enemy.state.assembly.power_core.uid
	var shots=0
	while enemy.state.alive and shots<12 and scene.player.state.alive:
		await frames(40)
		scene.player.rotation.y=0
		scene.player.visual.animate(1,0,true,false)
		scene.aim_position=enemy.global_position+Vector3(0,1.22,0)
		scene.perform_attack(scene.player,"right_arm")
		shots+=1
	assert(not enemy.state.alive,"Opening enemy must be defeatable by a magazine of actual centre-mass muzzle rays")
	assert(scene.player.state.alive,"Player survives first one-on-one encounter")
	assert(enemy.state.assembly.power_core.uid==starting_uid,"Combat keeps the actual battery instance")
	assert(enemy.state.assembly.power_core.durability<enemy.state.assembly.power_core.max_durability,"Exposed compartment transfers physical hits to the actual battery")
	var result=scene.sim.extract(scene.player.state,enemy.state,"right_arm","careful")
	assert(not result.has("error"),"Defeated enemy yields an intact reusable arm")
	assert(not enemy.state.assembly.has("right_arm"),"Salvage removes the arm from the corpse")
	print("FIRST_ENCOUNTER_OK shots=",shots," player_energy=",scene.player.state.energy)
	ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/combat-regression.json",{"passed":true,"shots":shots,"player_survived":scene.player.state.alive})
	scene.queue_free();await process_frame;quit()
