extends Node

var failures=[]
var checks=[]
func require(value: bool,message: String):
	checks.append(message)
	if not value:failures.append(message);push_error(message)
func frames(n=3):
	for i in range(n):await get_tree().physics_frame

func run(game):
	game.automation=true;game.automation_stage=999;game.ui.close();game.new_game(false);game.story.begin();await frames(15)
	require(game.story.prologue==0 and game.enemies.is_empty(),"Prologue starts without hostile actors")
	for stage in range(6):
		require(game.story.prologue==stage,"Prologue checkpoint "+str(stage))
		for line in range(game.story.scenes[stage].lines.size()-1):game.story.advance()
		if stage>=4:game.player.position.z=-14
		game.story.advance();await frames(4)
	require(game.story.prologue==-1 and game.story.flags.get("leya_rescued",false),"Normal prologue reaches dump with identity flags")
	require(game.enemies.size()==1 and game.world.wrecks.size()==2,"Dump has one hostile and two recoverable donor bodies")
	var donor=game.world.wrecks[0];var uid=donor.state.assembly.power_core.uid
	var before=game.sim.stats(game.player.state).generation
	var result=game.sim.extract(game.player.state,donor.state,"power_core","careful")
	require(not result.has("error") and result.item.uid==uid,"Precombat salvage preserves actual power-core instance")
	var index=game.player.state.inventory.size()-1
	var error=game.sim.install(game.player.state,index,"power_core")
	require(error=="" and game.sim.stats(game.player.state).generation>before,"Dump power core improves player's usable generation")
	require(game.sim.extract(game.player.state,donor.state,"power_core","careful").has("error"),"Donor cannot duplicate its removed part")
	game.player.refresh();game.set_camera_mode(2)
	var path="D:/GameDev/Projects/ScrapReborn3D/test-results/lowgrid-save.json"
	require(game.save_game(path),"Version 2 writes exact donor state")
	game.continue_game(path);await frames()
	require(game.camera_mode==2 and not game.world.wrecks[0].state.assembly.has("power_core"),"Reload restores camera and leaves donor socket empty")
	require(game.player.state.assembly.power_core.uid==uid,"Reload preserves installed salvaged UID")
	game.player.state.weapons.append(game.sim.item("LIGHT_PISTOL"));game.sim.equip_weapon(game.player.state,game.player.state.weapons.size()-1,"right_arm");game.player.refresh()
	for opponent in game.enemies:opponent.set_physics_process(false)
	game.player.state.held.right_arm.magazine=2;game.player.state.ammo.SCRAP_ROUND=12
	game.player.request_reload();game.set_camera_mode(0);game.set_camera_mode(2)
	require(game.player.state.held.right_arm.magazine==2,"Reload does not transfer ammunition before its animation event")
	await frames(ceili(game.player.visual.motion.player.get_animation("Pistol_Reload").length*60)+5)
	var loaded=game.player.state.held.right_arm.magazine;var reserve=game.player.state.ammo.SCRAP_ROUND
	require(loaded>2 and loaded+reserve==14,"Reload event transfers ammunition once and preserves total rounds")
	game.player.visual.motion.play_action("Pistol_Reload");await frames(ceili(game.player.visual.motion.player.get_animation("Pistol_Reload").length*60)+5)
	require(game.player.state.held.right_arm.magazine==loaded and game.player.state.ammo.SCRAP_ROUND==reserve,"Replaying an animation without a transaction cannot duplicate reload")
	game.story.enter_hub();await frames(30)
	require(game.enemies.is_empty() and game.story.location=="hub","Station is safe and has no hostile actor")
	var people=game.world.get_children().filter(func(n):return n is LowGridResident)
	require(people.size()==9,"Station contains four named residents, four background people and cargo bot")
	var humans=people.filter(func(n):return n.target_skeleton!=null)
	require(humans.size()==7,"Seven human characters use skinned game skeletons")
	var balance=game.player.state.credits
	game.story.talk("mira");game.ui.close();game.story.talk("mira");game.ui.close()
	require(game.player.state.credits==balance+35,"Repeated courier dialogue pays advance exactly once")
	var shots=game.player.state.shot_index;game.perform_attack(game.player,"right_arm")
	require(game.player.state.shot_index==shots,"Safe station refuses combat without consuming resources")
	game.story.leave_hub(1);await frames()
	require(game.enemies.size()==3,"Sorting begins with three sequential single opponents")
	var count=game.enemies.size();game.raise_alarm(Vector3.ZERO)
	require(game.enemies.size()==count,"Early drone alarm has no reinforcement")
	game.player.position=Vector3(-6.5,.05,-82);game.interact();game.ui.close()
	require(game.story.flags.get("transport_evidence",false),"Physical terminal provides transport evidence independent of drone memory")
	game.story.enter_hub();await frames(20)
	var personality=game.story.core.uid;var installed=game.player.state.assembly.power_core.uid
	game.replay_prologue();game.story.finish();game.ui.close();game.menu_open=false;await frames()
	require(game.story.core.uid==personality and game.player.state.assembly.power_core.uid==installed and game.story.location=="hub","Prologue replay preserves campaign equipment and personality")
	if DisplayServer.get_name()!="headless":
		game.player.position=Vector3(0,.05,-4);game.yaw=0;game.pitch=-.12;game.set_camera_mode(0);await frames(60)
		RenderingServer.force_draw();game.get_viewport().get_texture().get_image().save_png("D:/GameDev/Projects/ScrapReborn3D/test-results/lowgrid-hub.png")
		game.player.position=Vector3(-5,.05,-8);game.yaw=PI/2;game.set_camera_mode(2);await frames(60)
		RenderingServer.force_draw();game.get_viewport().get_texture().get_image().save_png("D:/GameDev/Projects/ScrapReborn3D/test-results/lowgrid-mechanic.png")
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","exported":not OS.has_feature("editor")}
	ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/lowgrid-regression.json",report);print("LOWGRID_REGRESSION ",report)
	get_tree().quit(0 if failures.is_empty() else 1)
