class_name ScrapUI
extends CanvasLayer

var game: Node3D
var root: Control
var hud: Control
var overlay: ColorRect
var panel: PanelContainer
var content: VBoxContainer
var modal_open=false
var top_title: Label
var objective: Label
var stats_label: Label
var weapon_label: Label
var context_label: Label
var target_label: Label
var event_label: Label
var reticle: Control
var bar_energy: ProgressBar
var bar_heat: ProgressBar
var program_label: Label
var modal_kind=""
var selected_slot="right_arm"
var settings: Dictionary={}
var rebind_action=""
var inspect_actor: ScrapActor
var body_bars={}
var body_names={}
var workshop_candidate=""
var workshop_undo: Array=[]
var vision_filter: ColorRect

const TEXT=Color("c6cec9")
const MUTED=Color("73858b")
const ACCENT=Color("caa56b")

func setup(g: Node3D):
	game=g
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	vision_filter=ColorRect.new();vision_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);vision_filter.mouse_filter=Control.MOUSE_FILTER_IGNORE;vision_filter.material=ShaderMaterial.new();vision_filter.material.shader=load("res://assets/materials/low_light.gdshader");vision_filter.visible=false;root.add_child(vision_filter)
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(hud)
	var top=HBoxContainer.new();top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);top.offset_left=28;top.offset_top=22;top.offset_right=-28;hud.add_child(top)
	top_title=label("SCRAP / REBORN",26,ACCENT);top.add_child(top_title)
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(spacer)
	stats_label=label("",17,TEXT);top.add_child(stats_label)
	objective=label("",18,TEXT);objective.position=Vector2(30,70);hud.add_child(objective)
	var bottom=VBoxContainer.new();bottom.anchor_top=1;bottom.anchor_bottom=1;bottom.anchor_right=1;bottom.offset_left=28;bottom.offset_top=-166;bottom.offset_right=-350;bottom.offset_bottom=-22;hud.add_child(bottom)
	var instruments=Panel.new();instruments.anchor_top=1;instruments.anchor_bottom=1;instruments.anchor_right=1;instruments.offset_left=16;instruments.offset_top=-180;instruments.offset_right=-330;instruments.offset_bottom=-16;instruments.mouse_filter=Control.MOUSE_FILTER_IGNORE;instruments.add_theme_stylebox_override("panel",style(Color(.025,.04,.05,.92)));hud.add_child(instruments);hud.move_child(instruments,0)
	var body_panel=PanelContainer.new();body_panel.anchor_left=1;body_panel.anchor_right=1;body_panel.anchor_top=1;body_panel.anchor_bottom=1;body_panel.offset_left=-304;body_panel.offset_right=-28;body_panel.offset_top=-244;body_panel.offset_bottom=-24;body_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;body_panel.add_theme_stylebox_override("panel",style(Color(.025,.045,.055,.92)));hud.add_child(body_panel)
	var body_stack=VBoxContainer.new();body_panel.add_child(body_stack);body_stack.add_child(label("СОСТОЯНИЕ УЗЛОВ",13,ACCENT))
	for slot in ["sensor","left_arm","right_arm","legs","power_core"]:
		var row=HBoxContainer.new();body_stack.add_child(row)
		var nameplate=label(ScrapCatalog.zone_label(slot),13,TEXT);nameplate.custom_minimum_size.x=133;row.add_child(nameplate);body_names[slot]=nameplate
		var bar=ProgressBar.new();bar.custom_minimum_size=Vector2(95,18);bar.show_percentage=false;bar.add_theme_stylebox_override("background",style(Color("0c1518"),Color("253137"),0));row.add_child(bar);body_bars[slot]=bar
	weapon_label=label("",19,TEXT);bottom.add_child(weapon_label)
	var bars=HBoxContainer.new();bottom.add_child(bars)
	bar_energy=progress("ПИТАНИЕ",Color("72a6aa"),bars)
	bar_heat=progress("НАГРЕВ",Color("bc714f"),bars)
	target_label=label("",16,ACCENT);bottom.add_child(target_label)
	program_label=label("",14,MUTED);bottom.add_child(program_label)
	bottom.add_child(label("WASD движение   ЛКМ / ПКМ руки   F сканер   TAB анализ   V камера   E действие   I снаряжение   B верстак   ESC меню",14,MUTED))
	context_label=label("",20,ACCENT);context_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER);context_label.offset_top=95;context_label.offset_left=-300;context_label.offset_right=300;context_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.add_child(context_label)
	event_label=label("",17,TEXT);event_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);event_label.offset_left=-440;event_label.offset_right=440;event_label.offset_top=110;event_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;event_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hud.add_child(event_label)
	reticle=Control.new();reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER);reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(reticle)
	for rect in [Rect2(-10,-1,5,2),Rect2(5,-1,5,2),Rect2(-1,-10,2,5),Rect2(-1,5,2,5)]:
		var line=ColorRect.new();line.position=rect.position;line.size=rect.size;line.color=ACCENT;line.mouse_filter=Control.MOUSE_FILTER_IGNORE;reticle.add_child(line)
	settings={"sensitivity":.0028,"shake":true,"volume":.65,"music":.25,"ambience":.35,"ui_volume":.5,"quality":1,"ui_scale":1.0}

