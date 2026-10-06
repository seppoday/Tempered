class_name InventoryTooltip
extends PanelContainer

const TOOLTIP_WIDTH := 700
const FONT_TITLE := 28
const FONT_BODY := 20

const BASE_BG := Color(0.111, 0.127, 0.157, 0.96)

const COLOR_HEADER := Color(0.91, 0.75, 0.35)
const COLOR_BODY_TEXT := Color(0.85, 0.85, 0.85)

@export var font_normal: Font
@export var font_bold: Font

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

	# Panel style
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

	# --- Header (Top) ---
	icon.visible = def.icon != null
	icon.texture = def.icon

	name_label.text = tr(def.name)
	name_label.add_theme_color_override("font_color", Color(0.91, 0.84, 0.58))
	name_label.add_theme_font_size_override("font_size", FONT_TITLE)

	# Prawy górny róg: Common • Weapon • d6
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
	category_label.add_theme_font_size_override("font_size", FONT_BODY)

	# --- Item Description ---
	if not def.description.is_empty():
		_build_description_blocks(tr(def.description), description_box)
		description_box.visible = true
		if description_box.get_parent() == root:
			root.move_child(description_box, mini(1, root.get_child_count() - 1))

	# --- Stats ---
	for property in stat_display.keys():
		if property not in def:
			continue

		var value = def.get(property)
		if value == 0 or value == 0.0:
			continue

		var info = stat_display[property]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		stats_box.add_child(row)

		if info.size() > 2 and info[2]:
			var stat_icon := TextureRect.new()
			stat_icon.texture = info[2]
			stat_icon.custom_minimum_size = Vector2(24, 24)
			stat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			stat_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			stat_icon.modulate = Color.ALICE_BLUE
			stat_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(stat_icon)

		var value_lbl := Label.new()
		value_lbl.text = "%d" % int(round(value))
		value_lbl.add_theme_color_override("font_color", info[1].lightened(0.4))
		value_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		value_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(value_lbl)

		var label_lbl := Label.new()
		label_lbl.text = info[0]
		label_lbl.add_theme_color_override("font_color", info[1].darkened(0.35))
		label_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		label_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label_lbl)

	var has_stats := stats_box.get_child_count() > 0
	stats_box.visible = has_stats
	stats_separator.visible = has_stats

	# --- Affinities ---
	if item_data.definition is ItemDefinition:
		var item_def: ItemDefinition = item_data.definition
		if not item_def.affinities.is_empty():
			var aff_title := Label.new()
			aff_title.text = "Elemental Affinities:"
			aff_title.add_theme_color_override("font_color", COLOR_HEADER)
			aff_title.add_theme_font_size_override("font_size", FONT_BODY)
			aff_title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			_apply_font(aff_title, true)
			affinities_box.add_child(aff_title)

			for affinity in item_def.affinities:
				var element_name = GameEnums.DamageElement.keys()[affinity.element].capitalize()
				affinities_box.add_child(_make_affinity_line(element_name, affinity.multiplier))

	var has_affinities := affinities_box.get_child_count() > 0
	affinities_box.visible = has_affinities
	affinities_separator.visible = has_affinities

	# --- Skill ---
	var processed_skill := false
	if item_data.definition is ItemDefinition and item_data.dice_level >= 0:
		var item_def: ItemDefinition = item_data.definition
		var active_skill: SkillDefinition = item_data.equipped_skill if item_data.equipped_skill else item_def.default_skill

		if active_skill:
			_add_skill_properties_box(active_skill, stat_display, dice_size, active_skill.skill_name)
			processed_skill = true

	if not processed_skill and def is SkillItemDefinition:
		var loose_skill_def: SkillDefinition = def.skill
		if loose_skill_def:
			_add_skill_properties_box(loose_skill_def, stat_display, 0, "")

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
		var passive_box := VBoxContainer.new()
		passive_box.add_theme_constant_override("separation", 2)
		passive_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		container.add_child(passive_box)

		if lines.size() >= 2:
			var p_title := Label.new()
			p_title.text = lines[0]
			p_title.add_theme_color_override("font_color", Color(0.91, 0.75, 0.35))
			p_title.add_theme_font_size_override("font_size", FONT_BODY)
			p_title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			passive_box.add_child(p_title)

			var p_desc := _make_description_label("\n".join(lines.slice(1)))
			passive_box.add_child(p_desc)
		else:
			passive_box.add_child(_make_description_label(block))

		if i < blocks.size() - 1:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 4)
			gap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			container.add_child(gap)


