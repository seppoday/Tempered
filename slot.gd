# slot.gd
extends Panel

# Dane przedmiotu w tym slocie (null/pusty słownik = pusty)
var item_data: Dictionary = {}

# Referencje do węzłów dzieci
var icon: TextureRect
var count_label: Label

# Sygnał wysyłany do inventory managera przy zmianie zawartości
signal slot_changed(slot: Panel)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_check_nodes()
	if icon:
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if count_label:
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _check_nodes() -> void:
	if not icon:
		icon = get_node_or_null("Icon") as TextureRect
	if not count_label:
		count_label = get_node_or_null("CountLabel") as Label

# ==========================================
# TOOLTIP (WŁASNY WYGLĄD RPG)
# ==========================================

# Klucze techniczne, które NIGDY nie mają się pokazać jako "stat" w tooltipie
const NON_STAT_KEYS := [
	"id", "name", "description", "item_type", "equip_slot",
	"count", "stackable", "rarity", "texture",
	"stat_target", "stat_amount", "success_chance",
]

# Metadane wyświetlania dla każdego znanego stata: [etykieta, kolor, format]
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

func _make_custom_tooltip(_for_text: String) -> Control:
	if item_data.is_empty():
		return null

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

	var name_label = Label.new()
	name_label.text = item_data.get("name", "Przedmiot")
	name_label.add_theme_color_override("font_color", _get_rarity_color())
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var rarity_label = Label.new()
	var rarity_str = item_data.get("rarity", "common").to_upper()
	rarity_label.text = "[ %s ]" % rarity_str
	rarity_label.add_theme_color_override("font_color", _get_rarity_color() * 0.8)
	rarity_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(rarity_label)

	var line = ColorRect.new()
	line.custom_minimum_size = Vector2(100, 1)
	line.color = Color(0.3, 0.3, 0.3, 0.5)
	vbox.add_child(line)

	var count: int = item_data.get("count", 1)
	if count > 1:
		var count_lbl = Label.new()
		count_lbl.text = "Ilość: %d" % count
		count_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		count_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(count_lbl)

	# ==========================================
	# NOWE: DOKŁADNE STATY ZAMIAST KRÓTKIEGO OPISU
	# ==========================================
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

	# Specjalne przypadki: stat_scroll / upgrade_stone mają staty w innym formacie
	_add_special_item_rows(vbox)

	# Opis zostaje, ale jako mały dopisek na końcu, nie główna treść
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

# Buduje listę {text, color} dla wszystkich znanych statów obecnych w item_data
func _get_stat_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for key in STAT_DISPLAY.keys():
		if not item_data.has(key):
			continue
		var value = item_data[key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		if value == 0:
			continue

		var info = STAT_DISPLAY[key]
		var label: String = info[0]
		var color: Color = info[1]
		var fmt: String = info[2]

		var value_str := ""
		match fmt:
			"int":
				value_str = str(int(value))
			"plus_int":
				value_str = "+%d" % int(value)
			"percent":
				value_str = "%d%%" % int(round(value * 100.0))
			"plus_percent":
				value_str = "+%d%%" % int(value)
			"mult":
				value_str = "%.1fx" % value
			"speed":
				value_str = "%.2f/s" % value
			"range":
				value_str = "%.1fm" % value
			"seconds":
				value_str = "%.1fs" % value
			_:
				value_str = str(value)

		rows.append({
			"text": "%s: %s" % [label, value_str],
			"color": color,
		})
	return rows

# Zwoje/kamienie mają inny kształt danych (stat_target/stat_amount, success_chance)
# — pokazujemy je w tooltipie w czytelnej formie
func _add_special_item_rows(vbox: VBoxContainer) -> void:
	var item_type: String = item_data.get("item_type", "")

	if item_type == "stat_scroll" and item_data.has("stat_target"):
		var target: String = item_data["stat_target"]
		var amount = item_data.get("stat_amount", 0)
		var display_name: String = STAT_DISPLAY.get(target, [target.capitalize()])[0]

		var lbl = Label.new()
		lbl.text = "Dodaje: +%s %s" % [str(amount), display_name]
		lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.3))
		lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(lbl)

	if item_type == "upgrade_stone" and item_data.has("success_chance"):
		var chance: float = item_data["success_chance"]
		var lbl = Label.new()
		lbl.text = "Szansa sukcesu: %d%%" % int(round(chance * 100.0))
		lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
		lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(lbl)

func _get_rarity_color() -> Color:
	var rarity: String = item_data.get("rarity", "common")
	match rarity:
		"common": return Color(0.7, 0.7, 0.7)
		"uncommon": return Color(0.2, 0.8, 0.2)
		"rare": return Color(0.2, 0.5, 1.0)
		"epic": return Color(0.7, 0.2, 0.9)
		"legendary": return Color(1.0, 0.7, 0.0)
	return Color.WHITE

