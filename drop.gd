extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

# --- KONFIGURACJA W INSPECTORZE (Gdy tworzysz gotowy prefabrykat w edytorze) ---
@export_group("Item Definition")
@export var item_name: String = "Miecz Przeznaczenia"
@export_enum("equipment", "material", "upgrade_stone", "stat_scroll", "modifier") var item_type: String = "equipment"
@export_enum("weapon", "shield", "helmet", "armor", "boots", "amulet", "ring", "none") var equip_slot: String = "weapon"
@export_enum("common", "uncommon", "rare", "epic", "legendary") var rarity: String = "common"
@export_multiline var description: String = "Starożytna broń leżąca na ziemi."

@export_group("Item Stats (Opcjonalne)")
@export var base_damage: int = 0
@export var attack_speed: float = 0.0
@export var crit_chance: float = 0.0
@export var block_chance: float = 0.0
@export var dodge_chance: float = 0.0
@export var luck: int = 0

@export_group("Bounce Settings")
@export var min_distance: float = 40.0
@export var max_distance: float = 80.0
@export var jump_height: float = 35.0
@export var total_duration: float = 1.0

# Słownik z danymi przedmiotu (przekazywany ze spawnera lub generowany z Inspectora)
@export var item_data: Dictionary = {}

# Referencja do aktywnego panelu tooltipa
var _tooltip_instance: Control = null
var _is_collected: bool = false # Zabezpieczenie przed wielokrotnym kliknięciem

# ==========================================
# TOOLTIP DATA & CONFIG
# ==========================================
const STAT_DISPLAY := {
	"base_damage":      ["Damage", Color(1, 1, 1), "int"],
	"attack_speed":     ["Attack Speed", Color(1, 1, 1), "speed"],
	"crit_chance":      ["Crit Chance", Color(1, 1, 1), "percent"],
	"crit_multiplier":  ["Crit Multiplier", Color(1, 1, 1), "mult"],
	"attack_range":     ["Attack Range", Color(0.5, 0.75, 1.0), "range"],
	"target_count":     ["Targets Hit", Color(0.5, 0.75, 1.0), "int"],
	"fire_damage":       ["Fire Damage", Color(1.0, 0.4, 0.2), "plus_int"],
	"poison_damage":     ["Poison Damage", Color(0.4, 0.85, 0.3), "int"],
	"poison_duration":   ["Poison Duration", Color(0.4, 0.85, 0.3), "seconds"],
	"slow_chance":       ["Slow Chance", Color(0.4, 0.7, 0.95), "percent"],
	"slow_amount":       ["Slow Amount", Color(0.4, 0.7, 0.95), "percent"],
	"stun_chance":       ["Stun Chance", Color(0.95, 0.85, 0.3), "percent"],
	"fear_chance":       ["Fear Chance", Color(0.7, 0.4, 0.85), "percent"],
	"lifesteal":         ["Lifesteal", Color(0.85, 0.3, 0.4), "percent"],
	"thorns":            ["Thorns", Color(0.6, 0.6, 0.65), "int"],
	"block_chance":      ["Block Chance", Color(0.6, 0.6, 0.65), "percent"],
	"armor_pierce":      ["Armor Pierce", Color(0.8, 0.5, 1.0), "int"],
	"dodge_chance":      ["Dodge Chance", Color(0.6, 0.6, 0.65), "percent"],
	"execute_threshold": ["Execute Threshold", Color(0.9, 0.25, 0.25), "percent"],
	"luck":              ["Item Drop Luck", Color(0.3, 0.9, 0.4), "plus_percent"],
}

func _ready() -> void:
	# 1. Zbudowanie item_data z pól Inspectora (jeśli spawner nie wstrzyknął własnych danych)
	_setup_item_data()

	# 2. Synchronizacja tekstury (pomiędzy Sprite2D a item_data)
	_sync_texture()

	# 3. Włączenie wykrywania kursora i kliknięć
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	# 4. Czekamy jedną klatkę na pozycję ze spawnera i odpalamy animację odbicia
	await get_tree().process_frame
	_animate_bounce()