func _make_description_label(text: String) -> RichTextLabel:
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 32, 0)
	desc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_color_override("default_color", Color(0.72, 0.72, 0.70))
	desc.add_theme_font_size_override("normal_font_size", FONT_BODY)
	desc.text = _colorize_numbers(text)
	return desc


func _add_skill_properties_box(skill_def: SkillDefinition, stat_display: Dictionary, dice_size: int = 0, skill_name_to_display: String = "") -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	skill_box.add_child(box)

	# --- 1. Nagłówek ---
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	header_hbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(header_hbox)

	if not skill_name_to_display.is_empty():
		if "icon" in skill_def and skill_def.icon:
			var s_icon := TextureRect.new()
			s_icon.texture = skill_def.icon
			s_icon.custom_minimum_size = Vector2(28, 28)
			s_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			s_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			s_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			header_hbox.add_child(s_icon)

		var s_name := Label.new()
		s_name.text = tr(skill_name_to_display)
		s_name.add_theme_color_override("font_color", COLOR_HEADER)
		s_name.add_theme_font_size_override("font_size", FONT_TITLE - 4)
		s_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_apply_font(s_name, true)
		header_hbox.add_child(s_name)

	var effect_name := _get_skill_effect_name(skill_def)

	var subtitle_rtl := RichTextLabel.new()
	subtitle_rtl.bbcode_enabled = true
	subtitle_rtl.fit_content = true
	subtitle_rtl.scroll_active = false
	subtitle_rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle_rtl.size_flags_horizontal = Control.SIZE_SHRINK_END
	subtitle_rtl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	subtitle_rtl.add_theme_font_size_override("normal_font_size", FONT_BODY)
	subtitle_rtl.add_theme_color_override("default_color", Color(0.55, 0.52, 0.42))

	var subtitle_text := effect_name
	if "damage_element" in skill_def and skill_def.damage_element != GameEnums.DamageElement.NONE:
		var element_name = GameEnums.DamageElement.keys()[skill_def.damage_element].capitalize()
		var element_color = _get_element_color(element_name)
		subtitle_text += "  •  [color=#%s]%s[/color]" % [element_color.to_html(false), element_name]

	subtitle_rtl.text = subtitle_text
	header_hbox.add_child(subtitle_rtl)

	# --- 2. Opis skilla ---
	if "description" in skill_def and not skill_def.description.is_empty() and not skill_name_to_display.is_empty():
		var s_desc_box := VBoxContainer.new()
		s_desc_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		box.add_child(s_desc_box)
		_build_description_blocks(tr(skill_def.description), s_desc_box)

	# --- 3. Projected value ---
	if skill_def.base_value != 0.0:
		var projected_range = _calculate_projected_range(skill_def, dice_size)
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
		proj_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		proj_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_apply_font(proj_lbl, true)
		box.add_child(proj_lbl)

	# --- 4. Base value ---
	if skill_def.base_value != 0.0:
		var base_lbl := Label.new()
		base_lbl.text = _format_base_value_text(skill_def.base_value, dice_size)
		base_lbl.add_theme_color_override("font_color", COLOR_BODY_TEXT)
		base_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		base_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		box.add_child(base_lbl)

	# --- 5. Scales with ---
	if not skill_def.scalings.is_empty():
		var scaling_title := Label.new()
		scaling_title.text = "Scales with:"
		scaling_title.add_theme_color_override("font_color", COLOR_BODY_TEXT)
		scaling_title.add_theme_font_size_override("font_size", FONT_BODY)
		scaling_title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_apply_font(scaling_title, true)
		box.add_child(scaling_title)

		for scaling in skill_def.scalings:
			var stat_key := _get_stat_key_from_enum(scaling.stat)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			box.add_child(row)

			var indent := Control.new()
			indent.custom_minimum_size = Vector2(16, 0)
			indent.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(indent)

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
			var raw_stat := _get_total_stat_value(scaling.stat)
			var scaling_contrib := raw_stat * scaling.weight

			var prefix_lbl := Label.new()
			prefix_lbl.text = "+%d%% of" % percentage
			prefix_lbl.add_theme_color_override("font_color", COLOR_BODY_TEXT)
			prefix_lbl.add_theme_font_size_override("font_size", FONT_BODY)
			prefix_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(prefix_lbl)

			if stat_icon_tex:
				var s_icon := TextureRect.new()
				s_icon.texture = stat_icon_tex
				s_icon.custom_minimum_size = Vector2(18, 18)
				s_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				s_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				s_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				s_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(s_icon)

			var suffix_lbl := Label.new()
			if raw_stat > 0:
				var contrib_str := ""
				if is_equal_approx(scaling_contrib, round(scaling_contrib)):
					contrib_str = "x%d" % int(round(scaling_contrib))
				else:
					contrib_str = "x%.1f" % scaling_contrib
				suffix_lbl.text = "%s (%s)" % [stat_name, contrib_str]
			else:
				suffix_lbl.text = stat_name

			suffix_lbl.add_theme_color_override("font_color", stat_color)
			suffix_lbl.add_theme_font_size_override("font_size", FONT_BODY)
			suffix_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(suffix_lbl)

	if skill_def.bonus_hits_per_stat:
		var bonus = skill_def.bonus_hits_per_stat
		var bonus_stat_key = _get_stat_key_from_enum(bonus.stat)
		var bonus_stat_name = stat_display[bonus_stat_key][0] if stat_display.has(bonus_stat_key) else GameEnums.Stat.keys()[bonus.stat].capitalize()

		var bonus_lbl := Label.new()
		bonus_lbl.text = "Bonus Hits: +1 hit per %.1f %s" % [bonus.weight, bonus_stat_name]
		bonus_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		bonus_lbl.add_theme_font_size_override("font_size", FONT_BODY)
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