# ==========================================
# DRAG & DROP (Z OBSŁUGĄ ROZDZIELANIA SHIFT/CTRL)
# ==========================================

func _get_drag_data(_at_position: Vector2) -> Variant:
	_check_nodes()
	if item_data.is_empty():
		return null

	var total_count: int = item_data.get("count", 1)
	var drag_count: int = total_count

	# SHIFT = Weź 1 sztukę
	if Input.is_key_pressed(KEY_SHIFT) and total_count > 1:
		drag_count = 1
	# CTRL = Weź połowę
	elif Input.is_key_pressed(KEY_CTRL) and total_count > 1:
		drag_count = int(total_count / 2.0)

	var dragged_item = item_data.duplicate()
	dragged_item["count"] = drag_count

	# Tworzenie podglądu pod kursorem
	var preview: TextureRect = TextureRect.new()
	if icon:
		preview.texture = icon.texture
	preview.modulate = Color(1, 1, 1, 0.8)
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Jeśli ciągniemy wybraną ilość, pokaże się przy ikonce cyferka
	if drag_count > 1:
		var p_label = Label.new()
		p_label.text = str(drag_count)
		p_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		preview.add_child(p_label)

	set_drag_preview(preview)

	return {
		"source_slot": self,
		"item": dragged_item,
		"drag_count": drag_count,
		"is_partial": drag_count < total_count
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("source_slot"):
		return false
	if data.source_slot == self:
		return false
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_slot: Panel = data["source_slot"]
	var dragged_item: Dictionary = data["item"]
	var drag_count: int = data.get("drag_count", 1)
	var is_partial: bool = data.get("is_partial", false)

	# 1. UPUSZCZENIE NA PUSTY SLOT
	if is_empty():
		set_item(dragged_item)
		if is_partial:
			source_slot.item_data["count"] -= drag_count
			source_slot._update_visual()
		else:
			source_slot.clear()

	# 2. UPUSZCZENIE NA ZAJĘTY SLOT
	else:
		var my_id = item_data.get("id", "")
		var dragged_id = dragged_item.get("id", "")
		var is_stackable = item_data.get("stackable", false) and dragged_item.get("stackable", false)

		# A) TEN SAM PRZEDMIOT -> ŁĄCZYMY STOSY
		if my_id == dragged_id and is_stackable:
			item_data["count"] += drag_count
			_update_visual()

			if is_partial:
				source_slot.item_data["count"] -= drag_count
				source_slot._update_visual()
			else:
				source_slot.clear()

		# B) INNY PRZEDMIOT -> ZAMIANA MIEJSCAMI (SWAP)
		else:
			if is_partial:
				# Nie można zamienić części stosu z innym przedmiotem
				print("[SLOT] Nie można zamienić części stosu z innym przedmiotem!")
				return
			else:
				var my_item: Dictionary = item_data.duplicate()
				source_slot.set_item(my_item)
				set_item(dragged_item)

	slot_changed.emit(self)
	source_slot.slot_changed.emit(source_slot)

# ==========================================
# PUBLIC API
# ==========================================

func set_item(data: Dictionary) -> void:
	item_data = data
	_update_visual()

func clear() -> void:
	item_data = {}
	_update_visual()

func is_empty() -> bool:
	return item_data.is_empty()

# ==========================================
# VISUAL (ujednolicony, delikatny wygląd)
# ==========================================

const BASE_BG := Color(0.12, 0.12, 0.14, 1.0)
const BASE_BORDER := Color(0.32, 0.32, 0.36, 1.0)

func _update_visual() -> void:
	_check_nodes()

	# Zawsze pełna widoczność – bez "przygaszania" pustych slotów
	modulate = Color.WHITE

	if item_data.is_empty():
		tooltip_text = ""
		if icon:
			icon.texture = null
			icon.visible = false
		if count_label:
			count_label.text = ""
		_apply_slot_style(BASE_BG, BASE_BORDER)
	else:
		tooltip_text = "use_custom"
		if icon:
			icon.texture = item_data.get("texture", null)
			icon.visible = icon.texture != null
		if count_label:
			var count: int = item_data.get("count", 1)
			count_label.text = str(count) if count > 1 else ""

		var rarity_color := _get_rarity_color()
		# Delikatne tło + subtelna ramka w kolorze rarity
		var bg := BASE_BG.lerp(rarity_color, 0.08)
		var border := BASE_BORDER.lerp(rarity_color, 0.55)
		_apply_slot_style(bg, border)

func _apply_slot_style(bg: Color, border: Color) -> void:
	var new_style := StyleBoxFlat.new()
	new_style.bg_color = bg
	new_style.border_color = border
	new_style.set_border_width_all(2)
	new_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", new_style)

# Stare funkcje zostawiamy jako cienkie wrappery,
# żeby nic indziej w projekcie się nie wywaliło
func _reset_style() -> void:
	_apply_slot_style(BASE_BG, BASE_BORDER)

func _set_rarity_style() -> void:
	_update_visual()
