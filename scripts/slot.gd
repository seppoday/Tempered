# slot.gd
class_name InventorySlot
extends Panel

var item_data: ItemInstance = null

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $CountLabel

signal slot_changed(slot: Panel)

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
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ==========================================
# TOOLTIP
# ==========================================

func _make_custom_tooltip(_for_text: String) -> Control:
	if is_empty() or not item_data.definition:
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

	var name_label = Label.new()
	name_label.text = def.item_name
	name_label.add_theme_color_override("font_color", _get_rarity_color())
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var rarity_label = Label.new()
	rarity_label.text = "[ %s ]" % GameEnums.Rarity.keys()[def.rarity]
	rarity_label.add_theme_color_override("font_color", _get_rarity_color() * 0.8)
	rarity_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(rarity_label)

	var line = ColorRect.new()
	line.custom_minimum_size = Vector2(120, 1)
	line.color = Color(0.3, 0.3, 0.3, 0.5)
	vbox.add_child(line)

	if not def.description.is_empty():
		var desc_label = Label.new()
		desc_label.text = def.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(180, 0)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(desc_label)

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

	return container

func _get_stat_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var def = item_data.definition
	for property in STAT_DISPLAY.keys():
		if property in def:
			var value = def.get(property)
			if value == 0 or value == 0.0:
				continue
			var info = STAT_DISPLAY[property]
			var value_str := ""
			match info[2]:
				"plus_int": value_str = "+%d" % int(value)
				"percent":
					var pct = int(round(value * 100.0)) if value <= 1.0 else int(round(value))
					value_str = "+%d%%" % pct
				"speed": value_str = "%.2f/s" % value
				_: value_str = str(value)
			rows.append({"text": "%s: %s" % [info[0], value_str], "color": info[1]})
	return rows

func _get_rarity_color() -> Color:
	if is_empty() or not item_data.definition:
		return Color.WHITE
	match item_data.definition.rarity:
		GameEnums.Rarity.COMMON: return Color(0.7, 0.7, 0.7)
		GameEnums.Rarity.UNCOMMON: return Color(0.2, 0.8, 0.2)
		GameEnums.Rarity.RARE: return Color(0.2, 0.5, 1.0)
		GameEnums.Rarity.EPIC: return Color(0.7, 0.2, 0.9)
		GameEnums.Rarity.LEGENDARY: return Color(1.0, 0.7, 0.0)
	return Color.WHITE

# ==========================================
# DRAG & DROP
# ==========================================

func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_empty():
		return null

	var total_count: int = item_data.quantity
	var drag_count: int = total_count

	if Input.is_key_pressed(KEY_SHIFT) and total_count > 1:
		drag_count = 1
	elif Input.is_key_pressed(KEY_CTRL) and total_count > 1:
		drag_count = int(total_count / 2.0)

	var drag_instance = ItemInstance.new(item_data.definition, drag_count)

	var preview: TextureRect = TextureRect.new()
	preview.texture = icon.texture
	preview.modulate = Color(1, 1, 1, 0.8)
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if drag_count > 1:
		var p_label = Label.new()
		p_label.text = str(drag_count)
		p_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		preview.add_child(p_label)

	set_drag_preview(preview)

	return {
		"source_slot": self,
		"item_instance": drag_instance,
		"drag_count": drag_count,
		"is_partial": drag_count < total_count
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("source_slot") or not data.has("item_instance"):
		return false
	if data.source_slot == self:
		return false
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_slot: Panel = data["source_slot"]
	var dragged_instance: ItemInstance = data["item_instance"]
	var drag_count: int = data["drag_count"]
	var is_partial: bool = data["is_partial"]

	if is_empty():
		set_item(dragged_instance)
		if is_partial:
			source_slot.item_data.quantity -= drag_count
			source_slot._update_visual()
		else:
			source_slot.clear()
	else:
		var my_def = item_data.definition
		var drag_def = dragged_instance.definition
		var is_stackable = my_def.stackable and drag_def.stackable

		if my_def.id == drag_def.id and is_stackable:
			var room = my_def.max_stack_size - item_data.quantity
			var to_add = min(room, drag_count)
			if to_add > 0:
				item_data.quantity += to_add
				_update_visual()
				if is_partial:
					source_slot.item_data.quantity -= to_add
					source_slot._update_visual()
				else:
					if to_add == drag_count:
						source_slot.clear()
					else:
						source_slot.item_data.quantity = drag_count - to_add
						source_slot._update_visual()
		else:
			if is_partial:
				return
			var temp_instance := item_data
			set_item(dragged_instance)
			source_slot.set_item(temp_instance)

	slot_changed.emit(self)
	source_slot.slot_changed.emit(source_slot)

# ==========================================
# PUBLIC API
# ==========================================

func set_item(new_instance: ItemInstance) -> void:
	item_data = new_instance
	_update_visual()

func clear() -> void:
	item_data = null
	_update_visual()

func is_empty() -> bool:
	return item_data == null

# ==========================================
# VISUAL
# ==========================================

const BASE_BG := Color(0.12, 0.12, 0.14, 1.0)
const BASE_BORDER := Color(0.32, 0.32, 0.36, 1.0)

func _update_visual() -> void:
	modulate = Color.WHITE

	if is_empty() or not item_data.definition:
		tooltip_text = ""
		icon.texture = null
		icon.visible = false
		count_label.text = ""
		_apply_slot_style(BASE_BG, BASE_BORDER)
	else:
		tooltip_text = "use_custom"
		var def = item_data.definition
		icon.texture = def.icon
		icon.visible = icon.texture != null
		count_label.text = str(item_data.quantity) if item_data.quantity > 1 else ""

		var rarity_color := _get_rarity_color()
		_apply_slot_style(BASE_BG.lerp(rarity_color, 0.08), BASE_BORDER.lerp(rarity_color, 0.55))

func _apply_slot_style(bg: Color, border: Color) -> void:
	var new_style := StyleBoxFlat.new()
	new_style.bg_color = bg
	new_style.border_color = border
	new_style.set_border_width_all(2)
	new_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", new_style)