# Sprawdza czy dany przedmiot jest założony u gracza
func _is_item_equipped(item_instance: ItemInstance) -> bool:
	if item_instance == null:
		return false

	if "is_equipped" in item_instance and bool(item_instance.is_equipped):
		return true
	if "equipped" in item_instance and bool(item_instance.equipped):
		return true
	if item_instance.has_method("is_equipped") and item_instance.is_equipped():
		return true

	var player_data = get_node_or_null("/root/PlayerData")
	if player_data:
		if player_data.has_method("is_item_equipped") and player_data.is_item_equipped(item_instance):
			return true

		for field in ["equipment", "equipped_items", "equipment_slots", "slots", "gear"]:
			if field in player_data:
				var container = player_data.get(field)
				if container is Array and item_instance in container:
					return true
				elif container is Dictionary:
					for val in container.values():
						if val == item_instance:
							return true
						if val != null and typeof(val) == TYPE_OBJECT:
							if "item" in val and val.item == item_instance:
								return true
							if "item_instance" in val and val.item_instance == item_instance:
								return true

	return false


# Zwraca przedmiot obecnie założony w slocie, do którego pasuje dany slot
func _get_equipped_item_in_slot(slot) -> ItemInstance:
	var player_data = get_node_or_null("/root/PlayerData")
	if not player_data or slot == null:
		return null

	if player_data.has_method("get_equipped_item"):
		return player_data.get_equipped_item(slot)

	for field_name in ["equipment", "equipped_items", "equipment_slots", "slots", "gear"]:
		if field_name in player_data:
			var container = player_data.get(field_name)
			if container is Dictionary and container.has(slot):
				var val = container[slot]
				if val is ItemInstance:
					return val
				elif val != null and typeof(val) == TYPE_OBJECT:
					if "item" in val and val.item is ItemInstance:
						return val.item
					if "item_instance" in val and val.item_instance is ItemInstance:
						return val.item_instance
	return null


# Pobiera statystykę bezpośrednio z obudowanego przedmiotu lub jego definicji
func _get_item_stat(item, stat_enum: GameEnums.Stat) -> float:
	if item == null:
		return 0.0

	var def = item.definition if ("definition" in item and item.definition) else item
	if def == null:
		return 0.0

	var stat_key := _get_stat_key_from_enum(stat_enum)
	if stat_key in def:
		return float(def.get(stat_key))

	var full_stat_key = GameEnums.Stat.keys()[stat_enum].to_lower()
	if full_stat_key in def:
		return float(def.get(full_stat_key))

	return 0.0


func _get_player_stat_from_dict(stats: Dictionary, stat_enum: GameEnums.Stat) -> float:
	var full_key = GameEnums.Stat.keys()[stat_enum].to_lower()
	if stats.has(full_key):
		return float(stats[full_key])

	var short_key := _get_stat_key_from_enum(stat_enum)
	if stats.has(short_key):
		return float(stats[short_key])

	return 0.0


