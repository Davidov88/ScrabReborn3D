class_name ScrapCatalog
extends RefCounted

var data: Dictionary = {}
var parts: Dictionary = {}
var weapons: Dictionary = {}
var programs: Dictionary = {}
var enemies: Dictionary = {}
var visuals: Array = []
const HARDWARE={"LOAD1_CONTROLLER":{"load_bonus":15},"LOAD3_WEIGHT_CONTROLLER":{"load_bonus":35},"SERVO_SYNC_BASIC":{"accuracy_bonus":5},"RECOILX_MICRO":{"accuracy_bonus":8},"EVASION_MICROCONTROLLER":{"dash_bonus":8},"COMPLIANCE_BLOCKER":{"reaction_suppression":15},"SHIELD_SYNC_DRIVER_HW":{"shield_bonus":15},"SYNC_CORE_X":{"load_bonus":25},"MOVE1_CONTROLLER":{"mobility_bonus":4},"BALANCE2_CONTROLLER":{"stability_bonus":12},"RECOILX_CONTROLLER":{"accuracy_bonus":8},"GRIPSOFT_CONTROLLER":{"salvage_bonus":3},"ECORUN_CONTROLLER":{"movement_saving":20},"SYNCCORE_CONTROLLER":{"load_bonus":25},"SIGNAL_BEACON_R2":{"scan_bonus":20}}

func _init():
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	parts = data.parts
	weapons = data.weapons
	programs = data.programs
	programs["LOW_LIGHT_VISION"]={"id":"LOW_LIGHT_VISION","program_id":"LOW_LIGHT_VISION","type":"system","cpu_req":1,"ram_req":1,"idle_energy":.5,"active_energy":1,"heat":0,"boot_time":.1,"duration":0,"cooldown":0,"formula_effect":"Усиливает остаточный свет сенсора. N — включить / выключить. Потребляет 1 CPU и 0,5 энергии/сек."}
	enemies = data.enemies
	visuals = data.visuals

func definition(id: String) -> Dictionary:
	return parts.get(id, weapons.get(id, {}))

func label(id: String) -> String:
	var d=definition(id);var visual=str(d.get("visual_id",""))
	var titles={"arms":["Базовый манипулятор","Ремонтная рука","Силовой кулак","Щитовая рука","Пистолетная рука","Снайперская рука","Хакерский манипулятор","Плазменный резак","Импульсная рука","Рука-дробовик","Тяжёлый захват","Экспериментальная рука"],"torsos":["Бытовой корпус","Сервисный корпус","Охранный корпус","Хакерский корпус","Корпоративный корпус","Промышленный корпус","Военный корпус","Полицейский корпус","Экспериментальный корпус","Тяжёлый корпус","Скрытный корпус","Корпус прототипа"],"legs":["Бытовые ноги","Сервисные ноги","Разведывательные ноги","Охранные ноги","Промышленные ноги","Грузовые ноги","Скрытные ноги","Манёвренные ноги","Штурмовые ноги","Корпоративные ноги","Прыжковые ноги","Экспериментальные ноги"],"heads":["Бытовой сенсор","Сервисный сенсор","Охранный сенсор","Хакерский сенсор","Корпоративный сенсор","Экспериментальный сенсор"]}
	var family=visual.get_slice("_",0);var index=int(visual.get_slice("_",1))-1
	if titles.has(family) and index>=0 and index<titles[family].size():return titles[family][index]+" / "+id.get_slice("_",0)
	return str(definition(id).get("name", id.replace("_", " ")))

