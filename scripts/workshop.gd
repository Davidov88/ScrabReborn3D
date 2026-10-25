class_name ScrapWorkshop
extends RefCounted

var ui: ScrapUI
var game
var selected_index=-1
var slots=["sensor","torso","left_arm","right_arm","legs","cpu","power_core","cooling","controller","memory","comm_module","adapter","drone_engine"]

func text(value: String,parent: Node,size: int=16,color: Color=ScrapUI.TEXT) -> Label:
	var l=ui.label(value,size,color);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(l);return l

func compatible(d: Dictionary,slot: String) -> bool:
	return str(d.get("type",""))==("arm" if slot in ["left_arm","right_arm"] else slot)

func build(owner: ScrapUI):
	ui=owner;game=ui.game
	ui.open_panel("МОДУЛЬНЫЙ КОРПУС / МАСТЕРСКАЯ","1  Выберите крепление на теле     2  Посмотрите совместимые детали     3  Установите одним нажатием", "workshop")
	var r=game.player.state
	for i in range(r.inventory.size()):
		if r.inventory[i].uid==ui.workshop_candidate and compatible(game.sim.definition(r.inventory[i]),ui.selected_slot):selected_index=i
	var toolbar=HBoxContainer.new();ui.content.add_child(toolbar)
	ui.button("СБОРКА",func():ui.inventory(true),toolbar)
	ui.button("РУЧНОЕ ОРУЖИЕ",func():ui.inventory(true,"weapons"),toolbar)
	ui.button("ПРОГРАММЫ",func():ui.inventory(true,"programs"),toolbar)
	if not ui.workshop_undo.is_empty():ui.button("ОТМЕНИТЬ ПОСЛЕДНЮЮ ЗАМЕНУ",undo,toolbar)
	var columns=HFlowContainer.new();columns.add_theme_constant_override("h_separation",18);columns.add_theme_constant_override("v_separation",18);ui.content.add_child(columns)
	var width=maxf(270,(ui.root.size.x-105)/3)
	var body=VBoxContainer.new();body.custom_minimum_size.x=width;body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(body)
	var list=VBoxContainer.new();list.custom_minimum_size.x=width;list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(list)
	var detail=VBoxContainer.new();detail.custom_minimum_size.x=width;detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(detail)
	text("КАРТА КРЕПЛЕНИЙ",body,15,ScrapUI.ACCENT)
	var preview=r.duplicate(true)
	if selected_index>=0:game.sim.install(preview,selected_index,ui.selected_slot)
	var container=ui.add_assembly_preview(preview,body,270,false)
	if ui.selected_slot not in ["sensor","torso","left_arm","right_arm","legs"]:container.get_meta("preview_model").inspect_internals(true)
	body.get_child(body.get_child_count()-1).visible=false
	var markers=Control.new();markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);markers.mouse_filter=Control.MOUSE_FILTER_IGNORE;container.add_child(markers)
	var positions={"sensor":Vector2(.50,.07),"torso":Vector2(.50,.34),"left_arm":Vector2(.80,.41),"right_arm":Vector2(.20,.41),"legs":Vector2(.50,.78)}
	for slot in positions:
		var key=slot;var b=ui.button(ScrapCatalog.zone_label(key),func():select_slot(key),markers)
		b.add_theme_font_size_override("font_size",11);b.custom_minimum_size=Vector2(100,28);b.anchor_left=positions[key].x;b.anchor_right=positions[key].x;b.anchor_top=positions[key].y;b.anchor_bottom=positions[key].y;b.offset_left=-50;b.offset_right=50;b.offset_top=0;b.offset_bottom=28
		compact(b)
		if key==ui.selected_slot:b.modulate=ScrapUI.ACCENT
	text("ВНУТРЕННИЕ МОДУЛИ",body,14,ScrapUI.ACCENT)
	var internal=GridContainer.new();internal.columns=2;body.add_child(internal)
	for slot in slots.slice(5):
		var key=slot;var mounted=r.assembly.has(key)
		var b=ui.button(ScrapCatalog.zone_label(key)+("  •" if mounted else "  +"),func():select_slot(key),internal);b.add_theme_font_size_override("font_size",12);b.custom_minimum_size=Vector2(165,30)
		compact(b)
		if key==ui.selected_slot:b.modulate=ScrapUI.ACCENT
	var stats=game.sim.stats(r);var after=game.sim.stats(preview)
	text("СБОРКА: СЕЙЧАС → ПРИМЕРКА" if selected_index>=0 else "РЕСУРСЫ СБОРКИ",body,14,ScrapUI.ACCENT)
	text("Масса %.1f → %.1f / %.0f кг\nПитание %.1f → %.1f / %.1f в сек\nCPU %.0f → %.0f / %.0f\nОхлаждение %.1f → %.1f в сек" % [stats.mass,after.mass,after.safe_load,stats.idle,after.idle,after.generation,stats.cpu_load,after.cpu_load,after.cpu_cap,stats.cooling,after.cooling],body,13)
	if after.load_ratio>1:text("ПЕРЕГРУЗКА: движение замедлится",body,14,Color("e18766"))
	if after.idle>after.generation:text("ДЕФИЦИТ ПИТАНИЯ: заряд будет падать",body,14,Color("e18766"))
	text(ScrapCatalog.zone_label(ui.selected_slot),list,21,ScrapUI.ACCENT)
	text("ПКМ — атака левой рукой" if ui.selected_slot=="left_arm" else "ЛКМ — атака правой рукой" if ui.selected_slot=="right_arm" else slot_purpose(ui.selected_slot),list,14,ScrapUI.MUTED)
	var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(width,450);scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_child(scroll)
	var candidates=VBoxContainer.new();candidates.size_flags_horizontal=Control.SIZE_EXPAND_FILL;candidates.add_theme_constant_override("separation",10);scroll.add_child(candidates)
	var count=0
	for i in range(r.inventory.size()):
		var p=r.inventory[i];var d=game.sim.definition(p)
		if not compatible(d,ui.selected_slot):continue
		count+=1
		candidate_card(candidates,i,p,d)
	if count==0:text("На складе нет деталей для этого крепления.\n\nСнимайте уцелевшие узлы противников или ищите технические хранилища.",candidates,18,ScrapUI.MUTED)
	var current=r.assembly.get(ui.selected_slot)
	var candidate=r.inventory[selected_index] if selected_index>=0 else current
	text("ПРИМЕРКА / ЕЩЁ НЕ УСТАНОВЛЕНО" if selected_index>=0 else "УСТАНОВЛЕНО" if current!=null else "СВОБОДНОЕ КРЕПЛЕНИЕ",detail,14,ScrapUI.ACCENT)
	if candidate==null:
		text(slot_purpose(ui.selected_slot),detail,22);return
	var d=game.sim.definition(candidate)
	text(game.catalog.label(candidate.id),detail,22)
	var picture=game.catalog.reference_texture(d)
	if picture!=null:
		var art=TextureRect.new();art.texture=picture;art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.custom_minimum_size=Vector2(width,150);detail.add_child(art)
	else:ui.add_part_preview(d,detail)
	text(game.catalog.summary(d),detail,15,ScrapUI.TEXT)
	if d.get("type","")=="arm":
		text("Держит ручное оружие" if d.get("can_hold_weapon",false) else "Встроенное оружие. Ручное оружие не устанавливается.",detail,14,ScrapUI.ACCENT)
		if float(d.get("attack_energy",0))>after.peak:text("НЕ ХВАТАЕТ МОЩНОСТИ: атака требует %.0f, доступно %.1f. Сначала усилите питание." % [float(d.get("attack_energy",0)),after.peak],detail,14,Color("e18766"))
	text("Прочность %.0f / %.0f • %s" % [candidate.durability,candidate.max_durability,game.sim.state_name(candidate)],detail,14)
	text("ХАРАКТЕРИСТИКА              СЕЙЧАС → НОВАЯ",detail,12,ScrapUI.MUTED)
	var old=game.sim.definition(current) if current!=null else {}
	for metric in game.catalog.metrics(d):
		var key=metric[0];var value=float(metric[1]);var previous=float(game.catalog.hardware_effects(old).get(key,old.get(key,0)));var delta=value-previous
		var good=delta<0 if key in ["mass","idle_energy","cpu_req","attack_energy","energy_cost"] else delta>0
		var color=Color("8fbea3") if good else Color("df9677") if absf(delta)>.001 else ScrapUI.TEXT
		text("%s   %.1f → %.1f %s" % [ScrapCatalog.metric_label(key),previous,value,"(%+.1f)" % delta if absf(delta)>.001 else ""],detail,14,color)
	if selected_index>=0:
		var copy=r.duplicate(true);var error=game.sim.install(copy,selected_index,ui.selected_slot)
		if error!="":text(error,detail,15,Color("df9677"))
		else:ui.button("УСТАНОВИТЬ → "+ScrapCatalog.zone_label(ui.selected_slot),install.bind(selected_index),detail)
	if float(candidate.durability)<float(candidate.max_durability) and not candidate.destroyed:
		var cost=int(ceil((candidate.max_durability-candidate.durability)*float(d.get("repair_difficulty",1))/10))
		ui.button("ОТРЕМОНТИРОВАТЬ / %d ЛОМА" % cost,repair.bind(candidate),detail)

