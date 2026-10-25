extends SceneTree

var scene
var start_msec=0
var duration=3600.0
var records=[]
var next_sector=120.0
var next_report=15.0
var frames=0
var last_report_msec=0

func _initialize():
	var args=OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i]=="--seconds":duration=float(args[i+1])
	call_deferred("run")

func run():
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	scene.ui.close();scene.new_game(true);scene.ui.close()
	start_msec=Time.get_ticks_msec();last_report_msec=start_msec
	while true:
		await process_frame
		frames+=1
		var elapsed=(Time.get_ticks_msec()-start_msec)/1000.0
		scene.player.state.energy=scene.sim.stats(scene.player.state).energy_cap
		scene.player.state.alive=true
		for part in scene.player.state.assembly.values():part.durability=part.max_durability;part.destroyed=false
		scene.player.state.heat=0
		scene.player.position=Vector3(sin(elapsed*.03)*2,.05,-minf(94,fmod(elapsed*.6,96)))
		scene.player.patrol_origin=scene.player.position
		scene.top_view=int(elapsed/30)%2==1
		if elapsed>=next_sector:
			scene.enter_sector((scene.sector+1)%5,false);next_sector+=120
		if elapsed>=next_report:
			var now=Time.get_ticks_msec()
			var record={"elapsed":elapsed,"fps":frames/((now-last_report_msec)/1000.0),"static_memory":OS.get_static_memory_usage(),"sector":scene.sector,"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			records.append(record);frames=0;last_report_msec=now;next_report+=15
			ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/soak-live.json",{"elapsed":elapsed,"requested":duration,"records":records,"complete":false})
			print("SOAK_PROGRESS ",elapsed," fps=",record.fps," memory=",record.static_memory)
		if elapsed>=duration:break
	ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/soak-final.json",{"elapsed":(Time.get_ticks_msec()-start_msec)/1000.0,"requested":duration,"records":records,"complete":true,"headless":DisplayServer.get_name()=="headless"})
	print("SOAK_COMPLETE")
	scene.ui.close();scene.queue_free();await process_frame
	quit()
