extends Node

var game
var failures=[]
var route=[]
var start=0
func frames(count: int):
	for i in range(count):await get_tree().physics_frame
func press(code: int,down: bool):
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;Input.parse_input_event(event)
func click(down: bool):
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event)
func close_dialogue():
	game.ui.close();game.menu_open=false
func descendants(node) -> Array:
	var result=[]
	for child in node.get_children():result.append(child);result.append_array(descendants(child))
	return result
func walk_to(point: Vector3,limit=35.0,interaction_id: String="") -> bool:
	var since=Time.get_ticks_msec();game.yaw=0
	while Vector2(game.player.position.x-point.x,game.player.position.z-point.z).length()>1.2:
		game.yaw=0
		if interaction_id!="" and game.world.near(game.player.position).get("id","")==interaction_id:break
		var delta=point-game.player.position
		press(KEY_D,delta.x>.35);press(KEY_A,delta.x<-.35);press(KEY_W,delta.z<-.35);press(KEY_S,delta.z>.35)
		await frames(2)
		if (Time.get_ticks_msec()-since)/1000.0>limit:
			failures.append("Movement route blocked at "+str(point))
			ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/lowgrid-playthrough.json",{"passed":false,"failures":failures,"route":route,"position":[game.player.position.x,game.player.position.y,game.player.position.z],"location":game.story.location,"sector":game.sector})
			get_tree().quit(1);return false
	for key in [KEY_W,KEY_S,KEY_A,KEY_D]:press(key,false)
	await frames(2)
	return failures.is_empty()
func use_at(point: Vector3):
	var id=""
	for entry in game.world.interactions:
		if Vector2(entry.position[0]-point.x,entry.position[2]-point.z).length()<.6:id=entry.id;break
	if not await walk_to(point,35,id):return
	press(KEY_E,true);await frames(2);press(KEY_E,false);await frames(2)
func fight(enemy) -> bool:
	if not is_instance_valid(enemy):failures.append("Encounter actor no longer exists");return false
	game.set_camera_mode(2)
	var since=Time.get_ticks_msec()
	while enemy.state.alive and game.player.state.alive and (Time.get_ticks_msec()-since)<65000:
		var target=enemy.position+Vector3(0,0 if enemy.drone else 1.2,0)
		if enemy.state.archetype=="E03" and game.sim.functional(enemy.state,"right_arm"):target=enemy.hitboxes.right_arm.global_position
		var direction=target-(game.player.position+Vector3(0,1.69,0))
		game.yaw=atan2(-direction.x,-direction.z);game.pitch=atan2(direction.y,Vector2(direction.x,direction.z).length())
		var weapon=game.player.state.held.get("right_arm")
		if weapon!=null and weapon.magazine<=0:
			click(false);press(KEY_R,true);await frames(2);press(KEY_R,false);await frames(100)
		else:click(true);await frames(8)
		if game.ui.modal_open:break
	click(false)
	var success=not enemy.state.alive and game.player.state.alive
	if not success:failures.append("Encounter failed: "+enemy.uuid)
	route.append({"encounter":enemy.uuid,"passed":success,"ammo":game.player.state.ammo.duplicate(),"elapsed":(Time.get_ticks_msec()-start)/1000.0})
	return success
