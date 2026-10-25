class_name LowGridStory
extends RefCounted

var game: Node3D
var location="campaign"
var prologue=-1
var line=0
var flags={}
var conversations={}
var npc_states={}
var core={"uid":"ILYA-K63-IDENTITY","owner":"Илья Арден","integrity":63,"platform":"L.R.-01","transfer_count":0}
var subtitle: PanelContainer
var speaker: Label
var words: Label
var hint: Label
var elapsed=0.0
var scene_time=0.0
var line_time=0.0
var scenes: Array=[]

const SCENES=[
	{"name":"01 / АВАРИЯ","lines":[["Илья","Дождь глушит всё, кроме шин. Я должен был вернуться в лабораторию до смены."],["Система","ВХОДЯЩЕЕ СОЕДИНЕНИЕ / HELIX DOMINION"],["Неизвестный","Арден, остановите передачу. Вы не понимаете, что выпускаете наружу."],["Илья","Я видел список. Там не добровольцы."],["Система","УДАР / ПОТЕРЯ СИГНАЛА"]]},
	{"name":"02 / ЛАБОРАТОРИЯ","lines":[["Техник","Очистка остановилась. Личностный контур удерживает шестьдесят три процента."],["Второй техник","Повторный запуск?"],["Техник","Вейл запретил. Поставь отметку: брак. Утилизация, участок семнадцать."],["Илья","Я слышу их. Почему я не могу пошевелиться? Где мои руки?"],["Система","СЕНСОР: АКТИВЕН. ВНЕШНЕЕ УПРАВЛЕНИЕ: ЗАБЛОКИРОВАНО."],["Техник","Не подключай его к сети. Этот отпечаток уже есть в архиве."]]},
	{"name":"03 / ТРАНСПОРТИРОВКА","lines":[["Охранник","Контейнер К-63. Подтверждение списания есть. Едем без остановок."],["Второй охранник","Почему у брака питание не сняли?"],["Охранник","Не наше дело. Не открывай."],["Лея","Технический контроль. У контейнера утечка. Мне нужен доступ к сенсорному креплению."],["Охранник","У тебя девяносто секунд."],["Лея, тихо","Если ты меня слышишь — удерживай сигнал. Я попробую тебя вытащить."]]},
	{"name":"04 / СПАСЕНИЕ","lines":[["Система","ВНЕШНИЕ ПРИВОДЫ ОТКЛЮЧЕНЫ. ЯДРО ЛИЧНОСТИ СОХРАНЕНО."],["Лея","Не сопротивляйся. Я снимаю сенсорный блок целиком. Память останется с тобой."],["Илья","Ты… знаешь меня?"],["Лея","Знаю, что списывают здесь не только неисправные машины."],["Лея","Моя мастерская рядом. L.R.-01 никогда не запускался с человеческим ядром. Другого корпуса у нас нет."],["Система","ПОДКЛЮЧЕНИЕ К ШИНЕ L.R.-01 / ПРОВЕРКА СОВМЕСТИМОСТИ"]]},
	{"name":"05 / ЗАПУСК L.R.-01","lines":[["Лея Ренн","Меня зовут Лея. Это мой прототип. Он не солдат, но его крепления принимают серийные узлы."],["Лея Ренн","Твоя личность — отдельный модуль. Голову, руки, питание можно менять. Ты от этого не станешь другим."],["Система","ПРИВОДЫ ОНЛАЙН. WASD — движение. V — три камеры. N — усиленное зрение."],["Илья","Илья. Кажется, меня зовут Илья."],["Лея Ренн","Проверь сенсор и руки. Потом иди к освещённой двери. Если услышишь тревогу — не стреляй, беги."],["Система","ПРОВЕРКА: пройдите к двери и нажмите E."]]},
	{"name":"06 / ПОБЕГ","lines":[["Охрана","Несанкционированное включение в ремонтном блоке. Перекрыть грузовой мост."],["Лея Ренн","Держись жёлтых огней. Под мостом — старый двор Scrap Union. Скажешь Стальному, что ты от меня."],["Илья","А ты?"],["Лея Ренн","Я закрою след. Илья, не подключайся к их сети. Ты там уже есть."],["Система","МАРШРУТ: аварийный мост. Доберитесь до конца прохода."],["Лея Ренн","Назад! Крепление не выдержит—"]]}
]