# Główna funkcja wyliczająca całkowitą statystykę z uwzględnieniem podmieniania przedmiotu
func _get_total_stat_value(stat_enum: GameEnums.Stat) -> float:
	var player_data = get_node_or_null("/root/PlayerData")
	var current_total_stats := 0.0

	if player_data:
		var player_stats: Dictionary = {}
		if player_data.has_method("get_total_stats"):
			player_stats = player_data.get_total_stats()
		elif "totals" in player_data and player_data.totals is Dictionary:
			player_stats = player_data.totals

		current_total_stats = _get_player_stat_from_dict(player_stats, stat_enum)

	# 1. Jeśli ten przedmiot JEST już założony, current_total_stats jest ostatecznym wynikiem
	if _is_item_equipped(_cached_item_data):
		return current_total_stats

	# 2. Jeśli przedmiot NIE JEST założony, symulujemy jego założenie:
	# Odejmujemy statystykę przedmiotu obecnie założonego w tym slocie (jeśli taki istnieje)
	var replaced_item_stat := 0.0
	if _cached_item_data and _cached_item_data.definition and "slot" in _cached_item_data.definition:
		var target_slot = _cached_item_data.definition.slot
		var currently_equipped_item = _get_equipped_item_in_slot(target_slot)
		if currently_equipped_item and currently_equipped_item != _cached_item_data:
			replaced_item_stat = _get_item_stat(currently_equipped_item, stat_enum)

	# Dodajemy statystykę nowego przedmiotu z plecaka
	var new_item_stat := _get_item_stat(_cached_item_data, stat_enum)

	return current_total_stats - replaced_item_stat + new_item_stat


func _calculate_projected_range(skill_def: SkillDefinition, dice_size: int) -> Vector2:
	var min_roll := 1.0
	var max_roll := float(dice_size) if dice_size > 0 else 1.0

	var stat_scaling: float = 0.0
	if skill_def.scalings.is_empty():
		stat_scaling = 1.0
	else:
		for scaling in skill_def.scalings:
			stat_scaling += _get_total_stat_value(scaling.stat) * scaling.weight

	var affinity_mult := 1.0
	if _cached_item_data and _cached_item_data.definition:
		if _cached_item_data.definition.has_method("get_affinity_multiplier"):
			affinity_mult = _cached_item_data.definition.get_affinity_multiplier(skill_def.damage_element)
		elif "affinities" in _cached_item_data.definition:
			for aff in _cached_item_data.definition.affinities:
				if aff.element == skill_def.damage_element:
					affinity_mult = aff.multiplier
					break

	var total_hits := 1
	if skill_def.bonus_hits_per_stat:
		var bonus_stat_val = _get_total_stat_value(skill_def.bonus_hits_per_stat.stat)
		var bonus_hits = int(floor(bonus_stat_val * skill_def.bonus_hits_per_stat.weight))
		total_hits += bonus_hits

	var min_outcome = skill_def.base_value * min_roll * stat_scaling * affinity_mult * total_hits
	var max_outcome = skill_def.base_value * max_roll * stat_scaling * affinity_mult * total_hits

	return Vector2(min_outcome, max_outcome)


func _format_base_value_text(base_value: float, dice_size: int) -> String:
	var percent := int(round(base_value * 100.0))

	if dice_size <= 0:
		return "Base value: %d%% of dice roll" % percent

	var min_value := base_value * 1.0
	var max_value := base_value * float(dice_size)

	return "Base value: %s-%s (%d%% of dice roll)" % [
		_format_dice_value(min_value), _format_dice_value(max_value), percent
	]


func _format_dice_value(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(round(value))
	return "%.1f" % value


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
	rtl.add_theme_font_size_override("normal_font_size", FONT_BODY)

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


func _apply_font(control: Control, bold: bool = false) -> void:
	if control is RichTextLabel:
		if bold and font_bold:
			control.add_theme_font_override("bold_font", font_bold)
		elif not bold and font_normal:
			control.add_theme_font_override("normal_font", font_normal)
	elif control is Label:
		var font := font_bold if bold else font_normal
		if font:
			control.add_theme_font_override("font", font)


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


func _get_stat_key_from_enum(stat_enum: GameEnums.Stat) -> String:
	var enum_name: String = GameEnums.Stat.keys()[stat_enum].to_lower()

	match enum_name:
		"vitality": return "vit"
		"defense": return "def"
		"damage": return "dmg"
		_: return enum_name
