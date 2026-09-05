# slot.gd
class_name InventorySlot
extends Panel

var item_data: ItemInstance = null

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $CountLabel
@onready var name_label: Label = $Name

signal slot_changed(slot: Panel)

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

const BASE_BG := Color(0.12, 0.12, 0.14, 1.0)
const BASE_BORDER := Color(0.32, 0.32, 0.36, 1.0)

func _ready() -> void:
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	var is_double_click_lmb = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click
	if not is_double_click_lmb:
		return

	if is_empty() or item_data.definition.category != InventoryEntry.Category.CONSUMABLE:
		return

	item_data.use()
	item_data.quantity -= 1

	if item_data.quantity <= 0:
		clear()
	else:
		_update_visual()

	slot_changed.emit(self)

# ==========================================
# TOOLTIP
# ==========================================
const FONT_TITLE := 18
const FONT_BODY := 12

func _make_custom_tooltip(_for_text: String) -> Control:
	if is_empty() or not item_data.definition:
		return null

	var def = item_data.definition
	var rarity_color := _get_rarity_color()

	# ── Root ──────────────────────────────────────────────
	var container := PanelContainer.new()
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

	# Usuń domyślne tło TooltipPanel
	container.tree_entered.connect(_clear_tooltip_panel_bg.bind(container), CONNECT_ONE_SHOT)

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
		icon_rect.custom_minimum_size = Vector2(22, 22) # multiple bazy fontu
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		header.add_child(icon_rect)

	# Nazwa + kategoria
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)

	var name_label := Label.new()
	if item_data.upgrade_level > 0:
		name_label.text = "%.2f %s" % [item_data.upgrade_level, def.name]
	else:
		name_label.text = def.name
	name_label.add_theme_color_override("font_color", Color(0.91, 0.84, 0.58)) # LoL gold
	name_label.add_theme_font_size_override("font_size", FONT_TITLE)
	title_box.add_child(name_label)

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


func _clear_tooltip_panel_bg(tooltip_content: Control) -> void:
	var parent := tooltip_content.get_parent()
	if parent == null:
		return
	parent.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


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
	var def = item_data.definition
	for property in STAT_DISPLAY.keys():
		if property in def:
			var value = def.get(property)

			if item_data.upgrade_level > 0 and def.upgrade_curve != null:
				var levels = def.upgrade_curve.levels
				if item_data.upgrade_level <= levels.size():
					var upgrade: ItemUpgradeLevel = levels[item_data.upgrade_level - 1]
					if upgrade.stat_name == property:
						var base_value: float = def.get(property)
						var bonus: float = base_value * upgrade.bonus_percent
						value += bonus

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
	if is_empty() or not item_data.definition:
		return Color.WHITE
	return GameEnums.get_rarity_color(item_data.definition.rarity)

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

	if not is_empty() and dragged_instance.definition.category == InventoryEntry.Category.UPGRADE_STONE:
		if item_data.definition is ItemDefinition and item_data.definition.upgrade_curve != null:
			var upgrade_result: ItemInstance.UpgradeResult = item_data.attempt_upgrade()

			if upgrade_result == ItemInstance.UpgradeResult.SUCCESS or upgrade_result == ItemInstance.UpgradeResult.FAILURE:
				source_slot.item_data.quantity -= 1
				if source_slot.item_data.quantity <= 0:
					source_slot.clear()
				else:
					source_slot._update_visual()
				_update_visual()

			slot_changed.emit(self)
			source_slot.slot_changed.emit(source_slot)

		return

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
		var is_stackable = item_data.is_stackable() and dragged_instance.is_stackable()

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

func _update_visual() -> void:
	modulate = Color.WHITE

	if is_empty() or not item_data.definition:
		tooltip_text = ""
		icon.texture = null
		icon.visible = false
		count_label.text = ""
		name_label.text = ""
		_apply_slot_style(BASE_BG, BASE_BORDER)
	else:
		tooltip_text = "use_custom"
		var def = item_data.definition
		icon.texture = def.icon
		icon.visible = icon.texture != null
		count_label.text = str(item_data.quantity) if item_data.quantity >= 1 else ""
		name_label.text = str(item_data.definition.name) if item_data.definition.name  else ""

		var rarity_color := _get_rarity_color()
		_apply_slot_style(BASE_BG.lerp(rarity_color, 0.08), BASE_BORDER.lerp(rarity_color, 0.55))

func _apply_slot_style(bg: Color, border: Color) -> void:
	var new_style := StyleBoxFlat.new()
	new_style.bg_color = bg
	new_style.border_color = border
	new_style.set_border_width_all(2)
	new_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", new_style)