func label(text: String,size: int=18,color: Color=TEXT) -> Label:
	var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);return l

func style(bg: Color,border: Color=Color("34464c"),width: int=1) -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border;s.set_border_width_all(width);s.set_content_margin_all(12);s.corner_radius_top_left=2;s.corner_radius_bottom_right=2;return s

func button(text: String,callback: Callable,parent: Node=null) -> Button:
	var b=Button.new();b.text=text;b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.custom_minimum_size.y=42;b.add_theme_font_size_override("font_size",16)
	b.add_theme_stylebox_override("normal",style(Color("172329")));b.add_theme_stylebox_override("hover",style(Color("24343a"),ACCENT));b.add_theme_stylebox_override("pressed",style(Color("354449"),ACCENT))
	b.add_theme_color_override("font_color",TEXT);b.pressed.connect(func():game.play_sound("click",null);callback.call())
	(parent if parent!=null else content).add_child(b);return b

func progress(title: String,color: Color,parent: Node) -> ProgressBar:
	var box=VBoxContainer.new();box.custom_minimum_size.x=270;parent.add_child(box);box.add_child(label(title,12,MUTED))
	var p=ProgressBar.new();p.custom_minimum_size=Vector2(270,12);p.show_percentage=false;p.add_theme_stylebox_override("background",style(Color("0b151a"),Color("24363d")));p.add_theme_stylebox_override("fill",style(color,color,0));box.add_child(p);return p

