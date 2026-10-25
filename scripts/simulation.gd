class_name ScrapSimulation
extends RefCounted

var catalog: ScrapCatalog
var serial: int = 0
const MODES = {
	"normal":[1.0,1.0,1.0,1.0], "precision":[0.75,1.15,1.05,0.55],
	"power":[1.45,1.35,1.3,1.6], "disable":[0.55,1.2,1.0,0.35],
	"burst":[1.2,1.4,1.45,1.5], "finisher":[2.0,1.6,1.7,2.2], "hack":[0.1,1.3,1.2,0.1]
}
const MODE_NAMES = {"normal":"ОБЫЧНЫЙ", "precision":"ТОЧНЫЙ", "power":"СИЛОВОЙ", "disable":"ОТКЛЮЧЕНИЕ", "burst":"СЕРИЯ", "finisher":"ДОБИВАНИЕ", "hack":"ВЗЛОМ"}
const DISMANTLE = {"careful":[1.0,0.0],"fast":[0.5,0.05],"force":[0.7,0.15],"surgical":[1.5,0.0],"emergency":[0.6,0.1]}

func _init(c: ScrapCatalog):
	catalog = c

func item(id: String) -> Dictionary:
	serial += 1
	var d = catalog.definition(id)
	return {"uid":"p%07d" % serial,"id":id,"durability":float(d.get("durability",50)),"max_durability":float(d.get("max_durability",d.get("durability",50))),"destroyed":false,"magazine":int(d.get("magazine_size",12)),"location":"installed"}

func robot(archetype: String = "E01") -> Dictionary:
	var assembly = {}
	for slot in catalog.enemies[archetype].assembly:
		assembly[slot] = item(catalog.enemies[archetype].assembly[slot])
	if archetype == "E01":
		assembly.cooling = item("COOL0_PASSIVE_RADIATOR")
	var r = {"assembly":assembly,"inventory":[],"weapons":[],"held":{"left_arm":null,"right_arm":null},"ammo":{},"programs":[],"loaded":[],"hotbar":[],"buffs":{},"cooldowns":{},"energy":100.0,"heat":0.0,"time":0.0,"stability_damage":0.0,"disabled":{},"credits":30,"alive":true,"captured_until":0.0,"scan_until":0.0,"clues":[],"archetype":archetype,"shot_index":0}
	for id in catalog.data.ammo:r.ammo[id] = 0
	r.energy = stats(r).energy_cap
	return r

func starter() -> Dictionary:
	var r = robot()
	r.programs = ["BATTERY_SAVER", "BLACKBOX_READER","LOW_LIGHT_VISION"]
	r.hotbar = ["BLACKBOX_READER", "BATTERY_SAVER"]
	r.ammo.SCRAP_ROUND = 36
	r.ammo.SHOCK_CAPACITOR = 12
	return r

func condition(p) -> float:
	if p == null or p.is_empty() or p.get("destroyed",false):return 0.0
	var ratio = float(p.durability) / maxf(float(p.max_durability),1.0)
	if ratio >= .95:return 1.0
	if ratio >= .70:return .95
	if ratio >= .40:return .75
	if ratio >= .15:return .45
	return 0.0

func state_name(p) -> String:
	if p.get("destroyed",false):return "РАЗРУШЕН"
	var ratio = float(p.durability)/maxf(float(p.max_durability),1)
	if ratio >= .95:return "ИДЕАЛ"
	if ratio >= .70:return "РАБОЧИЙ"
	if ratio >= .40:return "ПОВРЕЖДЁН"
	if ratio >= .15:return "НЕСТАБИЛЕН"
	return "СЛОМАН"

func definition(p) -> Dictionary:
	return catalog.definition(str(p.id)) if p != null else {}

func slot_def(r: Dictionary,slot: String) -> Dictionary:
	return definition(r.assembly.get(slot))

func functional(r: Dictionary,slot: String) -> bool:
	return condition(r.assembly.get(slot)) > 0 and float(r.disabled.get(slot,0)) <= float(r.time)

func active(r: Dictionary,id: String) -> bool:
	return id in r.loaded or float(r.buffs.get(id,0)) > float(r.time)

