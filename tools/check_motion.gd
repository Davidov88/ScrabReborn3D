extends SceneTree
func _initialize():call_deferred("run")
func run():
	var motion=LowGridMotion.new();root.add_child(motion)
	for i in range(60):await process_frame
	print("MOTION root=",motion.tree.root_node," playerroot=",motion.player.root_node," state=",motion.playback.get_current_node()," pos=",motion.playback.get_current_play_position())
	print("IDLE direction=",motion.direction("DEF-upper_arm.L","DEF-forearm.L"))
	for ident in ["mira","steel"]:
		var model=load("res://assets/models/residents/"+ident+".glb").instantiate();root.add_child(model)
		var skeleton: Skeleton3D
		for n in motion.walk(model):
			if n is Skeleton3D:skeleton=n
		print("HUMAN ",ident," bones=",skeleton.get_bone_count()," upper=",skeleton.find_bone("upperarm_l")," transform=",skeleton.global_transform)
		motion.retarget(skeleton)
		var upper=skeleton.find_bone("upperarm_l");var lower=skeleton.find_bone("lowerarm_l")
		print("target rest=",skeleton.get_bone_global_rest(upper)," pose=",skeleton.get_bone_global_pose(upper)," child=",skeleton.get_bone_global_pose(lower))
	var clip=motion.player.get_animation("Idle")
	print("TRACK ",clip.track_get_path(0)," rootpath=",motion.rig.name)
	motion.update(.1,3)
	for i in range(60):await process_frame
	print("WALK direction=",motion.direction("DEF-upper_arm.L","DEF-forearm.L")," state=",motion.playback.get_current_node())
	quit()