func update_hud():
	if game.player==null:return
	var r=game.player.state
	var s=game.sim.stats(r)
	vision_filter.visible=game.sim.active(r,"LOW_LIGHT_VISION") and game.sim.functional(r,"sensor") and not modal_open and not game.menu_open
	for slot in body_bars:
		var part=r.assembly.get(slot,{})
		var ratio=float(part.get("durability",0))/maxf(1,float(part.get("max_durability",1)))
		body_bars[slot].value=ratio*100
		var color=Color("8daf9c") if ratio>.7 else Color("c59f60") if ratio>=.15 else Color("d06a54")
		body_bars[slot].add_theme_stylebox_override("fill",style(color,color,0))
		body_names[slot].modulate=color
	top_title.text="SCRAP / REBORN    %02d" % (game.sector+1)
	stats_label.text="МАССА %.0f / %.0f кг     CPU %.0f / %.0f     ЛОМ %d     %s" % [s.mass,s.safe_load,s.cpu_load,s.cpu_cap,int(r.credits),["ТРЕТЬЕ ЛИЦО","ВИД СВЕРХУ","ПЕРВОЕ ЛИЦО"][game.camera_mode]]
	var sec=ScrapCampaign.SECTORS[game.sector]
	var done=game.completed_objectives()
	objective.text=sec.title+"\n"+(sec.objectives[mini(done,2)] if done<3 else "Контуры восстановлены. Найдите выход.")
	var parts=[]
	for hand in ["left_arm","right_arm"]:
		var d=game.sim.action_profile(r,hand)
		var ammo=""
		if r.held.get(hand)!=null and d.get("ammo_type",null)!=null:ammo=" [%d / %d]" % [r.held[hand].magazine,int(r.ammo.get(d.ammo_type,0))]
		var action_name=str(d.get("name","OFFLINE"))
		if r.held.get(hand)==null and d.get("attack_delivery","melee")=="melee":action_name="УДАР МАНИПУЛЯТОРОМ / %.0f урона" % float(d.get("attack_damage",8))
		parts.append(("ПКМ: " if hand=="left_arm" else "ЛКМ: ")+action_name+ammo)
	weapon_label.text="   /   ".join(parts)+"     |     "+ScrapSimulation.MODE_NAMES[game.attack_mode]
	bar_energy.max_value=s.energy_cap;bar_energy.value=r.energy;bar_heat.max_value=110;bar_heat.value=r.heat
	var near=game.world.near(game.player.global_position) if game.world!=null else {}
	context_label.text="[E] "+near.title if not near.is_empty() else ""
	if near.is_empty():
		for enemy in game.enemies:
			if is_instance_valid(enemy) and not enemy.state.alive and enemy.position.distance_to(game.player.position)<2.8:context_label.text="[E] ДЕМОНТИРОВАТЬ / "+enemy.enemy_name;break
	for pending in game.pending_actions:
		if pending.actor==game.player:
			context_label.text=("ДЕМОНТАЖ" if pending.kind=="salvage" else "ПОДКЛЮЧЕНИЕ")+"  /  %.1f c" % pending.remaining
	var programs=[]
	for i in range(r.hotbar.size()):
		var id=r.hotbar[i];var cooldown=maxf(0,float(r.cooldowns.get(id,0))-float(r.time));programs.append("%d  %s%s" % [i+1,game.catalog.program_label(id)," [%.0f c]" % cooldown if cooldown>0 else ""])
	program_label.text="   /   ".join(programs)+("     N  УСИЛЕННОЕ ЗРЕНИЕ [ВКЛ]" if vision_filter.visible else "     N  Усиленное зрение")
	var target=game.target_actor
	if target!=null and is_instance_valid(target):
		var p=target.state.assembly.get(game.target_zone,{})
		target_label.text=target.enemy_name+"  /  "+ScrapCatalog.zone_label(game.target_zone)+( "  %.0f / %.0f  %s" % [p.durability,p.max_durability,game.sim.state_name(p)] if not p.is_empty() else "")
	else:target_label.text="УЗЛЫ: сенсор / руки / корпус / шасси     Нажмите F для диагностики"
	reticle.visible=not game.top_view and not modal_open and not game.menu_open
	hud.visible=not game.menu_open

func close(preserve_workshop: bool=false,keep_mouse_visible: bool=false):
	if overlay!=null:overlay.queue_free();overlay=null
	if not preserve_workshop:workshop_undo.clear()
	modal_open=false;modal_kind="";inspect_actor=null
	if not keep_mouse_visible:game.update_mouse()

func open_panel(title: String,subtitle: String="",kind: String=""):
	close(kind=="workshop",true);modal_open=true;modal_kind=kind
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	overlay=ColorRect.new();overlay.color=Color(0.015,.025,.03,.88);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(overlay)
	panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.offset_left=95;panel.offset_right=-95;panel.offset_top=48;panel.offset_bottom=-48;panel.add_theme_stylebox_override("panel",style(Color("101c22"),Color("52636a")));overlay.add_child(panel)
	var outer=VBoxContainer.new();outer.add_theme_constant_override("separation",12);panel.add_child(outer)
	var heading=HBoxContainer.new();outer.add_child(heading);heading.add_child(label(title,28,ACCENT));var space=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(space)
	if kind!="menu":button("ЗАКРЫТЬ / ESC",close,heading)
	if subtitle!="":outer.add_child(label(subtitle,15,MUTED))
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",8);scroll.add_child(content)

