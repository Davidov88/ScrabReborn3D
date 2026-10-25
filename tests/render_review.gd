extends SceneTree

func _initialize():
	call_deferred("run")

func wait_frames(n: int):
	for i in range(n):await process_frame

func capture(path: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	await wait_frames(60)
	await capture("D:/GameDev/Projects/ScrapReborn3D/test-results/menu.png")
	scene.ui.close();scene.new_game(true);scene.ui.close()
	for actor in scene.enemies:actor.set_physics_process(false)
	scene.ui.modal_open=true
	await wait_frames(90)
	await capture("D:/GameDev/Projects/ScrapReborn3D/test-results/third-person.png")
	scene.set_camera_mode(1)
	await wait_frames(70)
	await capture("D:/GameDev/Projects/ScrapReborn3D/test-results/top-view.png")
	scene.set_camera_mode(2)
	await wait_frames(70)
	await capture("D:/GameDev/Projects/ScrapReborn3D/test-results/first-person.png")
	scene.ui.modal_open=false;scene.toggle_vision()
	await wait_frames(50)
	await capture("D:/GameDev/Projects/ScrapReborn3D/test-results/enhanced-vision.png")
	for item in scene.player.state.inventory:
		if item.id=="S17_PISTOL_ARM":scene.ui.workshop_candidate=item.uid;break
	scene.ui.modal_open=false;scene.ui.inventory(true)
	await wait_frames(70)
	await capture("D:/GameDev/Projects/ScrapReborn3D/test-results/workshop.png")
	scene.ui.close()
	print("RENDER_REVIEW_COMPLETE")
	quit()