func setup(g):
	game=g;scenes=SCENES.duplicate(true)
	var extensions=JSON.parse_string(FileAccess.get_file_as_string("res://data/prologue_dialogue.json"))
	if extensions is Dictionary:
		for key in extensions:
			var target=scenes[int(key)].lines
			if int(key)==5:
				var warning=target.pop_back();target.append_array(extensions[key].slice(0,4));target.append(warning);target.append_array(extensions[key].slice(4));continue
			var at=maxi(1,target.size()-2)
			for entry in extensions[key]:target.insert(at,entry);at+=1

func data() -> Dictionary:
	return {"location":location,"prologue":prologue,"line":line,"flags":flags,"conversations":conversations,"npc_states":npc_states,"core":core,"elapsed":elapsed,"scene_time":scene_time}

func restore(value: Dictionary):
	location=value.get("location","campaign");prologue=int(value.get("prologue",-1));line=int(value.get("line",0));flags=value.get("flags",{});conversations=value.get("conversations",{});npc_states=value.get("npc_states",{});core=value.get("core",core);elapsed=float(value.get("elapsed",0));scene_time=float(value.get("scene_time",0))

func reset():
	if is_instance_valid(subtitle):subtitle.queue_free();subtitle=null
	location="campaign";prologue=-1;line=0;flags.clear();conversations.clear();npc_states.clear();elapsed=0;scene_time=0
	core={"uid":"ILYA-K63-"+str(Time.get_ticks_usec()),"owner":"Илья Арден","integrity":63,"platform":"L.R.-01","transfer_count":0}

func begin():
	location="prologue";prologue=0;line=0;scene_time=0
	game.enter_sector(0,false);game.set_camera_mode(2);show_line();game.save_game()

func show_line():
	if prologue<0:return
	line_time=0
	if subtitle==null or not is_instance_valid(subtitle):
		subtitle=PanelContainer.new();subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);subtitle.offset_left=110;subtitle.offset_right=-110;subtitle.offset_top=-190;subtitle.offset_bottom=-24;subtitle.add_theme_stylebox_override("panel",game.ui.style(Color(.025,.045,.055,.94)))
		game.ui.root.add_child(subtitle);var box=VBoxContainer.new();subtitle.add_child(box)
		speaker=game.ui.label("",18,game.ui.ACCENT);box.add_child(speaker)
		words=game.ui.label("",23);words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(words)
		hint=game.ui.label("",14,game.ui.MUTED);box.add_child(hint)
	var scene=scenes[prologue];var entry=scene.lines[mini(line,scene.lines.size()-1)]
	speaker.text=scene.name+"   /   "+entry[0];words.text=entry[1]
	hint.text=game.action_key("interact")+" — следующая реплика    P — пропустить пролог    "+game.action_key("camera")+" — камера"

func advance():
	if prologue<0:return
	var last=scenes[prologue].lines.size()-1
	if line<last:line+=1;show_line();game.save_game();return
	if prologue>=4 and game.player.position.z>-12:
		game.notice("Пройдите к освещённому выходу");return
	if prologue==5:finish();return
	prologue+=1;line=0;scene_time=0
	game.enter_sector(0,false);show_line();game.save_game()

func finish():
	flags["leya_rescued"]=true;flags["identity_secured"]=true;flags["prologue_complete"]=true
	location="campaign";prologue=-1;line=0
	if is_instance_valid(subtitle):subtitle.queue_free();subtitle=null
	if not game.replay_restore.is_empty():game.end_replay();return
	game.enter_sector(0,false);game.player.state["personality_uid"]=core.uid
	game.player.state.assembly.legs.durability=floorf(game.player.state.assembly.legs.max_durability*.12)
	game.player.state.assembly.left_arm.durability=floorf(game.player.state.assembly.left_arm.max_durability*.80)
	flags["wake_time"]=elapsed;game.player.refresh()
	game.notice("L.R.-01 / повреждённая платформа. Найдите Шва у ремонтного поста.",7);game.save_game()