func menu():
	game.menu_open=true
	open_panel("SCRAP REBORN","ГЛАВА 01  /  АППАРАТНОЕ ПОДТВЕРЖДЕНИЕ", "menu")
	var columns=HBoxContainer.new();columns.add_theme_constant_override("separation",48);content.add_child(columns)
	var navigation=VBoxContainer.new();navigation.custom_minimum_size.x=460;navigation.size_flags_horizontal=Control.SIZE_EXPAND_FILL;navigation.add_theme_constant_override("separation",12);columns.add_child(navigation)
	navigation.add_child(label("СОЗНАНИЕ\nВ МАШИНЕ",48,TEXT))
	var intro=label("Участок утилизации 17.\nПробуждение после списания.\nНайдите причину своего уничтожения.",20,MUTED);navigation.add_child(intro)
	button("01    НАЧАТЬ ГЛАВУ",func():close();game.new_game(false),navigation)
	button("02    ВОССТАНОВИТЬ СЕАНС",func():close();game.continue_game(),navigation)
	button("03    ИСПЫТАТЕЛЬНЫЙ ПОЛИГОН",func():close();game.new_game(true),navigation)
	button("04    КОНФИГУРАЦИЯ",settings_panel,navigation)
	button("05    АРХИВ / УПРАВЛЕНИЕ",journal,navigation)
	button("06    АВТОРЫ / ИСТОЧНИКИ",credits,navigation)
	button("ВЫХОД",func():game.get_tree().quit(),navigation)
	var showcase=VBoxContainer.new();showcase.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(showcase)
	showcase.add_child(label("B-01 / ГРАЖДАНСКИЙ КАРКАС",18,ACCENT))
	if game.player!=null:add_assembly_preview(game.player.state,showcase,480,false)

func pause_menu():
	open_panel("СИСТЕМА ПРИОСТАНОВЛЕНА","Локальное управление корпусом", "pause")
	button("ВЕРНУТЬСЯ",close)
	button("СОХРАНИТЬ",func():game.save_game();game.notice("Сохранение записано"))
	button("ЗАГРУЗИТЬ КОНТРОЛЬНУЮ ТОЧКУ",func():close();game.continue_game())
	button("НАСТРОЙКИ",settings_panel)
	button("ЖУРНАЛ",journal)
	button("ГЛАВНОЕ МЕНЮ",menu)

func message(title: String,text: String,callback: Callable=Callable()):
	open_panel(title,"", "message")
	var l=label(text,22,TEXT);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.y=170;content.add_child(l)
	button("ПРОДОЛЖИТЬ",finish_message.bind(callback))

func finish_message(callback: Callable):
	close()
	if callback.is_valid():callback.call()

func journal():
	open_panel("АРХИВ СОЗНАНИЯ","Управление и подтверждённые записи", "journal")
	content.add_child(label("WASD — движение. Shift — бег. Space — рывок. V — камера.\nЛКМ / ПКМ — отдельные руки. Средняя кнопка — прицел. Q — блок щитом.\nF — сканер. Tab — замедление до 15% и выбор узла мышью. C — режим атаки.\nE — действие. R — перезарядка. I — инвентарь. B — мастерская возле верстака.\n1–4 — назначенные программы. F5 — сохранить. F9 — загрузить.\nКолесо мыши — дистанция верхней камеры.",18,TEXT))
	if game.player!=null:
		for entry in game.journal:content.add_child(label(entry,18,ACCENT))
		for clue in game.player.state.clues:content.add_child(label("Извлечённые данные: "+game.catalog.program_label(clue),18,ACCENT))
	button("НАЗАД",menu if game.menu_open else close)