func hardware(r: Dictionary,key: String) -> float:
	var total=0.0
	for slot in ["controller","comm_module"]:
		var part=r.assembly.get(slot)
		if part!=null:total+=float(catalog.hardware_effects(definition(part)).get(key,0))*condition(part)
	return total

func stats(r: Dictionary) -> Dictionary:
	var mass = 0.0
	var idle = 0.0
	var cpu_load = 0.0
	var passive_heat = 0.0
	for p in r.assembly.values():
		var d = definition(p)
		mass += float(d.get("mass",0))
		idle += float(d.get("idle_energy",0))
		cpu_load += float(d.get("cpu_req",0))
		passive_heat += float(d.get("heat",0)) * .12
	for p in r.inventory + r.weapons:
		if p.get("location","inventory")!="storage":mass += float(definition(p).get("mass",0))
	for p in r.held.values():
		if p != null:mass += float(definition(p).get("mass",0))
	for id in r.loaded:
		var pr = catalog.programs.get(id,{})
		cpu_load += float(pr.get("cpu_req",0))
		idle += float(pr.get("idle_energy",0))
	if active(r,"CPU_SCHEDULER"):cpu_load = maxf(0,cpu_load-2)
	var legs = slot_def(r,"legs")
	var torso = slot_def(r,"torso")
	var cpu = slot_def(r,"cpu")
	var core = slot_def(r,"power_core")
	var controller = slot_def(r,"controller")
	var safe = minf(float(legs.get("load_cap",80)),float(torso.get("mount_limit",100)))
	if r.archetype in ["E05","E06"]:safe = 100.0
	safe+=hardware(r,"load_bonus")
	if active(r,"LOAD_BALANCER"):safe += 20
	var ratio = mass/maxf(safe,1)
	var speed = 1.15 if ratio <= .6 else 1.0 if ratio <= .9 else .85 if ratio <= 1.1 else .6 if ratio <= 1.3 else .25
	var cpu_cap = maxf(1,float(cpu.get("cpu_cap",3))*maxf(.1,condition(r.assembly.get("cpu"))))
	var cpur = cpu_load/cpu_cap
	var reaction = 1.0 if cpur <= .7 else .95 if cpur <= .9 else .8 if cpur <= 1.1 else .6 if cpur <= 1.3 else .35
	var core_eff = maxf(.1,condition(r.assembly.get("power_core")))
	var cooling = float(slot_def(r,"cooling").get("cooling_passive",3))*condition(r.assembly.get("cooling"))
	return {"mass":mass,"safe_load":safe,"load_ratio":ratio,"idle":idle,"cpu_load":cpu_load,"cpu_cap":cpu_cap,"program_slots":int(cpu.get("program_slots",cpu.get("slot_count",2))),"speed":speed*reaction,"energy_cap":float(core.get("energy_cap",40))*core_eff,"generation":float(core.get("power_gen",14))*core_eff,"peak":maxf(0,float(core.get("peak_output",18))*core_eff-idle),"cooling":cooling,"passive_heat":passive_heat,"mobility":float(legs.get("mobility",35))+hardware(r,"mobility_bonus"),"cpu_ratio":cpur}

func tick(r: Dictionary,dt: float):
	r.time += dt
	r["peak_used"]=0.0
	if not r.alive:return
	var s = stats(r)
	r.energy = clampf(float(r.energy)+(s.generation-s.idle)*dt,0,s.energy_cap)
	r.heat = clampf(float(r.heat)+(s.passive_heat-s.cooling)*dt,0,140)
	r.stability_damage = maxf(0,float(r.stability_damage)-12*dt)
	if r.heat >= 110:r["thermal_tripped"]=true
	if r.heat < 70:r["thermal_tripped"]=false
	if r.get("thermal_tripped",false):r.disabled["thermal_lock"] = r.time + 1.5
	if r.energy <= 0 and not r.loaded.is_empty():r.loaded.pop_back()
	if not functional(r,"cpu") or not functional(r,"power_core"):r.alive = false