func run(g):
	game=g;game.ui.close();game.automation=true;game.automation_stage=999;game.new_game(false);game.story.begin();start=Time.get_ticks_msec()
	while game.story.prologue>=0:
		if "--fast-prologue" in OS.get_cmdline_user_args():game.story.line_time=999
		var stage=game.story.prologue
		var last=game.story.scenes[stage].lines.size()-1
		if game.story.line==last and game.story.line_time>8.5:
			if stage>=4:await walk_to(Vector3(0,.05,-14))
			press(KEY_E,true);await frames(2);press(KEY_E,false)
		await frames(5)
	route.append({"prologue_seconds":(Time.get_ticks_msec()-start)/1000.0})
	await use_at(Vector3(-3,.05,-4));await frames(120);close_dialogue()
	var donor_uid=game.world.wrecks[0].state.assembly.power_core.uid
	await use_at(Vector3(-7,.05,-4))
	for card in game.ui.content.get_children():
		if not card is PanelContainer:continue
		var nodes=descendants(card)
		if nodes.any(func(node):return node is Label and game.catalog.label("GRID1_SERVICE_CORE") in node.text):
			var take=nodes.filter(func(node):return node is Button and node.text.begins_with("СНЯТЬ БЕРЕЖНО"))
			if not take.is_empty():take[0].pressed.emit();break
	while not game.pending_actions.is_empty():await frames(5)
	close_dialogue();await use_at(Vector3(-4,.05,0))
	var slots=descendants(game.ui.overlay).filter(func(node):return node is Button and node.text.begins_with(ScrapCatalog.zone_label("power_core")))
	if not slots.is_empty():slots[0].pressed.emit();await frames(3)
	var install=descendants(game.ui.overlay).filter(func(node):return node is Button and node.text=="УСТАНОВИТЬ" and not node.disabled)
	if not install.is_empty():install[0].pressed.emit();await frames(3)
	if game.player.state.assembly.power_core.uid!=donor_uid:failures.append("Donor power core was not installed through workshop UI")
	close_dialogue()
	await use_at(Vector3(4.9,.05,-6));close_dialogue()
	await walk_to(Vector3(0,.05,-8));await fight(game.enemies[0])
	if failures.is_empty():
		for i in range(3):await use_at(Vector3(-7,.05,-10-i*8));await frames(90);close_dialogue()
		await use_at(Vector3(0,.05,-33));await frames(10)
		if game.story.location!="hub":failures.append("Dump exit did not reach station")
	if failures.is_empty():
		for pos in [Vector3(-7,.05,-8),Vector3(6,.05,-17),Vector3(9,.05,-5)]:await use_at(pos);await frames(180);close_dialogue()
		await use_at(Vector3(-10,.05,-8))
		for slot in ["torso","left_arm","legs","power_core"]:
			var selects=descendants(game.ui.overlay).filter(func(node):return node is Button and node.text.begins_with(ScrapCatalog.zone_label(slot)))
			if not selects.is_empty():selects[0].pressed.emit();await frames(2)
			var repairs=descendants(game.ui.overlay).filter(func(node):return node is Button and node.text.begins_with("ОТРЕМОНТИРОВАТЬ"))
			if not repairs.is_empty():repairs[0].pressed.emit();await frames(2)
		close_dialogue();await use_at(Vector3(-10,.05,-2));close_dialogue()
		await use_at(Vector3(0,.05,-27));await frames(10)
		if game.sector!=1:failures.append("Station gate did not reach sorting")
	if failures.is_empty():
		await use_at(Vector3(4.9,.05,-6));close_dialogue()
		for i in range(3):
			await walk_to(Vector3(0,.05,-8-i*30))
			if not await fight(game.enemies[i]):break
			await use_at(Vector3(-6.5,.05,-22-i*30));await frames(120);close_dialogue()
		if not game.story.flags.get("transport_evidence",false):failures.append("Evidence not reached in ordinary input route")
		if failures.is_empty():
			await walk_to(Vector3(1.1,.05,-84));await walk_to(Vector3(1.1,.05,2));await use_at(Vector3(0,.05,3));await frames(5)
			var courier=game.world.interactions.filter(func(item):return item.kind=="npc" and item.data.id=="mira")
			if not courier.is_empty():await use_at(courier[0].node.position);await frames(120);close_dialogue()
			if not game.story.flags.get("courier_paid",false):failures.append("Transport evidence was not delivered to courier")
	var report={"passed":failures.is_empty(),"failures":failures,"route":route,"seconds":(Time.get_ticks_msec()-start)/1000.0,"accelerated_prologue":"--fast-prologue" in OS.get_cmdline_user_args(),"exported":not OS.has_feature("editor"),"rendered":DisplayServer.get_name()!="headless"}
	ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/lowgrid-playthrough.json",report);print("LOWGRID_PLAYTHROUGH ",report)
	if failures.is_empty() and "--soak-after" in OS.get_cmdline_user_args():
		var soak=load("res://tests/lowgrid_soak.gd").new();game.add_child(soak);soak.call_deferred("run",game,maxf(1,3600-report.seconds));return
	get_tree().quit(0 if failures.is_empty() else 1)