func inventory(bench: bool=false,tab: String="parts"):
	if game.player==null:return
	if bench and tab=="parts":
		ScrapWorkshop.new().build(self);return
	open_panel("МАСТЕРСКАЯ / СБОРКА" if bench else "СНАРЯЖЕНИЕ", "Ремонт и замена узлов доступны на сервисной станции" if bench else "Переносимая масса учитывается в нагрузке", "workshop" if bench else "inventory")
	var tabs=HBoxContainer.new();content.add_child(tabs)
	for category in ["parts","weapons","programs"]:
		var cat=category
		button({"parts":"УЗЛЫ","weapons":"ОРУЖИЕ","programs":"ПРОГРАММЫ"}[cat],func():inventory(bench,cat),tabs)
	button("ПРАВАЯ / ЛЕВАЯ: "+ScrapCatalog.zone_label(selected_slot),func():selected_slot="left_arm" if selected_slot=="right_arm" else "right_arm";inventory(bench,tab),tabs)
	var r=game.player.state
	var stats=game.sim.stats(r)
	content.add_child(label("Нагрузка %.1f / %.1f кг   Генерация %.1f   Постоянное потребление %.1f   Пик %.1f   CPU %.0f / %.0f" % [stats.mass,stats.safe_load,stats.generation,stats.idle,stats.peak,stats.cpu_load,stats.cpu_cap],17,ACCENT))
	if tab=="parts":
		var layout=HBoxContainer.new();layout.add_theme_constant_override("separation",20);content.add_child(layout)
		if bench:
			var display=VBoxContainer.new();display.custom_minimum_size.x=350;display.size_flags_horizontal=Control.SIZE_EXPAND_FILL;layout.add_child(display);add_assembly_preview(r,display,350)
		var installed=VBoxContainer.new();installed.size_flags_horizontal=Control.SIZE_EXPAND_FILL;layout.add_child(installed)
		installed.add_child(label("ТЕКУЩАЯ КОНФИГУРАЦИЯ",16,ACCENT))
		for slot in r.assembly:
			var p=r.assembly[slot];var line=HBoxContainer.new();installed.add_child(line)
			var l=label(ScrapCatalog.zone_label(slot)+"\n"+game.catalog.label(p.id)+"   %.0f / %.0f" % [p.durability,p.max_durability],14,TEXT);l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(l)
			if bench:
				var part=p
				button("РЕМОНТ",func():game.notice(game.sim.repair(r,part));game.player.refresh();inventory(true),line)
		content.add_child(label("СКЛАД КОМПОНЕНТОВ" if bench else "ПЕРЕНОСИМЫЕ КОМПОНЕНТЫ",16,ACCENT))
		var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);content.add_child(grid)
		for i in range(r.inventory.size()):
			var index=i;var p=r.inventory[i];var d=game.sim.definition(p)
			if not bench and p.get("location","")=="storage":continue
			var card=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",style(Color("172229")));grid.add_child(card)
			var stack=VBoxContainer.new();card.add_child(stack)
			stack.add_child(label(game.catalog.label(p.id),17,TEXT))
			stack.add_child(label("%s  •  %.0f / %.0f  •  %.1f кг" % [game.sim.state_name(p),p.durability,p.max_durability,float(d.get("mass",0))],13,MUTED))
			var line=HBoxContainer.new();stack.add_child(line)
			if bench:
				button("УСТАНОВИТЬ",func():show_install_preview(index),line)
				var part=p
				button("РЕМОНТ",func():game.notice(game.sim.repair(r,part));inventory(true),line)
				button("ВЗЯТЬ" if p.get("location","")=="storage" else "НА СКЛАД",func():part.location="inventory" if part.get("location","")=="storage" else "storage";inventory(true),line)
			button("В ЛОМ",func():r.credits+=maxi(1,int(d.get("mass",1)));r.inventory.remove_at(index);inventory(bench),line)
	elif tab=="weapons":
		for hand in ["left_arm","right_arm"]:
			var h=hand
			if r.held[h]!=null:button("СНЯТЬ "+ScrapCatalog.zone_label(h)+": "+game.catalog.label(r.held[h].id),func():r.weapons.append(r.held[h]);r.held[h]=null;game.player.refresh();inventory(bench,"weapons"))
		for i in range(r.weapons.size()):
			var index=i
			if not bench and r.weapons[i].get("location","")=="storage":continue
			var d=game.sim.definition(r.weapons[i])
			content.add_child(label(game.catalog.label(r.weapons[i].id)+"   УРОН %.0f • ПРОБИТИЕ %.0f • ЭНЕРГИЯ %.0f • %.0f КГ\n" % [float(d.get("damage",0)),float(d.get("armor_pen",0)),float(d.get("energy_cost",0)),float(d.get("mass",0))]+("Боезапас: "+str(d.ammo_type)+". R — перезарядка." if d.get("ammo_type")!=null else "Ближний бой. Расходует энергию тела."),16))
			button("УСТАНОВИТЬ В "+ScrapCatalog.zone_label(selected_slot),func():game.notice(game.sim.equip_weapon(r,index,selected_slot));game.player.refresh();inventory(bench,"weapons"))
		content.add_child(label("Боеприпасы: "+str(r.ammo),16,MUTED))
	else:
		content.add_child(label("Активных слотов: %d / %d. Загрузите пассивные системы или назначьте активные программы на 1–4." % [r.loaded.size(),stats.program_slots],16,MUTED))
		for id in r.programs:
			var pid=id;var d=game.catalog.programs[id];var line=HBoxContainer.new();content.add_child(line)
			var l=label(game.catalog.program_label(id)+"   CPU %d  ЭНЕРГИЯ %d\n" % [int(d.cpu_req),int(d.active_energy)]+game.catalog.program_summary(id),16);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(l)
			button("ВЫКЛ" if pid in r.loaded else "ЗАГРУЗИТЬ",func():game.notice(game.sim.load_program(r,pid));inventory(bench,"programs"),line)
			button("НА 1–4",toggle_hotbar.bind(pid,bench),line)
		content.add_child(label("Назначено: "+str(r.hotbar),16,ACCENT))

