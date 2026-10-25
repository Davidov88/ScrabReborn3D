extends SceneTree
func _initialize():
	var model=load("res://assets/animations/quaternius-ual1/AnimationLibrary_Godot_Standard.glb").instantiate()
	root.add_child(model)
	visit(model)
	quit()
func visit(n):
	if n is Skeleton3D:
		print("SKELETON ",n.get_path())
		for i in range(n.get_bone_count()):
			if "finger" not in n.get_bone_name(i):print(i," ",n.get_bone_name(i)," ",n.get_bone_global_rest(i))
	if n is AnimationPlayer:
		print("ANIMATIONS ",n.get_path()," root=",n.root_node," ",n.get_animation_list())
		var a=n.get_animation("Walk_Loop")
		for i in range(mini(10,a.get_track_count())):print("TRACK ",a.track_get_path(i))
	for c in n.get_children():visit(c)
