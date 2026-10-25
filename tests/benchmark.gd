extends SceneTree

func _initialize():call_deferred("run")

func run():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);scene.ui.close();scene.new_game(true);scene.ui.close()
	var samples=[]
	for sector in range(5):
		scene.enter_sector(sector,false);scene.player.position=Vector3(0,.05,-40)
		for i in range(60):await process_frame
		for mode in [0,1,2]:
			scene.set_camera_mode(mode)
			var start=Time.get_ticks_usec();var frames=0
			while Time.get_ticks_usec()-start<3000000:
				await process_frame;frames+=1
				if scene.ui.modal_open:scene.ui.close()
				scene.player.state.alive=true;scene.player.state.energy=170
				for p in scene.player.state.assembly.values():p.durability=p.max_durability;p.destroyed=false
			var seconds=(Time.get_ticks_usec()-start)/1000000.0
			samples.append({"sector":sector,"camera_mode":mode,"fps":frames/seconds,"static_memory":OS.get_static_memory_usage(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var width=root.get_visible_rect().size.x
	ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/benchmark-"+str(int(width))+".json",{"resolution":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"window_pixels":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"headless":DisplayServer.get_name()=="headless","samples":samples})
	print("BENCHMARK_COMPLETE ",samples)
	scene.ui.close();scene.queue_free();await process_frame;quit()