func toggle_hotbar(pid: String,bench: bool):
	var r=game.player.state
	if pid in r.hotbar:r.hotbar.erase(pid)
	else:
		if r.hotbar.size()>=4:r.hotbar.pop_front()
		r.hotbar.append(pid)
	inventory(bench,"programs")

func add_assembly_preview(r: Dictionary,parent: Node=null,height: int=320,inspect: bool=true):
	var host=parent if parent!=null else content
	var container=SubViewportContainer.new();container.custom_minimum_size=Vector2(340,height);container.stretch=true;container.size_flags_horizontal=Control.SIZE_EXPAND_FILL;host.add_child(container)
	var viewport=SubViewport.new();viewport.size=Vector2i(440,height);viewport.own_world_3d=true;container.add_child(viewport)
	var scene=Node3D.new();viewport.add_child(scene)
	var model=ScrapRobotVisual.new();scene.add_child(model);model.setup(game.catalog,game.sim,r);model.rotation.y=PI+.4
	container.set_meta("preview_model",model)
	if inspect:button("ОБОЛОЧКА / ВНУТРЕННИЕ УЗЛЫ",func():model.set_meta("inspection",not model.get_meta("inspection",false));model.inspect_internals(model.get_meta("inspection",false)),host)
	var camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,1.15,3.5);camera.look_at(Vector3(0,1,0));camera.current=true;camera.fov=36
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-30,0);light.light_energy=2;scene.add_child(light)
	var environment=WorldEnvironment.new();var settings3d=Environment.new();settings3d.background_mode=Environment.BG_COLOR;settings3d.background_color=Color("142129");settings3d.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings3d.ambient_light_color=Color("b5c5c8");settings3d.ambient_light_energy=.7;environment.environment=settings3d;scene.add_child(environment)
	container.gui_input.connect(func(event):
		if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:model.rotation.y+=event.relative.x*.012
	)
	host.add_child(label("Потяните модель мышью для осмотра сборки",13,MUTED))
	return container

