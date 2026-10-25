extends SceneTree

func _initialize():call_deferred("run")

func descendants(n: Node) -> Array:
	var result=[]
	for child in n.get_children():result.append(child);result.append_array(descendants(child))
	return result

func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.ui.close();game.new_game(true);game.ui.close()
	assert(game.enemies.size()==1,"First sector contains exactly one opponent")
	game.ui.selected_slot="right_arm";game.ui.inventory(true)
	await process_frame
	var inventory=game.player.state.inventory
	var expected=""
	for p in inventory:
		if game.sim.definition(p).type=="arm":expected=p.uid;break
	var before=game.player.state.assembly.right_arm.uid
	var buttons=descendants(game.ui.overlay).filter(func(n):return n is Button and n.text=="УСТАНОВИТЬ" and not n.disabled)
	assert(not buttons.is_empty(),"Compatible slot exposes install controls")
	buttons[0].pressed.emit();await process_frame
	assert(game.ui.modal_kind=="workshop","Install does not open a confirmation screen")
	assert(game.player.state.assembly.right_arm.uid==expected,"One click installs into selected anatomical slot")
	assert(game.ui.workshop_undo.size()==1,"Installation can be undone")
	var undo=descendants(game.ui.overlay).filter(func(n):return n is Button and n.text=="ОТМЕНИТЬ ПОСЛЕДНЮЮ ЗАМЕНУ")[0]
	undo.pressed.emit();await process_frame
	assert(game.player.state.assembly.right_arm.uid==before,"Undo restores original exact instance")
	game.ui.close();game.toggle_vision()
	assert(game.sim.active(game.player.state,"LOW_LIGHT_VISION"),"N enables vision program")
	assert(game.sim.stats(game.player.state).cpu_load>=1,"Vision consumes CPU")
	game.toggle_vision();assert(not game.sim.active(game.player.state,"LOW_LIGHT_VISION"),"N disables vision")
	game.enter_sector(1,false);game.ui.close()
	var a=game.enemies[0];var b=game.enemies[2]
	a.position=Vector3(-.38,.05,-8);b.position=Vector3(.38,.05,-8);game.player.position=Vector3(0,.05,-4)
	var minimum=10.0
	for i in range(180):
		await physics_frame
		minimum=minf(minimum,Vector2(a.position.x-b.position.x,a.position.z-b.position.z).length())
	assert(minimum>=.54,"Actor collision and separation prevent body overlap")
	print("WORKSHOP_REGRESSION_OK direct_install undo vision single_enemy separation=",minimum)
	game.queue_free();await process_frame;quit()
