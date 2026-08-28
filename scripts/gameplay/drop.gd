# drop.gd
extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

# --- NOWA, LEKKA KONFIGURACJA W INSPEKTORZE ---
@export_group("Fallback Resource")
# Jeśli kładziesz przedmiot ręcznie na mapie, przeciągnij tu plik .tres (np. steel_sword.tres)
@export var fallback_definition: ItemDefinition

@export_group("Bounce Settings")
@export var min_distance: float = 40.0
@export var max_distance: float = 80.0
@export var jump_height: float = 35.0
@export var total_duration: float = 1.0

@export_group("Despawn Settings")
@export var queue_free_timer: bool = true   # Czy ma znikać po czasie?
@export var despawn_time: float = 120.0    # Czas leżenia w sekundach (120s = 2 minuty)


@export var max_sprite_size: float = 64.0 # Maksymalna szerokość lub wysokość w pikselach

# Silnie typowana instancja przedmiotu (ustawiana przez spawner LUB z fallback_definition)
var item_data: ItemInstance = null

var _tooltip_instance: Control = null
var _is_collected: bool = false
var _current_lifetime: float = 0.0 # Licznik czasu leżenia na ziemi

# Ujednolicone mapowanie statystyk z ItemDefinition na etykiety i kolory
const STAT_DISPLAY := {
	"hp":           ["Max HP", Color(0.2, 0.8, 0.2), "plus_int"],
	"dmg":          ["Damage", Color(0.95, 0.3, 0.3), "plus_int"],
	"attack_speed": ["Attack Speed", Color(0.95, 0.95, 0.95), "speed"],
	"armor":        ["Armor", Color(0.6, 0.6, 0.65), "plus_int"],
	"crit_chance":  ["Crit Chance", Color(0.9, 0.7, 0.2), "percent"],
	"crit_damage":  ["Crit Damage", Color(0.9, 0.2, 0.2), "percent"],
	"dodge":        ["Dodge", Color(0.2, 0.8, 0.8), "percent"],
	"lifesteal":    ["Lifesteal", Color(0.85, 0.3, 0.4), "percent"],
}

func _ready() -> void:
	_setup_item_data()
	_sync_texture()

	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	await get_tree().process_frame
	_animate_bounce()

func _process(delta: float) -> void:
	# 1. Aktualizacja pozycji tooltipa za myszką
	if is_instance_valid(_tooltip_instance):
		_tooltip_instance.global_position = get_viewport().get_mouse_position() + Vector2(14, 14)

	# 2. Licznik czasu znikania
	if queue_free_timer and not _is_collected:
		_current_lifetime += delta

		# Miganie w ostatnich 3 sekundach życia
		if _current_lifetime >= despawn_time - 3.0:
			modulate.a = 0.3 + 0.7 * abs(sin(_current_lifetime * 10.0))

		# Czas minął -> usuwamy
		if _current_lifetime >= despawn_time:
			_hide_tooltip()
			queue_free()

func _exit_tree() -> void:
	_hide_tooltip()

# ==========================================
# HOVER & PICKUP
# ==========================================
func _on_mouse_entered() -> void:
	_show_tooltip()

func _on_mouse_exited() -> void:
	_hide_tooltip()

func _show_tooltip() -> void:
	if item_data == null or is_instance_valid(_tooltip_instance) or _is_collected:
		return

	_tooltip_instance = _build_tooltip_panel()
	if _tooltip_instance:
		get_tree().root.add_child(_tooltip_instance)
		_tooltip_instance.global_position = get_viewport().get_mouse_position() + Vector2(14, 14)

func _hide_tooltip() -> void:
	if is_instance_valid(_tooltip_instance):
		_tooltip_instance.queue_free()
		_tooltip_instance = null

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_collected or item_data == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		# Przekazujemy DEFINICJĘ do inventory (tak jak oczekuje sygnał) i SIEBIE (do usunięcia)
		EventBus.item_pickup_requested.emit(item_data.definition, self)