func add_part_preview(d: Dictionary,parent: Node):
	var path="res://assets/models/devices/internal_"+str(d.get("type",""))+".glb"
	if not ResourceLoader.exists(path):return
	var container=SubViewportContainer.new();container.custom_minimum_size=Vector2(350,150);container.stretch=true;container.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(container)
	var viewport=SubViewport.new();viewport.size=Vector2i(400,150);viewport.own_world_3d=true;container.add_child(viewport)
	var stage=Node3D.new();viewport.add_child(stage)
	var model=load(path).instantiate();stage.add_child(model);model.rotation=Vector3(.25,.3,0)
	var cam=Camera3D.new();stage.add_child(cam);cam.position=Vector3(0,.30,.65);cam.look_at(Vector3.ZERO);cam.fov=35;cam.current=true
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=2;stage.add_child(light)
	var environment=WorldEnvironment.new();var settings3d=Environment.new();settings3d.background_mode=Environment.BG_COLOR;settings3d.background_color=Color("142129");settings3d.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings3d.ambient_light_energy=.4;environment.environment=settings3d;stage.add_child(environment)

func show_install_preview(index: int):
	var r=game.player.state
	var p=r.inventory[index]
	var d=game.sim.definition(p)
	var slot=selected_slot if d.type=="arm" else str(d.type)
	var before=game.sim.stats(r)
	var copy=r.duplicate(true)
	var error=game.sim.install(copy,index,slot)
	var after=game.sim.stats(copy)
	open_panel("СРАВНЕНИЕ УСТАНОВКИ",game.catalog.label(p.id),"preview")
	add_assembly_preview(copy)
	content.add_child(label("Крепление: "+ScrapCatalog.zone_label(slot)+"\nМасса %.1f → %.1f кг\nЛимит %.1f → %.1f кг\nПотребление %.1f → %.1f\nПиковая мощность %.1f → %.1f\nCPU %.0f / %.0f → %.0f / %.0f" % [before.mass,after.mass,before.safe_load,after.safe_load,before.idle,after.idle,before.peak,after.peak,before.cpu_load,before.cpu_cap,after.cpu_load,after.cpu_cap],22,TEXT))
	if error!="":content.add_child(label(error,20,Color("db8869")))
	else:button("ПОДТВЕРДИТЬ УСТАНОВКУ",func():game.notice(game.sim.install(r,index,slot));game.player.refresh();inventory(true))
	button("НАЗАД",func():inventory(true))

func scan(actor: ScrapActor):
	if actor==null:return
	open_panel("ДИАГНОСТИКА / "+actor.enemy_name,"Выбор узла задаёт цель прицеливания. Геометрия продолжает блокировать атаки.","scan")
	inspect_actor=actor
	for zone in actor.state.assembly:
		var z=zone;var p=actor.state.assembly[z]
		if z in ["cpu","power_core","cooling","memory","controller"] and not game.sim.active(game.player.state,"VULNERABILITY_SCAN"):
			var torso=actor.state.assembly.get("torso",{})
			if not torso.is_empty() and float(torso.durability)/float(torso.max_durability)>.4:continue
		button(ScrapCatalog.zone_label(z)+"   "+game.catalog.label(p.id)+"   %.0f / %.0f   %s" % [p.durability,p.max_durability,game.sim.state_name(p)],func():game.target_actor=actor;game.target_zone=z;game.aim_lock=true;close())
	if game.sim.active(game.player.state,"HEAT_MAP"):content.add_child(label("ТЕПЛОВАЯ КАРТА: %.0f / 110" % actor.state.heat,18,ACCENT))
	if game.sim.active(game.player.state,"SIGNAL_TRACE"):content.add_child(label("СЕТЬ: "+("КАНАЛ ТРЕВОГИ" if actor.state.archetype=="E05" else "ЛОКАЛЬНОЕ УПРАВЛЕНИЕ"),18,ACCENT))

