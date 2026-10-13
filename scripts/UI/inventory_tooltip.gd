class_name InventoryTooltip
extends PanelContainer

const TOOLTIP_WIDTH := 700
const FONT_TITLE := 28
const FONT_BODY := 20

const BASE_BG := Color(0.111, 0.127, 0.157, 0.96)

const COLOR_HEADER := Color(0.91, 0.75, 0.35)
const COLOR_BODY_TEXT := Color(0.85, 0.85, 0.85)

const SECTION_HEADER := preload("uid://uc7tppxatbwg")
const STAT_ROW := preload("uid://ci7hkfppg4w4g")
const SCALING_ROW := preload("uid://co0dtgcq6880d")
const DESCRIPTION_BLOCK := preload("uid://dobwsnlvgyey1")
const SKILL_HEADER := preload("uid://ypktilcmco1t")

@onready var root: VBoxContainer = %Root
@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %Name
@onready var category_label: Label = %Category

@onready var stats_separator: ColorRect = %StatsSeparator
@onready var stats_box: VBoxContainer = %Stats

@onready var affinities_separator: ColorRect = %AffinitiesSeparator
@onready var affinities_box: VBoxContainer = %Affinities

@onready var skill_box: VBoxContainer = %Skill
@onready var description_box: VBoxContainer = %Description

var _cached_item_data: ItemInstance
var _cached_stat_display: Dictionary
var slot_name: String


func _ready() -> void:
	custom_minimum_size.x = TOOLTIP_WIDTH
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_force_shrink(root)
	_force_shrink(stats_box)
	_force_shrink(affinities_box)
	_force_shrink(skill_box)
	_force_shrink(description_box)

	_clear()

	if _cached_item_data != null:
		_render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		if _cached_item_data != null:
			_render()


func populate(item_data: ItemInstance, stat_display: Dictionary) -> void:
	_cached_item_data = item_data
	_cached_stat_display = stat_display

	if is_node_ready():
		_render()


func _force_shrink(node: Control) -> void:
	if node == null:
		return
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _render() -> void:
	_clear()

	var item_data := _cached_item_data
	var stat_display := _cached_stat_display

	if item_data == null or not item_data.definition:
		return

	var def = item_data.definition
	var rarity_color: Color = GameEnums.get_rarity_color(def.rarity)

	var style := StyleBoxFlat.new()
	style.bg_color = BASE_BG
	style.border_color = Color(rarity_color, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	icon.visible = def.icon != null
	icon.texture = def.icon

	name_label.text = tr(def.name)
	name_label.add_theme_color_override("font_color", Color(0.91, 0.84, 0.58))

	var cat_text = GameEnums.get_rarity_name(def.rarity)

	if def is ItemDefinition:
		slot_name = EquipmentSlot.Type.keys()[def.slot].capitalize()
		cat_text += "  •  " + tr(slot_name)

	var dice_size: int = 0
	if item_data.definition is ItemDefinition and item_data.dice_level >= 0:
		dice_size = GameEnums.DICE_PROGRESSION[item_data.dice_level]
		cat_text += "  •  d%d" % dice_size

	category_label.text = cat_text
	category_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.42))

	if not def.description.is_empty():
		_build_description_blocks(tr(def.description), description_box)
		description_box.visible = true
		if description_box.get_parent() == root:
			root.move_child(description_box, mini(1, root.get_child_count() - 1))

	for property in stat_display.keys():
		if property not in def:
			continue

		var value = def.get(property)
		if value == 0 or value == 0.0:
			continue

		var info = stat_display[property]
		var stat_icon_tex: Texture2D = info[2] if info.size() > 2 else null

		var row := STAT_ROW.instantiate()
		stats_box.add_child(row)
		row.setup(stat_icon_tex, value, info[0], info[1])

	var has_stats := stats_box.get_child_count() > 0
	stats_box.visible = has_stats
	stats_separator.visible = has_stats

	if item_data.definition is ItemDefinition:
		var item_def: ItemDefinition = item_data.definition
		if not item_def.affinities.is_empty():
			var aff_title := SECTION_HEADER.instantiate()
			affinities_box.add_child(aff_title)
			aff_title.setup("Elemental Affinities:", COLOR_HEADER)

			for affinity in item_def.affinities:
				var element_name = GameEnums.DamageElement.keys()[affinity.element].capitalize()
				affinities_box.add_child(_make_affinity_line(element_name, affinity.multiplier))

	var has_affinities := affinities_box.get_child_count() > 0
	affinities_box.visible = has_affinities
	affinities_separator.visible = has_affinities

	var processed_skill := false
	if item_data.definition is ItemDefinition and item_data.dice_level >= 0:
		var item_def: ItemDefinition = item_data.definition
		var active_skill: SkillDefinition = item_def.default_skill

		if active_skill:
			_add_skill_properties_box(active_skill, stat_display, dice_size, active_skill.skill_name, false)
			processed_skill = true

	skill_box.visible = skill_box.get_child_count() > 0

	_force_shrink(stats_box)
	_force_shrink(affinities_box)
	_force_shrink(skill_box)
	_force_shrink(description_box)
	reset_size()