func enter_hub():
	game.sector_records[str(game.sector)]=game.snapshot_sector()
	location="hub";game.enter_sector(0,false);flags["station_found"]=true;game.save_game()

func leave_hub(destination: int):
	game.sector_records["hub"]=game.snapshot_sector();location="campaign";game.enter_sector(destination,false);game.save_game()

func tick(dt):
	if game.menu_open or game.ui.modal_open:return
	elapsed+=dt;scene_time+=dt
	line_time+=dt
	if prologue>=0 and (subtitle==null or not is_instance_valid(subtitle)):show_line()
	if prologue>=0:
		game.player.visual.visible=prologue>=4
		if prologue<4:
			var origins=[Vector3(0,1.15,1),Vector3(0,1.55,-1),Vector3(0,1.1,1),Vector3(.6,1.1,-1)]
			var targets=[Vector3(0,1,-16),Vector3(-1,1.35,-5),Vector3(0,1.1,-15),Vector3(1.7,1.45,-4)]
			game.camera.global_position=origins[prologue]+Vector3(sin(scene_time*.08)*.035,0,0)
			game.camera.look_at(targets[prologue]+Vector3(sin(game.yaw)*1.5,game.pitch*.5,0))
		var entry=scenes[prologue].lines[mini(line,scenes[prologue].lines.size()-1)]
		var reading_time=maxf(8.5,float(entry[1].length())/9.0)
		if line_time>reading_time and line<scenes[prologue].lines.size()-1:advance()
	else:game.player.visual.visible=true
	if location=="campaign" and game.sector==0 and flags.get("prologue_complete",false) and not flags.get("movement_restored",false) and elapsed-float(flags.get("wake_time",elapsed))>45:
		restore_movement();game.notice("Шов: обход привода готов. Теперь можешь идти нормально. Рабочие узлы на свалке помогут перед боем.",7)
	if location=="hub":
		game.ui.top_title.text="LOW GRID / НУЛЕВАЯ СТАНЦИЯ"
		game.ui.objective.text="Поговорить со Стальным, Мирой и Яном. Выход к сортировке — северные ворота."
	elif prologue>=0:game.ui.objective.text=scenes[prologue].name+" / "+game.action_key("interact")+" — продолжить, P — пропустить"