func salvage(actor: ScrapActor):
	open_panel("ДЕМОНТАЖ / "+actor.enemy_name,"Сохраняются реальные экземпляры. Указанная потеря прочности применяется без случайного броска.","salvage")
	inspect_actor=actor
	for zone in actor.state.assembly:
		var z=zone;var p=actor.state.assembly[z]
		content.add_child(label(ScrapCatalog.zone_label(z)+"  /  "+game.catalog.label(p.id)+"  %.0f / %.0f  %s" % [p.durability,p.max_durability,game.sim.state_name(p)],18,ACCENT))
		if p.destroyed:continue
		var row=HBoxContainer.new();content.add_child(row)
		for method in ScrapSimulation.DISMANTLE:
			var m=method;var values=ScrapSimulation.DISMANTLE[m]
			var loss=ceilf(p.max_durability*game.sim.extraction_loss(game.player.state,m));var seconds=3.0*values[0]*float(game.sim.definition(p).get("dismantle_difficulty",1))
			button({"careful":"Аккуратный","fast":"Быстрый","force":"Силовой","surgical":"Хирургический","emergency":"Аварийный"}[m]+"\n%.1f c  −%.0f" % [seconds,loss],func():game.begin_salvage(actor,z,m,seconds),row)

func settings_panel():
	open_panel("НАСТРОЙКИ","Настройки сохраняются локально на D", "settings")
	for property in ["volume","music","ambience","ui_volume","sensitivity","ui_scale"]:
		var prop=property
		content.add_child(label({"volume":"ЭФФЕКТЫ","music":"МУЗЫКА","ambience":"ОКРУЖЕНИЕ","ui_volume":"ИНТЕРФЕЙС","sensitivity":"ЧУВСТВИТЕЛЬНОСТЬ МЫШИ","ui_scale":"МАСШТАБ ИНТЕРФЕЙСА"}[prop],16,MUTED))
		var slider=HSlider.new();slider.custom_minimum_size=Vector2(450,24);slider.min_value=.0008 if prop=="sensitivity" else .8 if prop=="ui_scale" else 0;slider.max_value=.006 if prop=="sensitivity" else 1.3 if prop=="ui_scale" else 1;slider.step=.0001 if prop=="sensitivity" else .05;slider.value=settings[prop];content.add_child(slider)
		slider.value_changed.connect(func(value):settings[prop]=value;game.apply_settings())
	button("ТРЯСКА КАМЕРЫ: "+("ВКЛ" if settings.shake else "ВЫКЛ"),func():settings.shake=not settings.shake;game.apply_settings();settings_panel())
	button("КАЧЕСТВО: "+["НИЗКОЕ","СРЕДНЕЕ"][int(settings.quality)],func():settings.quality=1-int(settings.quality);game.apply_settings();settings_panel())
	content.add_child(label("ПЕРЕНАЗНАЧЕНИЕ КЛАВИШ: нажмите действие, затем новую клавишу",15,MUTED))
	for action in game.key_actions:
		var a=action;var events=InputMap.action_get_events(a)
		button(a+"  /  "+(events[0].as_text() if events.size()>0 else "—"),func():rebind_action=a;game.notice("Нажмите новую клавишу для "+a))
	button("НАЗАД",menu if game.menu_open else pause_menu)

func _input(event):
	if rebind_action!="" and event is InputEventKey and event.pressed:
		InputMap.action_erase_events(rebind_action);var key=InputEventKey.new();key.physical_keycode=event.physical_keycode;InputMap.action_add_event(rebind_action,key);rebind_action="";game.apply_settings();settings_panel();get_viewport().set_input_as_handled()

func credits():
	open_panel("ПРОИСХОЖДЕНИЕ АССЕТОВ","Полные лицензии включены в third_party и Windows-поставку", "credits")
	var registry=JSON.parse_string(FileAccess.get_file_as_string("res://third_party/asset-register.json"))
	for entry in registry:
		content.add_child(label(str(entry.author)+" / "+str(entry.id)+" / "+str(entry.license)+"\n"+str(entry.source),17,TEXT))
	content.add_child(label("Детали андроидов — собственная модульная геометрия по предоставленным референсам.\nGodot Engine — MIT. Blender — средство подготовки исходных моделей.",17,MUTED))
	button("НАЗАД",menu)