func _build_description_blocks(desc_text: String, container: Container) -> void:
	var blocks = desc_text.split("\n\n", false)
	for i in blocks.size():
		var block: String = blocks[i].strip_edges()
		if block.is_empty():
			continue

		var lines := block.split("\n", false)
		var desc_instance := DESCRIPTION_BLOCK.instantiate()
		container.add_child(desc_instance)

		if lines.size() >= 2:
			var body_text := "\n".join(lines.slice(1))
			desc_instance.setup(lines[0], _colorize_numbers(body_text))
		else:
			desc_instance.setup("", _colorize_numbers(block))

		if i < blocks.size() - 1:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 4)
			gap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			container.add_child(gap)


func _add_skill_properties_box(skill_def: SkillDefinition, stat_display: Dictionary, dice_size: int = 0, skill_name_to_display: String = "", is_skill_item: bool = false) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	skill_box.add_child(box)

	var effect_name := _get_skill_effect_name(skill_def)
	var subtitle_text := effect_name

	if "damage_element" in skill_def and skill_def.damage_element != GameEnums.DamageElement.NONE:
		var element_name = GameEnums.DamageElement.keys()[skill_def.damage_element].capitalize()
		var element_color = _get_element_color(element_name)
		subtitle_text += "  •  [color=#%s]%s[/color]" % [element_color.to_html(false), element_name]

	var skill_icon: Texture2D = skill_def.icon if ("icon" in skill_def and skill_def.icon) else null

	var header := SKILL_HEADER.instantiate()
	box.add_child(header)
	header.setup(skill_icon, tr(skill_name_to_display) if not skill_name_to_display.is_empty() else "", subtitle_text)

	if "description" in skill_def and not skill_def.description.is_empty() and not skill_name_to_display.is_empty():
		var s_desc_box := VBoxContainer.new()
		s_desc_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		box.add_child(s_desc_box)
		_build_description_blocks(tr(skill_def.description), s_desc_box)

	# --- Projected value (pomijane dla luźnych skill itemów — brak kontekstu rzutu kością) ---
	if not is_skill_item and not skill_def.scalings.is_empty():
		var projected_range = SkillStatCalculator.calculate_projected_range(skill_def, dice_size, _cached_item_data)
		var proj_lbl := Label.new()

		var action_word := "Value"
		match effect_name.to_lower():
			"damage", "deal_damage", "dmg":
				action_word = "Damage"
			"heal", "healing", "restore_health":
				action_word = "Healing"
			"coin", "coins", "gold", "gain_coins":
				action_word = "Coins"

		proj_lbl.text = "Projected %s: %d - %d" % [action_word, int(round(projected_range.x)), int(round(projected_range.y))]
		proj_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95))
		proj_lbl.theme_type_variation = &"TooltipHeader"
		proj_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		box.add_child(proj_lbl)

	# USUNIĘTE: wyświetlanie nieistniejącego skill_def.base_value

	if not skill_def.scalings.is_empty():
		var scaling_title := SECTION_HEADER.instantiate()
		box.add_child(scaling_title)
		scaling_title.setup("Scales with:", COLOR_BODY_TEXT)

		for scaling in skill_def.scalings:
			var stat_key := SkillStatCalculator.get_stat_key_from_enum(scaling.stat)

			var stat_name: String
			var stat_color: Color
			var stat_icon_tex: Texture2D = null

			if stat_display.has(stat_key):
				var stat_info = stat_display[stat_key]
				stat_name = stat_info[0]
				stat_color = stat_info[1]
				if stat_info.size() > 2 and stat_info[2]:
					stat_icon_tex = stat_info[2]
			else:
				stat_name = GameEnums.Stat.keys()[scaling.stat].capitalize()
				stat_color = Color(0.7, 0.7, 0.7)

			var percentage := int(round(scaling.weight * 100.0))
			var raw_stat := SkillStatCalculator.get_total_stat_value(scaling.stat, _cached_item_data)
			var scaling_contrib := raw_stat * scaling.weight

			var row := SCALING_ROW.instantiate()
			box.add_child(row)
			row.setup(percentage, stat_icon_tex, stat_name, stat_color, raw_stat, scaling_contrib)

		# Wrzucamy wszystkie triggery przypisane do skilla
		var active_triggers: Array[SkillTrigger] = []
		for trigger in skill_def.triggers:
			active_triggers.append(trigger)

		if not active_triggers.is_empty():
			var trig_title := SECTION_HEADER.instantiate()
			box.add_child(trig_title)
			trig_title.setup("Additional Effects:", COLOR_BODY_TEXT)

			for trigger in active_triggers:
				box.add_child(_make_trigger_line(trigger, dice_size, is_skill_item))

	if skill_def.bonus_hits_per_stat:
		var bonus = skill_def.bonus_hits_per_stat
		var bonus_stat_key = SkillStatCalculator.get_stat_key_from_enum(bonus.stat)
		var bonus_stat_name = stat_display[bonus_stat_key][0] if stat_display.has(bonus_stat_key) else GameEnums.Stat.keys()[bonus.stat].capitalize()

		var bonus_lbl := Label.new()
		bonus_lbl.text = "Bonus Hits: +1 hit per %.1f %s" % [bonus.weight, bonus_stat_name]
		bonus_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		bonus_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		box.add_child(bonus_lbl)