# Zbudowanie słownika z ustawień Inspectora
func _setup_item_data() -> void:
	# 1. Jeśli item_data jest puste (brak spawnera), budujemy je z Inspectora
	if item_data.is_empty():
		var slot_val: String = equip_slot if (item_type == "equipment" and equip_slot != "none") else ""

		item_data = {
			"id": item_name.to_snake_case(),
			"name": item_name,
			"item_type": item_type,
			"equip_slot": slot_val,
			"rarity": rarity,
			"description": description,
			"stackable": item_type != "equipment",
			"count": 1
		}

		if base_damage > 0: item_data["base_damage"] = base_damage
		if attack_speed > 0.0: item_data["attack_speed"] = attack_speed
		if crit_chance > 0.0: item_data["crit_chance"] = crit_chance
		if block_chance > 0.0: item_data["block_chance"] = block_chance
		if dodge_chance > 0.0: item_data["dodge_chance"] = dodge_chance
		if luck > 0: item_data["luck"] = luck

	# 2. BEZPIECZNIK: Uzupełniamy ewentualne brakujące klucze w przekazanym słowniku
	if not item_data.has("id"):
		item_data["id"] = item_data.get("name", "item").to_snake_case()
	if not item_data.has("item_type"):
		item_data["item_type"] = "equipment"
	if not item_data.has("equip_slot") and item_data["item_type"] == "equipment":
		item_data["equip_slot"] = "weapon"
	if not item_data.has("stackable"):
		item_data["stackable"] = (item_data["item_type"] != "equipment")
	if not item_data.has("count"):
		item_data["count"] = 1
	if not item_data.has("rarity"):
		item_data["rarity"] = "common"

func _sync_texture() -> void:
	if sprite == null:
		return

	# A) Przepisz teksturę ze Sprite2D do item_data (jeśli item_data jej nie ma)
	if sprite.texture != null and not item_data.has("texture"):
		item_data["texture"] = sprite.texture

	# B) Przepisz teksturę z item_data do Sprite2D (jeśli spawner wstrzyknął teksturę)
	elif item_data.has("texture") and item_data["texture"] != null:
		sprite.texture = item_data["texture"]

func _process(_delta: float) -> void:
	# Podążanie tooltipa za kursorem myszy
	if is_instance_valid(_tooltip_instance):
		_tooltip_instance.global_position = get_viewport().get_mouse_position() + Vector2(14, 14)

func _exit_tree() -> void:
	_hide_tooltip()

# ==========================================
# HOVER & PODNOSZENIE PRZEDMIOTU
# ==========================================
func _on_mouse_entered() -> void:
	_show_tooltip()

func _on_mouse_exited() -> void:
	_hide_tooltip()

func _show_tooltip() -> void:
	if item_data.is_empty() or is_instance_valid(_tooltip_instance):
		return

	_tooltip_instance = _build_tooltip_panel()
	if _tooltip_instance:
		get_tree().root.add_child(_tooltip_instance)
		_tooltip_instance.global_position = get_viewport().get_mouse_position() + Vector2(14, 14)

func _hide_tooltip() -> void:
	if is_instance_valid(_tooltip_instance):
		_tooltip_instance.queue_free()
		_tooltip_instance = null

# Kliknięcie myszką w przedmiot leżący na ziemi
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_collected:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled() # Blokujemy przekazanie kliknięcia pod spód
		EventBus.item_pickup_requested.emit(item_data, self)

# Wywoływane przez inventory.gd gdy przedmiot uda się pomyślnie schować do plecaka
func on_collected() -> void:
	_is_collected = true
	_hide_tooltip()
	queue_free()

# ==========================================
# GENERATOR TOOLTIPA (RPG STYLE)
# ==========================================
func _build_tooltip_panel() -> Control:
	var container = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_color = _get_rarity_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)

	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	container.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	container.add_child(vbox)

	# Nazwa
	var name_label = Label.new()
	name_label.text = item_data.get("name", "Przedmiot")
	name_label.add_theme_color_override("font_color", _get_rarity_color())
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Rzadkość / Slot Ekwipunku
	var rarity_label = Label.new()
	var rarity_str = item_data.get("rarity", "common").to_upper()
	var equip_slot_str = item_data.get("equip_slot", "")
	
	if equip_slot_str != "":
		rarity_label.text = "[ %s • %s ]" % [rarity_str, equip_slot_str.to_upper()]
	else:
		rarity_label.text = "[ %s ]" % rarity_str

	rarity_label.add_theme_color_override("font_color", _get_rarity_color() * 0.8)
	rarity_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(rarity_label)

	# Linia oddzielająca
	var line = ColorRect.new()
	line.custom_minimum_size = Vector2(100, 1)
	line.color = Color(0.3, 0.3, 0.3, 0.5)
	vbox.add_child(line)

	# Ilość (dla materiałów/stosów)
	var count: int = item_data.get("count", 1)
	if count > 1:
		var count_lbl = Label.new()
		count_lbl.text = "Ilość: %d" % count
		count_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		count_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(count_lbl)

	# Lista statystyk
	var stat_rows := _get_stat_rows()
	if not stat_rows.is_empty():
		var stat_spacer = Control.new()
		stat_spacer.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(stat_spacer)

		for row in stat_rows:
			var stat_lbl = Label.new()
			stat_lbl.text = row["text"]
			stat_lbl.add_theme_color_override("font_color", row["color"])
			stat_lbl.add_theme_font_size_override("font_size", 12)
			vbox.add_child(stat_lbl)

	_add_special_item_rows(vbox)

	# Opis
	if item_data.has("description") and str(item_data["description"]) != "":
		var desc_spacer = Control.new()
		desc_spacer.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(desc_spacer)

		var desc_lbl = Label.new()
		desc_lbl.text = item_data["description"]
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(160, 0)
		vbox.add_child(desc_lbl)

	return container