func program_label(id: String) -> String:
	var labels = {"ENERGY_ROUTER":"Распределитель энергии", "HEAT_OPTIMIZER":"Оптимизация тепла", "CPU_SCHEDULER":"Планировщик CPU", "LOAD_BALANCER":"Балансировщик нагрузки", "SERVO_SYNC":"Синхронизация приводов", "BATTERY_SAVER":"Экономия батареи", "EMERGENCY_THROTTLE":"Аварийный ограничитель", "VULNERABILITY_SCAN":"Анализ уязвимостей", "LOOT_DIAGNOSTICS":"Диагностика демонтажа", "ARMOR_PATTERN_ANALYSIS":"Анализ брони", "HEAT_MAP":"Тепловая карта", "SIGNAL_TRACE":"Поиск сигналов", "PRECISION_STRIKE":"Точный удар", "RECOIL_CONTROL":"Контроль отдачи", "AUTO_PARRY":"Автопарирование", "DASH_STRIKE":"Удар с рывка", "LOW_DAMAGE_DISABLE":"Бережное отключение", "SERVO_HIJACK":"Перехват сервоприводов", "POWER_SPIKE":"Скачок питания", "FALSE_SIGNAL":"Ложный сигнал", "DRONE_CAPTURE":"Захват дрона", "MEMORY_EXTRACT":"Извлечение памяти", "BLACKBOX_READER":"Чтение чёрного ящика", "CORP_SIGNATURE_TRACE":"Корпоративный след"}
	return "Усиленное зрение" if id=="LOW_LIGHT_VISION" else labels.get(id, id)

static func zone_label(zone: String) -> String:
	return {"left_arm":"ЛЕВАЯ РУКА", "right_arm":"ПРАВАЯ РУКА", "legs":"ШАССИ", "torso":"КОРПУС", "sensor":"СЕНСОР", "cpu":"ПРОЦЕССОР", "power_core":"ПИТАНИЕ", "cooling":"ОХЛАЖДЕНИЕ", "controller":"КОНТРОЛЛЕР", "memory":"ПАМЯТЬ", "comm_module":"СВЯЗЬ", "drone_body":"КОРПУС ДРОНА", "drone_engine":"ДВИГАТЕЛЬ"}.get(zone, zone.to_upper())

func summary(d: Dictionary) -> String:
	var bonuses=hardware_effects(d)
	if not bonuses.is_empty():
		var lines=[]
		for key in bonuses:lines.append(metric_label(key)+" +%.0f" % float(bonuses[key]))
		return ". ".join(lines)+". Работает, пока модуль исправен."
	if d.has("role") and str(d.role).length()>12:return str(d.role).left(1).to_upper()+str(d.role).substr(1)+"."
	return {"arm":"Манипулятор задаёт атаку этой руки и возможность держать оружие.","torso":"Несущий корпус: броня, допустимая масса и крепления модулей.","legs":"Приводы ног определяют скорость, устойчивость и грузоподъёмность.","sensor":"Сенсор отвечает за обнаружение и точность наведения.","cpu":"Процессор задаёт вычислительный бюджет и число программ.","power_core":"Источник питания: заряд, восстановление и мощность одновременных действий.","cooling":"Отводит тепло. Мощное охлаждение позволяет дольше атаковать без перегрева.","controller":"Управляет приводами и усиливает указанные характеристики сборки.","memory":"Хранит данные и улики. Установка занимает дополнительное крепление.","comm_module":"Обеспечивает связь и доступ к программному взаимодействию.","adapter":"Универсальное крепление для совместимых узлов дронов.","drone_engine":"Через адаптер усиливает перемещение. Свободного полёта не даёт."}.get(str(d.get("type","")),"Внешнее оружие устанавливается в совместимый манипулятор.")

func metrics(d: Dictionary) -> Array:
	var fields={"arm":["attack_damage","armor_pen","attack_energy","attack_accuracy"],"legs":["load_cap","mobility","stability"],"torso":["mount_limit","slot_count","internal_protection"],"sensor":["accuracy_bonus","scan_range"],"cpu":["cpu_cap","program_slots"],"power_core":["energy_cap","power_gen","peak_output"],"cooling":["cooling_passive","cooling_burst"],"controller":[]}.get(str(d.get("type","")),["damage","armor_pen","energy_cost","magazine_size"])
	var rows=[]
	for field in fields+["armor","mass","idle_energy","cpu_req"]:
		if d.has(field):rows.append([field,float(d[field])])
	for key in hardware_effects(d):rows.push_front([key,float(hardware_effects(d)[key])])
	return rows

func hardware_effects(d: Dictionary) -> Dictionary:
	return HARDWARE.get(str(d.get("id","")),{})