func action_profile(r: Dictionary,hand: String) -> Dictionary:
	var p = r.held.get(hand)
	var arm = r.assembly.get(hand)
	var d = definition(p if p != null else arm).duplicate(true)
	if p != null:
		d.attack_damage = d.get("damage",8)
		d.attack_energy = d.get("energy_cost",3)
		d.attack_heat = d.get("heat",1)
		d.attack_accuracy = d.get("accuracy",65)
	else:
		d.attack_damage = d.get("attack_damage",8)
		d.attack_energy = d.get("attack_energy",5)
		d.attack_heat = d.get("attack_heat",2)
	d["instance"] = p if p != null else arm
	return d

func can_attack(r: Dictionary,hand: String,mode: String) -> String:
	if not functional(r,hand):return "Узел руки отключён"
	if float(r.disabled.get("thermal_lock",0)) > float(r.time):return "Аварийное охлаждение"
	var profile = action_profile(r,hand)
	var factor = MODES[mode]
	var cost = float(profile.get("attack_energy",5))*factor[1]
	if active(r,"ENERGY_ROUTER"):cost *= .88
	if r.energy < cost:return "Недостаточно заряда"
	if stats(r).peak-float(r.get("peak_used",0)) < minf(cost,float(profile.get("peak_energy",cost))):return "Превышена пиковая мощность"
	if r.held.get(hand) != null and profile.get("ammo_type",null) != null and int(profile.instance.magazine) < int(profile.get("ammo_per_shot",1)):return "Магазин пуст — R"
	return ""

func spend_attack(r: Dictionary,hand: String,mode: String):
	var profile = action_profile(r,hand)
	var factor = MODES[mode]
	var cost = float(profile.get("attack_energy",5))*factor[1]
	if active(r,"ENERGY_ROUTER"):cost *= .88
	r.energy -= cost
	r["peak_used"]=float(r.get("peak_used",0))+minf(cost,float(profile.get("peak_energy",cost)))
	var heat = float(profile.get("attack_heat",2))*factor[2]
	if active(r,"HEAT_OPTIMIZER"):heat *= .88
	r.heat = minf(140,r.heat+heat)
	r.shot_index += 1
	if r.held.get(hand) != null and profile.get("ammo_type",null) != null:
		profile.instance.magazine = maxi(0,int(profile.instance.magazine)-int(profile.get("ammo_per_shot",1)))

func damage(attacker: Dictionary,target: Dictionary,zone: String,profile: Dictionary,mode: String="normal",scale: float=1.0) -> Dictionary:
	if not target.assembly.has(zone):return {"damage":0.0,"zone":zone}
	# The exposed centre compartment remains hittable after its outer plate is removed.
	# Repeated centre-mass hits reach the actual power cell, preserving its exact instance.
	if zone=="torso" and float(target.assembly.torso.durability)/maxf(1,float(target.assembly.torso.max_durability))<=.4 and target.assembly.has("power_core"):zone="power_core"
	var internal = zone not in ["left_arm","right_arm","legs","sensor","torso","drone_body","drone_engine","comm_module"]
	if internal and target.assembly.has("torso"):
		var torso = target.assembly.torso
		if float(torso.durability)/maxf(float(torso.max_durability),1) > .4 and float(profile.get("armor_pen",0)) < float(slot_def(target,"torso").get("internal_protection",20)) and mode != "hack":zone="torso"
	var p = target.assembly[zone]
	if p.destroyed:return {"damage":0.0,"zone":zone}
	var d = definition(p)
	var dtype = str(profile.get("damage_type","kinetic"))
	var typekey = str(d.get("type",zone))
	if typekey == "memory":typekey = "cpu"
	if typekey.begins_with("drone"):typekey = "drone"
	var matrix = catalog.data.damage_matrix.get(dtype,{})
	var armor = maxf(0,float(d.get("armor",0))-float(profile.get("armor_pen",0)))
	if active(attacker,"ARMOR_PATTERN_ANALYSIS"):armor = maxf(0,armor-8)
	var amount = maxf(1,roundf(float(profile.get("attack_damage",8))*MODES[mode][0]*float(matrix.get(typekey,1))*scale-armor))
	if active(attacker,"DASH_STRIKE"):amount *= 1.25
	if active(attacker,"PRECISION_STRIKE"):amount *= 1.15
	if active(attacker,"HEAT_MAP") and dtype=="thermal":amount *= 1.15
	if active(attacker,"SIGNAL_TRACE") and zone=="comm_module":amount *= 1.15
	var before = float(p.durability)
	p.durability = maxf(0,before-amount)
	var bonus = {"kinetic":5,"cutting":8,"crushing":18,"piercing":12,"emp":4,"thermal":22,"impulse":6,"energy":25,"software":0}.get(dtype,0)
	var destruction = (float(profile.get("crit_destroy_risk",10))+maxf(0,amount-before)+bonus+maxf(0,18-float(d.get("armor",0))*2)-(42 if mode=="precision" else 24 if mode=="disable" else 0))*MODES[mode][3]
	if active(attacker,"LOW_DAMAGE_DISABLE"):destruction *= .45
	if p.durability <= 0 and destruction >= 100:p.destroyed=true
	if mode == "disable" or dtype == "emp":target.disabled[zone] = target.time + (3.5 if mode=="disable" else 1.5)
	if dtype in ["thermal","energy"]:target.heat = minf(140,target.heat+amount*.35)
	target.stability_damage += float(profile.get("stability_damage",5))
	if target.stability_damage >= float(slot_def(target,"legs").get("stability",65))+hardware(target,"stability_bonus"):
		target.disabled["stagger"] = target.time + 1.1
		target.stability_damage = 0
	if not functional(target,"cpu") or not functional(target,"power_core"):target.alive=false
	if target.assembly.has("left_arm") and not functional(target,"left_arm") and not functional(target,"right_arm"):target.alive=false
	if target.archetype=="E05" and not functional(target,"drone_engine"):target.alive=false
	return {"damage":amount,"zone":zone,"destroyed":p.destroyed,"disabled":not functional(target,zone),"destruction":destruction,"defeated":not target.alive}

