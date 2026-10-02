class_name InventorySlot
extends Panel

var item_data: ItemInstance = null

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $CountLabel
@onready var name_label: Label = $Name

signal slot_changed(slot: Panel)

const STAT_DISPLAY := {
	"dmg":    ["Attack Damage", Color(0.95, 0.95, 0.95), preload("uid://pdoitlfackp")],
	"magic":  ["Magic Damage", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"def":    ["Defense", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"vit":    ["Vitality", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"speed":  ["Speed", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"luck":   ["Luck", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"status": ["Status", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"crit":   ["Critical", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
}

const BASE_BG := Color(0.12, 0.12, 0.14, 1.0)
const BASE_BORDER := Color(0.32, 0.32, 0.36, 1.0)

const FONT_TITLE := 28
const FONT_BODY := 20
const TOOLTIP_WIDTH := 700

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

func _make_custom_tooltip(_for_text: String) -> Control:
	if is_empty() or not item_data.definition:
		return null

	var tooltip := preload("uid://d3l2j2u2xebjv").instantiate() as InventoryTooltip
	tooltip.populate(item_data, STAT_DISPLAY)

	tooltip.tree_entered.connect(
		_clear_tooltip_panel_bg.bind(tooltip),
		CONNECT_ONE_SHOT
	)

	return tooltip


## Wspólny renderer właściwości skilla — używany zarówno dla skilla założonego
## na itemie (owning_item_def != null, pokazuje affinity tego itemu), jak i dla
## luźnego skill-itemu w plecaku (owning_item_def == null, bez affinity, bo nie
## wiadomo jeszcze na jaki item trafi).
func _add_skill_properties_box(parent: Control, skill_def: SkillDefinition, owning_item_def: ItemDefinition) -> void:
	var skill_box := VBoxContainer.new()
	skill_box.add_theme_constant_override("separation", 4)
	parent.add_child(skill_box)

	var skill_header := Label.new()
	skill_header.text = "Skill Properties:"
	skill_header.add_theme_color_override("font_color", Color(0.91, 0.75, 0.35))
	skill_header.add_theme_font_size_override("font_size", FONT_BODY)
	skill_box.add_child(skill_header)

	var effect_lbl := Label.new()
	var element_name = GameEnums.DamageElement.keys()[skill_def.damage_element].capitalize()
	var effect_name = GameEnums.SkillEffect.keys()[skill_def.effect_type].capitalize()
	effect_lbl.text = " • Type: %s (%s)" % [effect_name, element_name]
	effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	effect_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	skill_box.add_child(effect_lbl)

	if not skill_def.scalings.is_empty():
		var scaling_title := Label.new()
		scaling_title.text = " • Damage scaling:"
		scaling_title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
		scaling_title.add_theme_font_size_override("font_size", FONT_BODY)
		skill_box.add_child(scaling_title)

		for scaling in skill_def.scalings:
			var stat_key := _get_stat_key_from_enum(scaling.stat)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)

			var indent := Control.new()
			indent.custom_minimum_size = Vector2(16, 0)
			row.add_child(indent)

			if STAT_DISPLAY.has(stat_key):
				var stat_info = STAT_DISPLAY[stat_key]

				if stat_info.size() > 2 and stat_info[2]:
					var s_icon := TextureRect.new()
					s_icon.texture = stat_info[2]
					s_icon.custom_minimum_size = Vector2(16, 16)
					s_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					s_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					s_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					row.add_child(s_icon)

				var scaling_lbl := Label.new()
				scaling_lbl.text = "%s x%.2f" % [stat_info[0], scaling.weight]
				scaling_lbl.add_theme_color_override("font_color", stat_info[1])
				scaling_lbl.add_theme_font_size_override("font_size", FONT_BODY)
				row.add_child(scaling_lbl)
			else:
				var scaling_lbl := Label.new()
				var fallback_name = GameEnums.Stat.keys()[scaling.stat].capitalize()
				scaling_lbl.text = "%s x%.2f" % [fallback_name, scaling.weight]
				scaling_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
				scaling_lbl.add_theme_font_size_override("font_size", FONT_BODY)
				row.add_child(scaling_lbl)

			skill_box.add_child(row)

	if skill_def.bonus_hits_per_stat:
		var bonus = skill_def.bonus_hits_per_stat
		var bonus_stat_key = _get_stat_key_from_enum(bonus.stat)
		var stat_name = STAT_DISPLAY[bonus_stat_key][0] if STAT_DISPLAY.has(bonus_stat_key) else GameEnums.Stat.keys()[bonus.stat].capitalize()

		var bonus_lbl := Label.new()
		bonus_lbl.text = " • Bonus Hits: +1 hit per %.1f %s" % [bonus.weight, stat_name]
		bonus_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		bonus_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		skill_box.add_child(bonus_lbl)

	if owning_item_def != null \
			and skill_def.effect_type == GameEnums.SkillEffect.DAMAGE \
			and skill_def.damage_element != GameEnums.DamageElement.PHYSICAL \
			and skill_def.damage_element != GameEnums.DamageElement.NONE:
		var element_name_aff = GameEnums.DamageElement.keys()[skill_def.damage_element].capitalize()
		var affinity_mult: float = owning_item_def.get_affinity_multiplier(skill_def.damage_element)

		var aff_lbl := Label.new()
		if affinity_mult != 1.0:
			aff_lbl.text = " • %s Affinity: x%.2f" % [element_name_aff, affinity_mult]
			aff_lbl.add_theme_color_override("font_color", Color(0.95, 0.6, 0.3))
		else:
			aff_lbl.text = " • %s Affinity: none on this item" % element_name_aff
			aff_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		aff_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		skill_box.add_child(aff_lbl)

	parent.add_child(_make_separator())


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

			if value == 0 or value == 0.0:
				continue

			var info = STAT_DISPLAY[property]
			var value_str := "%d" % int(round(value))

			var icon_texture: Texture2D = null
			if info.size() > 2:
				icon_texture = info[2]

			rows.append({
				"value": value_str,
				"label": info[0],
				"color": info[1],
				"icon": icon_texture,
			})
	return rows


func _get_rarity_color() -> Color:
	if is_empty() or not item_data.definition:
		return Color.WHITE
	return GameEnums.get_rarity_color(item_data.definition.rarity)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_empty():
		return null

	var total_count: int = item_data.quantity
	var drag_count: int = total_count

	if Input.is_key_pressed(KEY_SHIFT) and total_count > 1:
		drag_count = 1
	elif Input.is_key_pressed(KEY_CTRL) and total_count > 1:
		drag_count = int(total_count / 2.0)

	var drag_instance = ItemInstance.new(item_data.definition, drag_count, item_data.dice_level)

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
	
	if not is_empty() and dragged_instance.definition is SkillItemDefinition and item_data.definition is ItemDefinition:
		_assign_skill_to_item(dragged_instance.definition.skill, source_slot)
		return

	if not self.is_empty() and dragged_instance.definition is MaterialDefinition and dragged_instance.definition.category == InventoryEntry.Category.UPGRADE_STONE:
		if not item_data.definition is ItemDefinition:
			return

		var try_upgrade = self.item_data.attempt_upgrade(dragged_instance.definition)
		match try_upgrade:
			ItemInstance.UpgradeResult.SUCCESS:
				FloatingTextManager.spawn_screen("Level Up!", global_position + (size / 2), Color.GREEN)
				source_slot.item_data.quantity -= 1
				if source_slot.item_data.quantity <= 0:
					source_slot.clear()

				source_slot._update_visual()
				_update_visual()

			ItemInstance.UpgradeResult.WRONG_DIE:
				FloatingTextManager.spawn_screen("Wrong Die", global_position + (size / 2))
				Log.print("wrong die")

			ItemInstance.UpgradeResult.MAX_LEVEL_REACHED:
				FloatingTextManager.spawn_screen("Max Level Reached", global_position + (size / 2))
				Log.print("max level")
			

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
	
func _assign_skill_to_item(skill: SkillDefinition, source_slot: Panel) -> void:
	var existing: SkillDefinition = item_data.equipped_skill

	if existing == null:
		_confirm_skill_assignment(skill, source_slot)
		return

	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Nadpisać \"%s\" skillem \"%s\"?" % [existing.skill_name, skill.skill_name]
	confirm.confirmed.connect(func():
		_confirm_skill_assignment(skill, source_slot)
		confirm.queue_free()
	)
	confirm.canceled.connect(confirm.queue_free)
	get_tree().root.add_child(confirm)
	confirm.popup_centered()


func _confirm_skill_assignment(skill: SkillDefinition, source_slot: Panel) -> void:
	item_data.equipped_skill = skill
	_update_visual()

	source_slot.item_data.quantity -= 1
	if source_slot.item_data.quantity <= 0:
		source_slot.clear()
	else:
		source_slot._update_visual()
	source_slot.slot_changed.emit(source_slot)

func set_item(new_instance: ItemInstance) -> void:
	item_data = new_instance
	_update_visual()

func clear() -> void:
	item_data = null
	_update_visual()

func is_empty() -> bool:
	return item_data == null

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
		name_label.text = str(item_data.definition.name) if item_data.definition.name else ""

		var rarity_color := _get_rarity_color()
		_apply_slot_style(BASE_BG.lerp(rarity_color, 0.08), BASE_BORDER.lerp(rarity_color, 0.55))

func _apply_slot_style(bg: Color, border: Color) -> void:
	var new_style := StyleBoxFlat.new()
	new_style.bg_color = bg
	new_style.border_color = border
	new_style.set_border_width_all(2)
	new_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", new_style)

func _get_stat_key_from_enum(stat_enum: GameEnums.Stat) -> String:
	var enum_name: String = GameEnums.Stat.keys()[stat_enum].to_lower()
	
	match enum_name:
		"vitality": return "vit"
		"defense": return "def"
		"damage": return "dmg"
		_: return enum_name