static func metric_label(key: String) -> String:
	var extras={"load_bonus":"Доп. нагрузка, кг","dash_bonus":"Усиление рывка, %","reaction_suppression":"Замедление обнаружения, %","shield_bonus":"Усиление блока, %","mobility_bonus":"Бонус подвижности","stability_bonus":"Бонус устойчивости","salvage_bonus":"Сохранение при демонтаже, %","movement_saving":"Экономия движения, %","scan_bonus":"Дальность сканирования, %"}
	extras["scan_range"]="Дальность сенсора, м";extras["cooling_burst"]="Резерв охлаждения"
	if extras.has(key):return extras[key]
	return {"attack_damage":"Урон удара / выстрела","damage":"Урон","armor_pen":"Пробитие брони","attack_energy":"Энергия на атаку","energy_cost":"Энергия на атаку","attack_accuracy":"Точность наведения","accuracy_bonus":"Бонус точности","load_cap":"Грузоподъёмность, кг","mobility":"Подвижность","stability":"Устойчивость","mount_limit":"Лимит корпуса, кг","slot_count":"Доп. крепления","internal_protection":"Защита внутренних узлов","cpu_cap":"Мощность CPU","program_slots":"Слоты программ","energy_cap":"Запас энергии","power_gen":"Генерация в секунду","peak_output":"Пиковая мощность","cooling_passive":"Охлаждение в секунду","cooling_active":"Активное охлаждение","armor":"Броня детали","mass":"Масса, кг","idle_energy":"Потребление в секунду","cpu_req":"Нагрузка CPU","magazine_size":"Ёмкость магазина","detection_range":"Дальность сенсора"}.get(key,key.replace("_"," "))

func reference_texture(d: Dictionary) -> Texture2D:
	for visual in visuals:
		if visual.id==d.get("visual_id",""):
			var path="res://assets/references/"+str(visual.source).replace("\\","/").get_file()
			if ResourceLoader.exists(path):return load(path)
	return null

func program_summary(id: String) -> String:
	return {"ENERGY_ROUTER":"На 12% меньше энергии на атаки.","HEAT_OPTIMIZER":"На 12% меньше нагрева от атак.","CPU_SCHEDULER":"Освобождает 2 единицы CPU.","LOAD_BALANCER":"Добавляет 20 кг допустимой нагрузки.","SERVO_SYNC":"Уменьшает разброс выстрелов на 20%.","BATTERY_SAVER":"Снижает расход энергии на передвижение.","EMERGENCY_THROTTLE":"Сразу снимает 30 единиц нагрева.","VULNERABILITY_SCAN":"Диагностика показывает защищённые внутренние узлы.","LOOT_DIAGNOSTICS":"Сохраняет ещё 3% прочности при демонтаже.","ARMOR_PATTERN_ANALYSIS":"При расчёте попадания игнорирует 8 единиц брони.","HEAT_MAP":"Усиливает термический урон на 15% и показывает нагрев цели.","SIGNAL_TRACE":"Показывает сетевой статус и усиливает повреждение связи на 15%.","PRECISION_STRIKE":"Урон +15%, разброс уменьшается на 70%.","RECOIL_CONTROL":"Уменьшает разброс на 30%.","AUTO_PARRY":"Раз в 4 секунды вдвое ослабляет входящий удар.","DASH_STRIKE":"Во время действия атаки наносят на 25% больше урона.","LOW_DAMAGE_DISABLE":"На 55% уменьшает показатель критического разрушения детали.","SERVO_HIJACK":"На 5 секунд отключает ноги и правую руку цели. Нужен хакерский порт.","POWER_SPIKE":"Добавляет цели 35 единиц нагрева. Нужен хакерский порт.","FALSE_SIGNAL":"На 4 секунды отключает сенсор цели. Нужен хакерский порт.","DRONE_CAPTURE":"На 8 секунд обращает дрона против других врагов.","MEMORY_EXTRACT":"Извлекает данные памяти в журнал.","BLACKBOX_READER":"Считывает служебные записи чёрного ящика.","CORP_SIGNATURE_TRACE":"Сохраняет корпоративную подпись как улику.","LOW_LIGHT_VISION":"Усиливает остаточный свет. N — включение. 1 CPU и 0,5 энергии/сек."}.get(id,"")