func extract(r: Dictionary,corpse: Dictionary,zone: String,method: String) -> Dictionary:
	if not corpse.assembly.has(zone):return {"error":"Узел уже снят"}
	var p = corpse.assembly[zone]
	if p.destroyed:return {"error":"Критически разрушенная деталь"}
	if method=="surgical" and not has_tool(r):return {"error":"Нужен ремонтный манипулятор"}
	if method=="careful" and not functional(r,"left_arm") and not functional(r,"right_arm"):return {"error":"Нужен рабочий манипулятор"}
	var penalty = extraction_loss(r,method)
	p.durability = maxf(0,float(p.durability)-ceilf(float(p.max_durability)*penalty))
	p.location = "inventory"
	corpse.assembly.erase(zone)
	r.inventory.append(p)
	return {"item":p}

func extraction_loss(r: Dictionary,method: String) -> float:
	return maxf(0,float(DISMANTLE[method][1])-(.03 if active(r,"LOOT_DIAGNOSTICS") else 0)-hardware(r,"salvage_bonus")/100.0)

func has_tool(r: Dictionary) -> bool:
	for p in r.assembly.values():
		if condition(p)>0 and str(p.id) in ["R12_REPAIR_ARM","M7_SURGICAL_ARM","MICROWELD_R8"]:return true
	return false

func repair(r: Dictionary,p: Dictionary) -> String:
	if p.destroyed:return "Разрушенную деталь восстановить нельзя"
	var cost = int(ceil((float(p.max_durability)-float(p.durability))*float(definition(p).get("repair_difficulty",1))/10))
	if r.credits < cost:return "Недостаточно ремонтного лома: %d" % cost
	r.credits -= cost
	p.durability = p.max_durability
	return ""

func install(r: Dictionary,index: int,slot: String) -> String:
	if index < 0 or index >= r.inventory.size():return "Деталь не найдена"
	var p = r.inventory[index]
	if condition(p) <= 0:return "Сначала отремонтируйте деталь"
	var kind = definition(p).get("type","")
	if kind=="drone_body":return "Корпус дрона не совместим с гуманоидным каркасом"
	if kind != slot and not (slot in ["left_arm","right_arm"] and kind=="arm"):return "Несовместимое крепление"
	var extras = ["controller","memory","comm_module","adapter","drone_engine"]
	if kind in ["sensor","drone_engine"] and str(p.id) in ["SKYEYE_RECON_LENS","COMBAT_OPTIC_C2","HOVER_ENGINE","VECTOR_ENGINE"] and not r.assembly.has("adapter"):return "Нужен универсальный адаптер дрона"
	if kind in extras and not r.assembly.has(slot):
		var occupied = 0
		for key in extras:
			if r.assembly.has(key):occupied+=1
		if occupied >= int(slot_def(r,"torso").get("slot_count",2)):return "Дополнительные слоты корпуса заняты"
	var previous = r.assembly.get(slot)
	r.inventory.remove_at(index)
	if previous != null:previous.location="storage";r.inventory.append(previous)
	r.assembly[slot]=p;p.location="installed"
	if slot in ["left_arm","right_arm"] and not definition(p).get("can_hold_weapon",false) and r.held.get(slot)!=null:
		r.weapons.append(r.held[slot]);r.held[slot]=null
	r.energy = minf(r.energy,stats(r).energy_cap)
	r.alive = true
	return ""

