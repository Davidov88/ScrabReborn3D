extends Node

func run(game,duration_override: float=-1):
	game.ui.close();game.automation=true;game.automation_stage=999;game.new_game(false)
	var duration=3600.0;var arguments=OS.get_cmdline_user_args()
	for i in range(arguments.size()-1):
		if arguments[i]=="--seconds":duration=float(arguments[i+1])
	if duration_override>0:duration=duration_override
	var start=Time.get_ticks_msec();var report_at=15.0;var transition_at=0.0;var phase=0;var frames=0;var previous=start;var samples=[]
	while true:
		await get_tree().process_frame;frames+=1
		var elapsed=(Time.get_ticks_msec()-start)/1000.0
		if elapsed>=transition_at:
			game.ui.close()
			if phase%9<6:
				game.story.location="prologue";game.story.prologue=phase%9;game.story.line=0;game.enter_sector(0,false);game.story.show_line()
			else:
				if is_instance_valid(game.story.subtitle):game.story.subtitle.queue_free();game.story.subtitle=null
				game.story.prologue=-1;game.story.location="hub" if phase%9==7 else "campaign";game.enter_sector(1 if phase%9==8 else 0,false)
			phase+=1;transition_at+=90
		if game.camera_mode!=int(elapsed/15)%3:game.set_camera_mode(int(elapsed/15)%3)
		# Stability stress keeps combat running; this is not a balance/playthrough test.
		game.player.state.alive=true;game.player.state.energy=game.sim.stats(game.player.state).energy_cap;game.player.state.heat=0
		for item in game.player.state.assembly.values():item.durability=item.max_durability;item.destroyed=false
		if game.ui.modal_open:game.ui.close()
		if elapsed>=report_at:
			var now=Time.get_ticks_msec()
			var sample={"elapsed":elapsed,"location":game.story.location,"prologue":game.story.prologue,"fps":frames/((now-previous)/1000.0),"static_memory":OS.get_static_memory_usage(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			samples.append(sample);frames=0;previous=now;report_at+=15
			ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/lowgrid-soak-live.json",{"complete":false,"elapsed":elapsed,"requested":duration,"samples":samples})
			print("LOWGRID_SOAK ",sample)
		if elapsed>=duration:break
	ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/lowgrid-soak-final.json",{"complete":true,"requested":duration,"samples":samples,"headless":DisplayServer.get_name()=="headless","exported":not OS.has_feature("editor")})
	game.ui.close();game.queue_free();await get_tree().process_frame;get_tree().quit()