func talk(id: String):
	var title={"steel":"СТАЛЬНОЙ / МЕХАНИК","mira":"МИРА / КУРЬЕР","yan":"ЯН / БЫВШИЙ ТЕХНИК MAINTCORE","seam":"ШОВ / СЕРВИСНЫЙ АНДРОИД"}.get(id,"ЖИТЕЛЬ НУЛЕВОЙ СТАНЦИИ")
	game.ui.open_panel(title,"Нулевая станция · локальный разговор","dialogue")
	game.ui.overlay.color=Color(.01,.02,.025,.15)
	game.ui.panel.anchor_top=.57;game.ui.panel.offset_top=0
	game.ui.panel.anchor_right=.86;game.ui.panel.offset_right=0
	var text=""
	match id:
		"steel":text="Лея? Значит, её каркас всё-таки пошёл. Садись у верстака.\n\nМассу держат ноги и торс — всегда смотри на меньшее ограничение. CPU ведёт программы, питание — приводы. Тяжёлая рука без подходящего корпуса сделает тебя медленнее.\n\nСенсор сменный. Твоё личностное ядро я перенесу отдельно. Эту вещь мы не продаём."
		"mira":text="Я возила контейнеры MaintCore. Последний рейс у меня забрали прямо на грузовой линии. В сортировке осталась запись шлюза.\n\nДрон хранит свежий маршрут, но у пульта есть проводной дубль. Если его память сгорит — расследование не остановится."
		"yan":text="Маркировка К-63 — не номер корпуса. Это доля сохранённого отпечатка. Я видел такую подпись в нескольких партиях.\n\nВейл закрывал списки лично. Спроси себя, почему инженер Арден им так нужен — даже после списания."
		"seam":text="Не вставай резко. Я соединил обход сервопривода: теперь можешь идти нормально. Оружие в ящике справа. Сначала возьми его, затем просканируй бытовую машину.\n\nУ неё живы руки. Отключение питания остановит её и сохранит больше деталей. После боя — к Стальному."
		_:text="Здесь чинят тех, кого наверху уже списали. Оружие держи опущенным."
	if flags.get("transport_evidence",false) and id in ["mira","yan"]:text+="\n\nТы принёс запись. В маршруте есть подпись Вейла — и твой допуск инженера. Лея, похоже, знала об этом раньше нас."
	game.ui.content.add_child(game.ui.label(text,22))
	game.ui.content.get_child(-1).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	conversations[id]=int(conversations.get(id,0))+1
	if id=="steel":
		game.ui.button("ОТКРЫТЬ МАСТЕРСКУЮ",func():game.ui.inventory(true))
		game.ui.button("ОБСЛУЖИВАНИЕ / ЗАРЯДИТЬ КОРПУС",charge)
	if id=="mira" and not flags.get("courier_advance",false):
		flags["courier_advance"]=true;game.player.state.credits+=35;game.journal.append("Мира: получить запись перевозки в сортировочном цехе. Аванс: 35 лома.")
	if id=="mira" and flags.get("transport_evidence",false) and not flags.get("courier_paid",false):
		flags["courier_paid"]=true;game.player.state.credits+=60
		if "VULNERABILITY_SCAN" not in game.player.state.programs:game.player.state.programs.append("VULNERABILITY_SCAN")
		game.journal.append("Грузовой маршрут восстановлен. Мира передала 60 лома и диагностическую программу. Следующий след — допуск Ардена в документах Вейла.")
		game.notice("Поручение Миры выполнено: 60 лома и Vulnerability Scan.",6)
	if id=="seam":restore_movement()
	flags["talked_"+id]=true;game.save_game()
	game.ui.button("ЗАВЕРШИТЬ РАЗГОВОР",game.ui.close)

func restore_movement():
	if flags.get("movement_restored",false):return
	flags["movement_restored"]=true
	var legs=game.player.state.assembly.get("legs")
	if legs!=null and not legs.destroyed:legs.durability=maxf(legs.durability,legs.max_durability*.78)
	game.player.refresh()
	game.save_game()

func charge():
	game.player.state.energy=game.sim.stats(game.player.state).energy_cap;game.player.state.heat=0
	game.notice("Заряд восстановлен. Корпус охлаждён.");game.ui.close();game.save_game()

func market():
	game.ui.open_panel("РЫНОК НУЛЕВОЙ СТАНЦИИ","Фиксированные запасы местных техников. Оплата ремонтным ломом.","market")
	for offer in [["R12_REPAIR_ARM",45],["LOAD1_CONTROLLER",35],["FLOW1_LIQUID_LOOP",40]]:
		var id=str(offer[0]);var cost=int(offer[1]);var definition=game.catalog.definition(id)
		game.ui.content.add_child(game.ui.label(game.catalog.label(id),21,game.ui.ACCENT))
		game.ui.content.add_child(game.ui.label(game.catalog.summary(definition),17))
		var sold=flags.get("bought_"+id,false)
		var button=game.ui.button("ПРОДАНО" if sold else "КУПИТЬ / %d ЛОМА" % cost,buy.bind(id,cost))
		button.disabled=sold or int(game.player.state.credits)<cost
	game.ui.button("ПАТРОНЫ / 12 ШТ. ЗА 10 ЛОМА",buy_ammo).disabled=int(game.player.state.credits)<10
	game.ui.content.add_child(game.ui.label("Установленные детали и личностное ядро в продажу не принимаются.",15,game.ui.MUTED))

func buy(id: String,cost: int):
	if flags.get("bought_"+id,false) or game.player.state.credits<cost:return
	game.player.state.credits-=cost;flags["bought_"+id]=true
	var item=game.sim.item(id);item.location="inventory";game.player.state.inventory.append(item)
	game.save_game();market()

func buy_ammo():
	if game.player.state.credits<10:return
	game.player.state.credits-=10;game.player.state.ammo.SCRAP_ROUND+=12;game.save_game();market()
