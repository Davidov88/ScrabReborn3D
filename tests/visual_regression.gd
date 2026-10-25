extends SceneTree

func _initialize():call_deferred("run")

func run():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);scene.ui.close();scene.new_game(true);scene.ui.close()
	for i in range(3):await process_frame
	print("PLAYER_JOINT_KEYS ",scene.player.visual.joints.keys())
	var enemy=scene.enemies[0]
	var before=JSON.stringify(enemy.state)
	var original_mesh=enemy.visual.mounts.right_arm.get_child(0).get_instance_id()
	var p=scene.sim.item("S17_PISTOL_ARM");p.location="storage";scene.player.state.inventory.append(p)
	assert(scene.sim.install(scene.player.state,scene.player.state.inventory.size()-1,"right_arm")=="")
	scene.player.refresh()
	assert(JSON.stringify(enemy.state)==before,"Equipping player must not mutate enemy state")
	assert(enemy.visual.mounts.right_arm.get_child(0).get_instance_id()==original_mesh,"Equipping player must not replace enemy visual nodes")
	assert(scene.player.visual.mounts.right_arm.get_child(0).get_instance_id()!=original_mesh)
	var poses=[]
	for i in range(3):
		scene.player.visual.animate(.15,3,false,false)
		var pose={}
		for name in scene.player.visual.joints:pose[name]=str(scene.player.visual.joints[name].rotation)
		poses.append(pose)
	print("JOINT_POSES ",poses)
	assert(poses[0].right_armUpperArm!=poses[1].right_armUpperArm,"Shoulder articulates in walking cycle")
	assert(poses[0].right_armForearm!=poses[1].right_armForearm,"Elbow articulates independently")
	scene.player.visual.kick("right_arm","melee")
	assert(scene.player.visual.attacks.right_arm>0 and scene.player.visual.attacks.left_arm==0,"Each hand has independent attack animation")
	print("PLAYER_ENEMY_EQUIPMENT_ISOLATION_OK")
	scene.queue_free();await process_frame;quit()