func _get_skill_effect_name(skill_def: SkillDefinition) -> String:
	if not skill_def or not "effect_type" in skill_def or skill_def.effect_type == null:
		return "Skill"

	var effect_val = skill_def.effect_type
	var values = GameEnums.SkillEffect.values()
	var idx = values.find(effect_val)

	if idx != -1:
		return GameEnums.SkillEffect.keys()[idx].capitalize()

	return "Skill"


func _make_trigger_line(trigger: SkillTrigger, dice_size: int, is_skill_item: bool) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 32, 0)
	rtl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var condition_text := _get_trigger_condition_text(trigger)
	var parts: Array[String] = []

	# 1. Dodaj opis dla efektu (TriggerEffect) jeśli nie jest to NONE
	if trigger.effect != GameEnums.TriggerEffect.NONE:
		var effect_name = GameEnums.TriggerEffect.keys()[trigger.effect].replace("_", " ").capitalize()
		var val_str := ""
		if trigger.effect_value != 0.0:
			if trigger.effect == GameEnums.TriggerEffect.DAMAGE_MULTIPLIER:
				val_str = " x%.1f" % trigger.effect_value
			else:
				val_str = " %d" % int(round(trigger.effect_value))
		parts.append("[color=#ff8c39]%s%s[/color]" % [effect_name, val_str])

	# 2. Dodaj opis dla nakładanego statusu (StatusType)
	if trigger.apply_status != GameEnums.StatusType.NONE:
		var status_name = GameEnums.StatusType.keys()[trigger.apply_status].capitalize()
		var status_color := _get_status_color(trigger.apply_status)
		var status_text := "[color=#%s]%s[/color]" % [status_color.to_html(false), status_name]

		if trigger.status_stacks > 1:
			status_text += " (x%d)" % trigger.status_stacks

		if not is_skill_item:
			var preview := SkillStatCalculator.calculate_trigger_status_preview(trigger, dice_size, _cached_item_data)
			var value_parts: Array[String] = []
			if preview["tick_max"] > 0.0:
				value_parts.append("%s-%s/turn" % [
					SkillStatCalculator.format_dice_value(preview["tick_min"]),
					SkillStatCalculator.format_dice_value(preview["tick_max"])
				])
			if preview["initial_max"] > 0.0:
				value_parts.append("+%s-%s instant" % [
					SkillStatCalculator.format_dice_value(preview["initial_min"]),
					SkillStatCalculator.format_dice_value(preview["initial_max"])
				])
			if not value_parts.is_empty():
				var scaling_text := _get_status_scaling_text(trigger.apply_status)
				status_text += "  [color=#%s](%s, %d rounds · scales with %s)[/color]" % [
					COLOR_BODY_TEXT.to_html(false), " ".join(value_parts), preview["duration"], scaling_text
				]
		parts.append(status_text)

	var line := ""
	if parts.is_empty():
		line = "%s → None" % condition_text
	else:
		line = "%s → %s" % [condition_text, " & ".join(parts)]

	rtl.text = line
	return rtl


