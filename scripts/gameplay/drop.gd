extends Area2D

@onready var sprite: Sprite2D = %Sprite2D
@onready var visuals: Node2D = %Visuals
@onready var name_label: Label = %Name

# --- NOWA, LEKKA KONFIGURACJA W INSPEKTORZE ---
@export_group("Fallback Resource")
# Jeśli kładziesz przedmiot ręcznie na mapie, przeciągnij tu plik .tres (np. steel_sword.tres)
@export var fallback_definition: ItemDefinition

@export_group("Bounce Settings")
@export var min_distance: float = 360.0
@export var max_distance: float = 480.0
@export var jump_height: float = 50.0
@export var total_duration: float = 1.5

@export_group("Despawn Settings")
@export var queue_free_timer: bool = true   # Czy ma znikać po czasie?
@export var despawn_time: float = 120.0    # Czas leżenia w sekundach (120s = 2 minuty)


@export var max_sprite_size: float = 64.0 # Maksymalna szerokość lub wysokość w pikselach
@export var sprite_display_size: Vector2 = Vector2(80, 80)

# Silnie typowana instancja przedmiotu (ustawiana przez spawner LUB z fallback_definition)
var item_data: ItemInstance = null

var _tooltip_instance: Control = null
var _is_collected: bool = false
var _current_lifetime: float = 0.0 # Licznik czasu leżenia na ziemi

# Ujednolicone mapowanie statystyk – identyczne jak w slot.gd
const STAT_DISPLAY := {
	"hp":           ["Max HP", Color(0.2, 0.8, 0.2), "plus_int"],
	"dmg":          ["Damage", Color(0.95, 0.3, 0.3), "plus_float"],
	"magic_dmg":    ["Magic Damage", Color(0.0, 0.3, 0.9), "plus_float"],
	"attack_speed": ["Attack Speed", Color(0.95, 0.95, 0.95), "speed"],
	"armor":        ["Armor", Color(0.6, 0.6, 0.65), "plus_int"],
	"crit_chance":  ["Crit Chance", Color(0.9, 0.7, 0.2), "percent"],
	"crit_damage":  ["Crit Damage", Color(0.9, 0.2, 0.2), "percent"],
	"dodge":        ["Dodge", Color(0.2, 0.8, 0.8), "percent"],
	"lifesteal":    ["Lifesteal", Color(0.85, 0.3, 0.4), "percent"],
}

const FONT_TITLE := 24
const FONT_BODY := 12

func _ready() -> void:
	_setup_item_data()
	_sync_texture()
	_sync_name_label()
	_check_rarity()
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	await get_tree().process_frame
	_animate_bounce()
	_current_lifetime = 0.0
	modulate.a = 1.0

func _process(delta: float) -> void:
	# 1. Aktualizacja pozycji tooltipa za myszką
	if is_instance_valid(_tooltip_instance):
		var mouse_pos := get_viewport().get_mouse_position()
		var offset := Vector2(14, 14)
		var tooltip_size := _tooltip_instance.size
		var viewport_size := get_viewport().get_visible_rect().size

		var final_pos := mouse_pos + offset
		# Trzymaj tooltip w granicach ekranu
		if final_pos.x + tooltip_size.x > viewport_size.x:
			final_pos.x = mouse_pos.x - tooltip_size.x - offset.x
		if final_pos.y + tooltip_size.y > viewport_size.y:
			final_pos.y = mouse_pos.y - tooltip_size.y - offset.y

		_tooltip_instance.global_position = final_pos

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
		EventBus.item_pickup_requested.emit(item_data, self)

func on_collected() -> void:
	_is_collected = true
	_hide_tooltip()
	queue_free()

# ==========================================
# SETUP
# ==========================================
func _setup_item_data() -> void:
	# Jeśli przedmiot został położony ręcznie i spawner go nie zainicjalizował:
	if item_data == null and fallback_definition != null:
		item_data = ItemInstance.new(fallback_definition, 1)