func _get_stat_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for key in STAT_DISPLAY.keys():
		if not item_data.has(key): continue
		var value = item_data[key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or value == 0: continue

		var info = STAT_DISPLAY[key]
		var label_text: String = info[0]
		var color: Color = info[1]
		var fmt: String = info[2]

		var value_str := ""
		match fmt:
			"int": value_str = str(int(value))
			"plus_int": value_str = "+%d" % int(value)
			"percent": value_str = "%d%%" % int(round(value * 100.0))
			"plus_percent": value_str = "+%d%%" % int(value)
			"mult": value_str = "%.1fx" % value
			"speed": value_str = "%.2f/s" % value
			"range": value_str = "%.1fm" % value
			"seconds": value_str = "%.1fs" % value
			_: value_str = str(value)

		rows.append({"text": "%s: %s" % [label_text, value_str], "color": color})
	return rows

func _add_special_item_rows(vbox: VBoxContainer) -> void:
	var item_type_str: String = item_data.get("item_type", "")
	if item_type_str == "stat_scroll" and item_data.has("stat_target"):
		var target: String = item_data["stat_target"]
		var amount = item_data.get("stat_amount", 0)
		var display_name: String = STAT_DISPLAY.get(target, [target.capitalize()])[0]
		var lbl = Label.new()
		lbl.text = "Dodaje: +%s %s" % [str(amount), display_name]
		lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.3))
		lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(lbl)

	if item_type_str == "upgrade_stone" and item_data.has("success_chance"):
		var chance: float = item_data["success_chance"]
		var lbl = Label.new()
		lbl.text = "Szansa sukcesu: %d%%" % int(round(chance * 100.0))
		lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
		lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(lbl)

func _get_rarity_color() -> Color:
	var rarity_str: String = item_data.get("rarity", "common")
	match rarity_str:
		"common": return Color(0.7, 0.7, 0.7)
		"uncommon": return Color(0.2, 0.8, 0.2)
		"rare": return Color(0.2, 0.5, 1.0)
		"epic": return Color(0.7, 0.2, 0.9)
		"legendary": return Color(1.0, 0.7, 0.0)
	return Color.WHITE

# ==========================================
# ANIMACJA ODBICIA
# ==========================================
func _animate_bounce() -> void:
	if sprite == null: return

	var random_angle := randf_range(0.0, TAU)
	var distance := randf_range(min_distance, max_distance)
	var target_position := global_position + Vector2.RIGHT.rotated(random_angle) * distance

	var ground_tween := create_tween()
	ground_tween.tween_property(self, "global_position", target_position, total_duration)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var height_tween := create_tween()
	height_tween.tween_property(sprite, "position:y", -jump_height, total_duration * 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	height_tween.tween_property(sprite, "position:y", 0.0, total_duration * 0.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	height_tween.tween_property(sprite, "position:y", -jump_height * 0.5, total_duration * 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	height_tween.tween_property(sprite, "position:y", 0.0, total_duration * 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	height_tween.tween_property(sprite, "position:y", -jump_height * 0.2, total_duration * 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	height_tween.tween_property(sprite, "position:y", 0.0, total_duration * 0.07)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	height_tween.tween_property(sprite, "position:y", -3.0, total_duration * 0.04)
	height_tween.tween_property(sprite, "position:y", 0.0, total_duration * 0.04)