func _get_trigger_condition_text(trigger: SkillTrigger) -> String:
	match trigger.trigger_type:
		GameEnums.TriggerType.ON_HIT:
			return "On Hit"
		GameEnums.TriggerType.ON_ROLL_AT_LEAST:
			return "On Roll At Least %d" % trigger.threshold
		GameEnums.TriggerType.ON_ROLL_AT_MOST:
			return "On Roll At Most %d" % trigger.threshold
		GameEnums.TriggerType.ON_MAX_ROLL:
			return "On Max Roll"
		GameEnums.TriggerType.ON_LOW_ROLL:
			return "On Low Roll (1)"
		GameEnums.TriggerType.ON_KILL:
			return "On Kill"
		GameEnums.TriggerType.ON_TARGET_STATUS:
			return "On Target Status"
		_:
			return "Trigger"


func _get_status_color(status_type: GameEnums.StatusType) -> Color:
	match status_type:
		GameEnums.StatusType.BURN:
			return Color(1.0, 0.45, 0.0)
		GameEnums.StatusType.POISON:
			return Color(0.55, 0.15, 0.85)
		GameEnums.StatusType.BLEED:
			return Color(0.7, 0.0, 0.0)
		_:
			return Color(0.7, 0.7, 0.7)


func _get_status_scaling_text(status_type: GameEnums.StatusType) -> String:
	match status_type:
		GameEnums.StatusType.BURN:
			return "Status"
		GameEnums.StatusType.POISON:
			return "Magic + Status"
		GameEnums.StatusType.BLEED:
			return "DMG"
		_:
			return ""


func _make_affinity_line(element_name: String, multiplier: float) -> RichTextLabel:
	var element_color := _get_element_color(element_name)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 32, 0)
	rtl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if is_equal_approx(multiplier, 1.0):
		rtl.text = "[color=#%s]%s[/color] skills deal normal damage" % [
			element_color.to_html(false), element_name
		]
	else:
		var is_buff := multiplier > 1.0
		var percent := int(round(absf(multiplier - 1.0) * 100.0))
		var percent_color := Color(0.55, 0.9, 0.45) if is_buff else Color(0.95, 0.45, 0.4)
		var direction := "more" if is_buff else "less"
		rtl.text = "[color=#%s]%s[/color] skills are [color=#%s]%d%%[/color] %s effective" % [
			element_color.to_html(false), element_name,
			percent_color.to_html(false), percent, direction
		]

	return rtl


func _get_element_color(element_name: String) -> Color:
	match element_name.to_lower():
		"fire": return Color(0.95, 0.45, 0.25)
		"frost", "ice", "cold": return Color(0.55, 0.85, 0.95)
		"poison": return Color(0.62, 0.86, 0.35)
		"lightning", "electric": return Color(0.95, 0.85, 0.35)
		"physical": return Color(0.8, 0.8, 0.8)
		"magic", "arcane": return Color(0.7, 0.55, 0.95)
		_: return Color(0.7, 0.85, 0.95)


func _clear() -> void:
	icon.texture = null
	name_label.text = ""
	category_label.text = ""

	stats_separator.visible = false
	affinities_separator.visible = false
	stats_box.visible = false
	affinities_box.visible = false
	skill_box.visible = false
	description_box.visible = false

	_clear_children(stats_box)
	_clear_children(affinities_box)
	_clear_children(skill_box)
	_clear_children(description_box)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _colorize_numbers(text: String) -> String:
	var regex := RegEx.new()
	regex.compile(r"(\d+\.?\d*%?)")
	return regex.sub(text, "[color=#ff8c39]$1[/color]", true)