func _check_rarity() -> void:
	if item_data == null or item_data.definition == null:
		return

	var rarity_color := GameEnums.get_rarity_color(item_data.definition.rarity)

	if item_data.definition.rarity != GameEnums.Rarity.COMMON and item_data.definition.rarity != GameEnums.Rarity.UNCOMMON:
		%GPUParticles2D.get_process_material().set("color", rarity_color)
		%GPUParticles2D.emitting = true

func _sync_name_label() -> void:
	if name_label == null:
		return

	if item_data == null or item_data.definition == null:
		name_label.visible = false
		return

	name_label.text = item_data.definition.name
	name_label.visible = true

func _sync_texture() -> void:
	if sprite == null or item_data == null or item_data.definition == null:
		return

	if item_data.definition.icon:
		sprite.texture = item_data.definition.icon

	if sprite.texture:
		var tex_size := sprite.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			sprite.scale = Vector2(
				sprite_display_size.x / tex_size.x,
				sprite_display_size.y / tex_size.y
			)
		else:
			sprite.scale = Vector2.ONE

# ==========================================
# TOOLTIP BUILDING (styl jak w slot.gd)
# ==========================================
func _build_tooltip_panel() -> Control:
	if item_data == null or item_data.definition == null:
		return null

	var def = item_data.definition
	var rarity_color := _get_rarity_color()

	# ── Root ──────────────────────────────────────────────
	var container := PanelContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.top_level = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.96)
	style.border_color = Color(rarity_color, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	container.add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	container.add_child(root)

	# ── HEADER: ikona + nazwa/kategoria | cena ────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	# Ikona przedmiotu
	if def.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = def.icon
		icon_rect.custom_minimum_size = Vector2(22, 22)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		header.add_child(icon_rect)

	# Nazwa + kategoria
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)

	var title_label := Label.new()
	if item_data.dice_level >= 0:
		var dice_size := GameEnums.DICE_PROGRESSION[item_data.dice_level]
		title_label.text = "%s (d%d)" % [def.name, dice_size]
	else:
		title_label.text = def.name
	title_label.add_theme_color_override("font_color", Color(0.91, 0.84, 0.58)) # LoL gold
	title_label.add_theme_font_size_override("font_size", FONT_TITLE)
	title_box.add_child(title_label)

	var category_label := Label.new()
	category_label.text = GameEnums.Rarity.keys()[def.rarity].capitalize()
	category_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.42))
	category_label.add_theme_font_size_override("font_size", FONT_BODY)
	title_box.add_child(category_label)

	# Cena / sell value
	if def.get("sell_value") != null or def.get("price") != null:
		var price_box := VBoxContainer.new()
		price_box.alignment = BoxContainer.ALIGNMENT_CENTER
		header.add_child(price_box)

		var sell_label := Label.new()
		var price = def.sell_value if def.get("sell_value") != null else def.price
		sell_label.text = "Sells: %d" % price
		sell_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.40))
		sell_label.add_theme_font_size_override("font_size", FONT_BODY)
		sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_box.add_child(sell_label)

	# Ilość na ziemi (jeśli > 1) — zachowana informacja z drop.gd
	if item_data.quantity > 1:
		var qty_label := Label.new()
		qty_label.text = "x%d" % item_data.quantity
		qty_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		qty_label.add_theme_font_size_override("font_size", FONT_BODY)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(qty_label)

	# ── Separator ─────────────────────────────────────────
	root.add_child(_make_separator())

	# ── STATY ─────────────────────────────────────────────
	var stat_rows := _get_stat_rows()
	if not stat_rows.is_empty():
		var stats_box := VBoxContainer.new()
		stats_box.add_theme_constant_override("separation", 0)
		root.add_child(stats_box)

		for row in stat_rows:
			var row_h := HBoxContainer.new()
			row_h.add_theme_constant_override("separation", 0)
			stats_box.add_child(row_h)

			if row.has("icon") and row["icon"]:
				var s_icon := TextureRect.new()
				s_icon.texture = row["icon"]
				s_icon.custom_minimum_size = Vector2(12, 12)
				s_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				s_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				s_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				row_h.add_child(s_icon)

			var stat_lbl := Label.new()
			stat_lbl.text = row["text"]
			stat_lbl.add_theme_color_override("font_color", row.get("color", Color(0.85, 0.78, 0.50)))
			stat_lbl.add_theme_font_size_override("font_size", FONT_BODY)
			row_h.add_child(stat_lbl)

		root.add_child(_make_separator())

	# ── OPIS / PASYWKI ────────────────────────────────────
	if not def.description.is_empty():
		var blocks = def.description.split("\n\n", false)
		for i in blocks.size():
			var block: String = blocks[i].strip_edges()
			if block.is_empty():
				continue

			var lines := block.split("\n", false)
			var passive_box := VBoxContainer.new()
			passive_box.add_theme_constant_override("separation", 2)
			root.add_child(passive_box)

			if lines.size() >= 2:
				var p_title := Label.new()
				p_title.text = lines[0]
				p_title.add_theme_color_override("font_color", Color(0.91, 0.75, 0.35))
				p_title.add_theme_font_size_override("font_size", FONT_BODY)
				passive_box.add_child(p_title)

				var p_desc := RichTextLabel.new()
				p_desc.bbcode_enabled = true
				p_desc.fit_content = true
				p_desc.scroll_active = false
				p_desc.custom_minimum_size = Vector2(120, 0)
				p_desc.add_theme_color_override("default_color", Color(0.72, 0.72, 0.70))
				p_desc.add_theme_font_size_override("normal_font_size", FONT_BODY)
				p_desc.text = _colorize_numbers("\n".join(lines.slice(1)))
				passive_box.add_child(p_desc)
			else:
				var desc := RichTextLabel.new()
				desc.bbcode_enabled = true
				desc.fit_content = true
				desc.scroll_active = false
				desc.custom_minimum_size = Vector2(120, 0)
				desc.add_theme_color_override("default_color", Color(0.72, 0.72, 0.70))
				desc.add_theme_font_size_override("normal_font_size", FONT_BODY)
				desc.text = _colorize_numbers(block)
				passive_box.add_child(desc)

			if i < blocks.size() - 1:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 4)
				root.add_child(gap)

	return container