func on_collected() -> void:
	_is_collected = true
	_hide_tooltip()
	queue_free()

# ==========================================
# SETUP & TOOLTIP BUILDING
# ==========================================
func _setup_item_data() -> void:
	# Jeśli przedmiot został położony ręcznie i spawner go nie zainicjalizował:
	if item_data == null and fallback_definition != null:
		item_data = ItemInstance.new(fallback_definition, 1)

func _sync_texture() -> void:
	if sprite == null or item_data == null or item_data.definition == null: 
		return
		
	# 1. Przypisanie tekstury z zasobu
	if item_data.definition.icon:
		sprite.texture = item_data.definition.icon

	# 2. WYMUSZENIE MAKSYMALNEGO ROZMIARU (MAX SIZE)
	if sprite.texture:
		var tex_size = sprite.texture.get_size() # Rozmiar oryginalnej grafiki (np. 128x64)
		var max_dimension = max(tex_size.x, tex_size.y) # Pobieramy większy bok
		
		if max_dimension > max_sprite_size:
			# Obliczamy współczynnik skalowania (np. 48 / 128 = 0.375)
			var scale_factor = max_sprite_size / max_dimension
			sprite.scale = Vector2(scale_factor, scale_factor)
		else:
			# Jeśli grafika jest mniejsza niż max_sprite_size, zostawiamy oryginalną skalę 1:1
			sprite.scale = Vector2.ONE

func _build_tooltip_panel() -> Control:
	if item_data == null or item_data.definition == null:
		return null

	var def = item_data.definition

	var container = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_color = _get_rarity_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	container.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	container.add_child(vbox)

	# Nazwa przedmiotu
	var name_label = Label.new()
	name_label.text = def.name
	name_label.add_theme_color_override("font_color", _get_rarity_color())
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Rzadkość i Kategoria
	var rarity_label = Label.new()
	var rarity_str = GameEnums.Rarity.keys()[def.rarity]
	var category_str = ItemDefinition.Category.keys()[def.category]
	rarity_label.text = "[ %s • %s ]" % [rarity_str, category_str]
	rarity_label.add_theme_color_override("font_color", _get_rarity_color() * 0.8)
	rarity_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(rarity_label)

	# Linia oddzielająca
	var line = ColorRect.new()
	line.custom_minimum_size = Vector2(120, 1)
	line.color = Color(0.3, 0.3, 0.3, 0.5)
	vbox.add_child(line)

	# Ilość przedmiotu na ziemi (jeśli > 1)
	if item_data.quantity > 1:
		var count_lbl = Label.new()
		count_lbl.text = "Ilość: %d" % item_data.quantity
		count_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		count_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(count_lbl)

	# Statystyki generowane automatycznie z definicji
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

	# Opis przedmiotu
	if not def.description.is_empty():
		var desc_spacer = Control.new()
		desc_spacer.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(desc_spacer)
		var desc_lbl = Label.new()
		desc_lbl.text = def.description
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(180, 0)
		vbox.add_child(desc_lbl)

	return container

func _get_stat_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if item_data == null or item_data.definition == null:
		return rows

	var def = item_data.definition
	for property in STAT_DISPLAY.keys():
		if property in def:
			var value = def.get(property)
			if value == 0 or value == 0.0:
				continue

			var info = STAT_DISPLAY[property]
			var label: String = info[0]
			var color: Color = info[1]
			var fmt: String = info[2]

			var value_str := ""
			match fmt:
				"plus_int":
					value_str = "+%d" % int(value)
				"percent":
					var pct = int(round(value * 100.0)) if value <= 1.0 else int(round(value))
					value_str = "+%d%%" % pct
				"speed":
					value_str = "%.2f/s" % value
				_:
					value_str = str(value)

			rows.append({
				"text": "%s: %s" % [label, value_str],
				"color": color,
			})
	return rows

func _get_rarity_color() -> Color:
	if item_data == null or item_data.definition == null:
		return Color.WHITE
	return GameEnums.get_rarity_color(item_data.definition.rarity)

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