func slot_purpose(slot: String) -> String:
	return {"sensor":"Сенсор в голове: обзор и точность.","torso":"Грудной каркас: броня и крепления.","legs":"Ноги и таз: движение, масса и устойчивость.","cpu":"Внутри корпуса: вычисления и программы.","power_core":"Внутри корпуса: запас и генерация энергии.","cooling":"Внутри корпуса: отвод тепла от систем.","controller":"Дополнительное крепление: управление приводами.","memory":"Дополнительное крепление: память и улики.","comm_module":"Дополнительное крепление: каналы связи.","adapter":"Дополнительное крепление: совместимость узлов дрона.","drone_engine":"Через адаптер: усиление перемещения."}.get(slot,"")

func compact(button: Button):
	for state in ["normal","hover","pressed"]:
		var box=button.get_theme_stylebox(state).duplicate();box.set_content_margin_all(5);button.add_theme_stylebox_override(state,box)

func candidate_card(parent: Node,index: int,p: Dictionary,d: Dictionary):
	var card=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",ui.style(Color("1d3036") if p.uid==ui.workshop_candidate else Color("172329")));parent.add_child(card)
	var stack=VBoxContainer.new();card.add_child(stack)
	text(game.catalog.label(p.id),stack,16)
	var metrics=game.catalog.metrics(d);var summary=[]
	for metric in metrics.slice(0,2):summary.append(ScrapCatalog.metric_label(metric[0])+" %.0f" % metric[1])
	text(" • ".join(summary)+"\n%.0f / %.0f • %.0f кг" % [p.durability,p.max_durability,float(d.get("mass",0))],stack,13,ScrapUI.MUTED)
	var row=HBoxContainer.new();stack.add_child(row)
	ui.button("ПОСМОТРЕТЬ",func():ui.workshop_candidate=p.uid;ui.inventory(true),row)
	var copy=game.player.state.duplicate(true);var error=game.sim.install(copy,index,ui.selected_slot)
	var b=ui.button("УСТАНОВИТЬ",install.bind(index),row);b.disabled=error!="";b.tooltip_text=error if error!="" else "Сразу установить в "+ScrapCatalog.zone_label(ui.selected_slot)+". Старый узел останется на складе."
	if error!="":text(error,stack,12,Color("df9677"))

func select_slot(slot: String):
	ui.selected_slot=slot;ui.workshop_candidate="";ui.inventory(true)

func install(index: int):
	var r=game.player.state;var before=r.duplicate(true)
	var error=game.sim.install(r,index,ui.selected_slot)
	if error=="":
		if ui.selected_slot=="sensor":
			game.story.core.transfer_count=int(game.story.core.get("transfer_count",0))+1
			game.notice("Сенсор заменён. Личностное ядро Ильи перенесено в новый корпус.")
		ui.workshop_undo.append(before)
		if ui.workshop_undo.size()>8:ui.workshop_undo.pop_front()
		game.player.refresh();ui.workshop_candidate=""
	else:game.notice(error)
	ui.inventory(true)

func undo():
	if ui.workshop_undo.is_empty():return
	var r=game.player.state;r.clear();r.merge(ui.workshop_undo.pop_back(),true);game.player.refresh();ui.workshop_candidate="";ui.inventory(true)

func repair(p: Dictionary):
	game.notice(game.sim.repair(game.player.state,p));game.player.refresh();ui.inventory(true)