func equip_weapon(r: Dictionary,index: int,hand: String) -> String:
	if not slot_def(r,hand).get("can_hold_weapon",false):return "Эта рука не держит внешнее оружие"
	var w = r.weapons[index]
	var d = definition(w)
	if float(d.get("mass",0)) > float(slot_def(r,hand).get("weapon_weight_limit",12)):return "Превышен лимит массы оружия"
	var previous = r.held[hand]
	r.weapons.remove_at(index)
	if previous != null:r.weapons.append(previous)
	r.held[hand]=w
	return ""

func reload(r: Dictionary,hand: String) -> String:
	if r.held.get(hand)==null:return ""
	var p = r.held[hand]
	var d = definition(p)
	var ammo = d.get("ammo_type",null)
	if ammo==null:return ""
	var missing = int(d.get("magazine_size",12))-int(p.magazine)
	var count = mini(missing,int(r.ammo.get(ammo,0)))
	if count<=0:return "Нет подходящих боеприпасов"
	p.magazine += count;r.ammo[ammo]-=count
	return ""

func load_program(r: Dictionary,id: String) -> String:
	if id in r.loaded:r.loaded.erase(id);return ""
	if r.loaded.size() >= stats(r).program_slots:return "Программные слоты CPU заняты"
	r.loaded.append(id)
	if stats(r).cpu_ratio > 1.3:r.loaded.erase(id);return "CPU не справится с этой программой"
	return ""

func activate_program(r: Dictionary,id: String,target: Dictionary={}) -> String:
	if id not in r.programs:return "Программа не найдена"
	var d = catalog.programs[id]
	if r.time < float(r.cooldowns.get(id,0)):return "Программа восстанавливается"
	if float(d.cpu_req)>stats(r).cpu_cap:return "Недостаточная мощность CPU"
	if r.energy < float(d.active_energy):return "Недостаточно энергии"
	if id in ["SERVO_HIJACK","POWER_SPIKE","FALSE_SIGNAL","DRONE_CAPTURE"] and target.is_empty():return "Нет цели для взлома"
	if id in ["SERVO_HIJACK","POWER_SPIKE","FALSE_SIGNAL","DRONE_CAPTURE"] and not has_hack_port(r):return "Требуется хакерский манипулятор"
	if id=="DRONE_CAPTURE" and target.get("archetype","") not in ["E05","E06"]:return "Цель не является дроном"
	r.energy -= float(d.active_energy);r.heat += float(d.heat)
	r.cooldowns[id]=r.time+maxf(1,float(d.cooldown))
	r.buffs[id]=r.time+maxf(6,float(d.duration))
	match id:
		"EMERGENCY_THROTTLE":r.heat=maxf(0,r.heat-30)
		"SERVO_HIJACK":target.disabled["legs"]=target.time+5;target.disabled["right_arm"]=target.time+5
		"POWER_SPIKE":target.heat=minf(140,target.heat+35)
		"FALSE_SIGNAL":target.disabled["sensor"]=target.time+4
		"DRONE_CAPTURE":
			target.captured_until=target.time+8
		"MEMORY_EXTRACT","BLACKBOX_READER","CORP_SIGNATURE_TRACE":
			if id not in r.clues:r.clues.append(id)
	return ""

func has_hack_port(r: Dictionary) -> bool:
	for p in r.assembly.values():
		if "GHOST" in str(p.id) or "NEEDLE" in str(p.id):return condition(p)>0
	return false
