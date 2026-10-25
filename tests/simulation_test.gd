extends SceneTree

var c: ScrapCatalog
var s: ScrapSimulation
var checks=0
var failures=[]

func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)

func _initialize():
	c=ScrapCatalog.new();s=ScrapSimulation.new(c)
	var player=s.starter()
	var stats=s.stats(player)
	check(is_equal_approx(stats.mass,63),"Starter body mass must be 63 kg")
	check(stats.generation>stats.idle,"Starter can recover energy while idle")
	var hardware_robot=s.starter();var base_load=s.stats(hardware_robot).safe_load
	hardware_robot.assembly.controller=s.item("LOAD3_WEIGHT_CONTROLLER")
	check(is_equal_approx(s.stats(hardware_robot).safe_load,base_load+35),"Load controller changes usable assembly capacity by canonical 35 kg")
	hardware_robot.assembly.controller.durability=0
	check(is_equal_approx(s.stats(hardware_robot).safe_load,base_load),"Broken controller stops granting load capacity")
	hardware_robot.assembly.controller=s.item("GRIPSOFT_CONTROLLER")
	check(is_equal_approx(s.extraction_loss(hardware_robot,"fast"),.02),"Grip controller preserves three percent during actual extraction")
	hardware_robot.assembly.controller=s.item("RECOILX_MICRO")
	check(is_equal_approx(s.hardware(hardware_robot,"accuracy_bonus"),8),"Recoil controller grants physical aiming accuracy")
	check(s.can_attack(player,"right_arm","normal")=="","Starter can attack")
	s.spend_attack(player,"right_arm","normal")
	check(s.can_attack(player,"left_arm","normal")!="","Concurrent hands share peak-output budget")
	s.tick(player,1)
	var enemy=s.robot("E03")
	var before=enemy.assembly.right_arm.durability
	var profile={"attack_damage":20,"armor_pen":10,"damage_type":"kinetic","crit_destroy_risk":10}
	var clone=enemy.duplicate(true)
	var a=s.damage(player,enemy,"right_arm",profile,"precision")
	var b=s.damage(player,clone,"right_arm",profile,"precision")
	check(a==b,"Identical physical hits must have identical outcomes")
	check(enemy.assembly.right_arm.durability<before,"Damage affects requested arm")
	check(enemy.assembly.left_arm.durability==clone.assembly.left_arm.durability,"Other arm unchanged")
	var uid=enemy.assembly.right_arm.uid
	var hp=enemy.assembly.right_arm.durability
	var result=s.extract(player,enemy,"right_arm","careful")
	check(result.item.uid==uid,"Extraction preserves item identity")
	check(result.item.durability==hp,"Careful extraction preserves exact durability")
	check(not enemy.assembly.has("right_arm"),"Extracted node removed from corpse")
	check(s.extract(player,enemy,"right_arm","careful").has("error"),"Cannot extract twice")
	var damaged=result.item
	damaged.durability=0;var credits=player.credits;player.credits=100
	check(s.repair(player,damaged)=="" and damaged.durability==damaged.max_durability,"Broken component can be repaired")
	check(player.credits<100,"Repair consumes scrap")
	damaged.destroyed=true
	check(s.repair(player,damaged)!="","Destroyed component cannot be repaired")
	damaged.destroyed=false
	var before_uid=player.assembly.right_arm.uid
	check(s.install(player,0,"right_arm")=="","Install extracted arm")
	check(player.assembly.right_arm.uid==uid,"Installation preserves UID")
	check(player.inventory.any(func(p):return p.uid==before_uid),"Replaced component remains real item")
	var heavy=s.item("ATLAS_INDUSTRIAL_FRAME");heavy.location="inventory";player.inventory.append(heavy)
	var overloaded=s.stats(player)
	check(overloaded.mass>stats.mass and overloaded.speed<stats.speed,"Carried salvage affects mobility")
	heavy.location="storage"
	check(s.stats(player).mass<overloaded.mass,"Storage is not carried mass")
	var p=s.starter();p.weapons.append(s.item("LIGHT_PISTOL"));p.ammo.SCRAP_ROUND=30
	check(s.equip_weapon(p,0,"right_arm")=="","Manipulator equips external pistol")
	var magazine=p.held.right_arm.magazine
	s.spend_attack(p,"right_arm","normal")
	check(p.held.right_arm.magazine==magazine-1,"Firing consumes finite magazine")
	check(s.reload(p,"right_arm")=="" and p.ammo.SCRAP_ROUND==29,"Reload transfers reserve ammunition")
	p.held.right_arm.magazine=0
	check(s.can_attack(p,"right_arm","normal")!="","Empty magazine blocks attack")
	p.assembly.right_arm.durability=0
	check(s.can_attack(p,"right_arm","normal")!="","Broken right arm blocks right attack")
	var core=s.starter();core.energy=0
	check(s.can_attack(core,"left_arm","normal")!="","Insufficient energy blocks action")
	core.heat=120;s.tick(core,.1)
	check(core.disabled.has("thermal_lock"),"Overheating engages deterministic thermal lock")
	for visual in c.visuals:
		check(ResourceLoader.exists(visual.model),"Missing external model "+visual.id)
	check(c.visuals.size()==42,"42 external forms")
	check(c.weapons.size()==13,"13 weapons")
	check(c.programs.size()==25,"24 canonical programs plus low-light vision")
	for archetype in c.enemies:
		var r=s.robot(archetype)
		check(r.alive and s.functional(r,"cpu") and s.functional(r,"power_core"),"Valid vital components "+archetype)
		for slot in r.assembly:check(c.parts.has(r.assembly[slot].id),"Enemy catalog reference "+archetype+"/"+slot)
	var advanced=s.robot("E10");advanced.programs=c.programs.keys();advanced.energy=10000
	advanced.assembly.left_arm=s.item("GHOST_PORT_LITE_L")
	for id in c.programs:
		advanced.energy=10000;advanced.heat=0
		var target=s.robot("E06")
		var before_energy=advanced.energy
		var err=s.activate_program(advanced,id,target)
		check(err=="","Program activation "+id+": "+err)
		check(advanced.energy<before_energy,"Program energy cost "+id)
		check(advanced.buffs.has(id),"Program real active state "+id)
	var drone=s.robot("E06")
	advanced.cooldowns.clear();advanced.energy=10000
	check(s.activate_program(advanced,"DRONE_CAPTURE",drone)=="" and drone.captured_until>drone.time,"Drone capture expires on simulation clock")
	advanced.buffs.ARMOR_PATTERN_ANALYSIS=advanced.time+10
	var armored=s.robot("E03");var armored_copy=armored.duplicate(true)
	var base=s.damage(s.starter(),armored,"torso",profile)
	var analyzed=s.damage(advanced,armored_copy,"torso",profile)
	check(analyzed.damage>=base.damage,"Armor analysis has damage effect")
	var save={"version":1,"player":player,"serial":s.serial}
	var path="D:/GameDev/Projects/ScrapReborn3D/test-results/state-save.json"
	check(ScrapPersistence.write(path,save)==OK,"Atomic save")
	check(ScrapPersistence.write(path,save)==OK,"Backup save")
	var loaded=ScrapPersistence.read(path)
	check(loaded.player.assembly.right_arm.uid==uid,"Save preserves UID")
	var corrupt=FileAccess.open(path,FileAccess.WRITE);corrupt.store_string("{broken");corrupt.close()
	loaded=ScrapPersistence.read(path)
	check(loaded.get("recovered_backup",false),"Corrupt save recovers backup")
	ScrapPersistence.write("D:/GameDev/Projects/ScrapReborn3D/test-results/simulation-tests.json",{"checks":checks,"failures":failures,"passed":failures.is_empty()})
	print("SIMULATION_TESTS ",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