func _make_separator() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(0.35, 0.32, 0.22, 0.6)
	return line


func _colorize_numbers(text: String) -> String:
	var regex := RegEx.new()
	regex.compile(r"(\d+\.?\d*%?)")
	return regex.sub(text, "[color=#ff8c39]$1[/color]", true)


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
			var value_str := ""
			match info[2]:
				"plus_int": value_str = "%d" % int(value)
				"plus_float": value_str = "%.2f" % value
				"percent":
					var pct = int(round(value * 100.0)) if value <= 1.0 else int(round(value))
					value_str = "%d%%" % pct
				"speed": value_str = "%.2f/s" % value
				_: value_str = str(value)
			rows.append({"text": "%s %s" % [value_str, info[0]], "color": info[1]})
	return rows


func _get_rarity_color() -> Color:
	if item_data == null or item_data.definition == null:
		return Color.WHITE
	return GameEnums.get_rarity_color(item_data.definition.rarity)

# ==========================================
# ANIMACJA
# ==========================================
func _animate_bounce() -> void:
	if visuals == null: return
	var random_angle := randf_range(0.0, TAU)
	var distance := randf_range(min_distance, max_distance)
	var target_position := global_position + Vector2.RIGHT.rotated(random_angle) * distance

	var ground_tween := create_tween()
	ground_tween.tween_property(self, "global_position", target_position, total_duration)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var height_tween := create_tween()
	height_tween.tween_property(visuals, "position:y", -jump_height, total_duration * 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	height_tween.tween_property(visuals, "position:y", 0.0, total_duration * 0.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	height_tween.tween_property(visuals, "position:y", -jump_height * 0.5, total_duration * 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	height_tween.tween_property(visuals, "position:y", 0.0, total_duration * 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	height_tween.tween_property(visuals, "position:y", -jump_height * 0.2, total_duration * 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	height_tween.tween_property(visuals, "position:y", 0.0, total_duration * 0.07)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	height_tween.tween_property(visuals, "position:y", -3.0, total_duration * 0.04)
	height_tween.tween_property(visuals, "position:y", 0.0, total_duration * 0.04)
