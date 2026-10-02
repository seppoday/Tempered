class_name InventoryTooltip
extends PanelContainer

const TOOLTIP_WIDTH := 700
const FONT_TITLE := 28
const FONT_BODY := 20

const BASE_BG := Color(0.111, 0.127, 0.157, 0.96)

@onready var root: VBoxContainer = %Root
@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %Name
@onready var category_label: Label = %Category
@onready var price_box: VBoxContainer = %PriceBox
@onready var price_label: Label = %Price

@onready var stats_separator: ColorRect = %StatsSeparator
@onready var stats_box: VBoxContainer = %Stats

@onready var affinities_separator: ColorRect = %AffinitiesSeparator
@onready var affinities_box: VBoxContainer = %Affinities

@onready var skill_box: VBoxContainer = %Skill
@onready var description_box: VBoxContainer = %Description

# Zmienne przechowujące dane przed wejściem do drzewa
var _cached_item_data: ItemInstance
var _cached_stat_display: Dictionary
var slot_name: String

func _ready() -> void:
	custom_minimum_size.x = TOOLTIP_WIDTH
	_clear()
	
	# Jeśli dane zostały ustawione przed _ready, generujemy UI teraz
	if _cached_item_data != null:
		_render()


func populate(item_data: ItemInstance, stat_display: Dictionary) -> void:
	_cached_item_data = item_data
	_cached_stat_display = stat_display

	# Jeśli węzeł jest już w drzewie, od razu renderujemy
	if is_node_ready():
		_render()


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

	# Header
	icon.visible = def.icon != null
	icon.texture = def.icon

	if item_data.definition is ItemDefinition and item_data.dice_level >= 0:
		var dice_size := GameEnums.DICE_PROGRESSION[item_data.dice_level]
		name_label.text = "%s (d%d)" % [def.name, dice_size]
	else:
		name_label.text = def.name

	name_label.add_theme_color_override("font_color", Color(0.91, 0.84, 0.58))
	name_label.add_theme_font_size_override("font_size", FONT_TITLE)
	
	var category_name: String = GameEnums.Rarity.keys()[def.rarity].capitalize()
	category_label.text = category_name
	
	if def is ItemDefinition:
		slot_name = EquipmentSlot.Type.keys()[def.slot].capitalize()
		category_label.text += "  •  " + slot_name
		
	
	category_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.42))
	category_label.add_theme_font_size_override("font_size", FONT_BODY)

	var has_price := def.get("sell_value") != null or def.get("price") != null
	price_box.visible = has_price
	if has_price:
		var price = def.sell_value if def.get("sell_value") != null else def.price
		price_label.text = "Sells: %d" % price
		price_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.40))
		price_label.add_theme_font_size_override("font_size", FONT_BODY)

	# Stats
	for property in stat_display.keys():
		if property not in def:
			continue

		var value = def.get(property)
		if value == 0 or value == 0.0:
			continue

		var info = stat_display[property]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		stats_box.add_child(row)

		if info.size() > 2 and info[2]:
			var stat_icon := TextureRect.new()
			stat_icon.texture = info[2]
			stat_icon.custom_minimum_size = Vector2(24, 24)
			stat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			stat_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			stat_icon.modulate = Color.ALICE_BLUE
			row.add_child(stat_icon)

		var value_lbl := Label.new()
		value_lbl.text = "%d" % int(round(value))
		value_lbl.add_theme_color_override("font_color", info[1].lightened(0.4))
		value_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		row.add_child(value_lbl)

		var label_lbl := Label.new()
		label_lbl.text = info[0]
		label_lbl.add_theme_color_override("font_color", info[1].darkened(0.35))
		label_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		row.add_child(label_lbl)

	var has_stats := stats_box.get_child_count() > 0
	stats_box.visible = has_stats
	stats_separator.visible = has_stats

	# Affinities
	if item_data.definition is ItemDefinition:
		var item_def: ItemDefinition = item_data.definition
		if not item_def.affinities.is_empty():
			var aff_title := Label.new()
			aff_title.text = "Elemental Affinities:"
			aff_title.add_theme_color_override("font_color", Color(0.4, 0.75, 0.95))
			aff_title.add_theme_font_size_override("font_size", FONT_BODY)
			affinities_box.add_child(aff_title)

			for affinity in item_def.affinities:
				var aff_lbl := Label.new()
				var element_name = GameEnums.DamageElement.keys()[affinity.element].capitalize()
				aff_lbl.text = " • %s: x%.2f Damage" % [element_name, affinity.multiplier]
				aff_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
				aff_lbl.add_theme_font_size_override("font_size", FONT_BODY)
				affinities_box.add_child(aff_lbl)

	var has_affinities := affinities_box.get_child_count() > 0
	affinities_box.visible = has_affinities
	affinities_separator.visible = has_affinities

	# Skill
	if item_data.definition is ItemDefinition and item_data.dice_level >= 0:
		var item_def: ItemDefinition = item_data.definition
		var active_skill: SkillDefinition = item_data.equipped_skill if item_data.equipped_skill else item_def.default_skill

		if active_skill:
			var is_custom := item_data.equipped_skill != null

			var skill_name_lbl := Label.new()
			skill_name_lbl.text = active_skill.skill_name + ("" if is_custom else " (Default)")
			skill_name_lbl.add_theme_color_override(
				"font_color",
				Color(0.91, 0.75, 0.35) if is_custom else Color(0.6, 0.6, 0.6)
			)
			skill_name_lbl.add_theme_font_size_override("font_size", FONT_BODY)
			skill_box.add_child(skill_name_lbl)

			_add_skill_properties_box(active_skill, item_def, stat_display)

	var loose_skill_def: SkillDefinition = null
	if def is SkillItemDefinition:
		loose_skill_def = def.skill

	if loose_skill_def:
		_add_skill_properties_box(loose_skill_def, null, stat_display)

	skill_box.visible = skill_box.get_child_count() > 0

	# Description
	if not def.description.is_empty():
		var blocks = def.description.split("\n\n", false)

		for i in blocks.size():
			var block: String = blocks[i].strip_edges()
			if block.is_empty():
				continue

			var lines := block.split("\n", false)
			var passive_box := VBoxContainer.new()
			passive_box.add_theme_constant_override("separation", 2)
			description_box.add_child(passive_box)

			if lines.size() >= 2:
				var p_title := Label.new()
				p_title.text = lines[0]
				p_title.add_theme_color_override("font_color", Color(0.91, 0.75, 0.35))
				p_title.add_theme_font_size_override("font_size", FONT_BODY)
				passive_box.add_child(p_title)

				var p_desc := _make_description_label("\n".join(lines.slice(1)))
				passive_box.add_child(p_desc)
			else:
				passive_box.add_child(_make_description_label(block))

			if i < blocks.size() - 1:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 4)
				description_box.add_child(gap)

	description_box.visible = description_box.get_child_count() > 0


func _make_description_label(text: String) -> RichTextLabel:
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 16, 0)
	desc.add_theme_color_override("default_color", Color(0.72, 0.72, 0.70))
	desc.add_theme_font_size_override("normal_font_size", FONT_BODY)
	desc.text = _colorize_numbers(text)
	return desc


func _add_skill_properties_box(skill_def: SkillDefinition, owning_item_def: ItemDefinition, stat_display: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	skill_box.add_child(box)

	var header := Label.new()
	header.text = "Skill Properties:"
	header.add_theme_color_override("font_color", Color(0.91, 0.75, 0.35))
	header.add_theme_font_size_override("font_size", FONT_BODY)
	box.add_child(header)

	var effect_lbl := Label.new()
	var element_name = GameEnums.DamageElement.keys()[skill_def.damage_element].capitalize()
	var effect_name = GameEnums.SkillEffect.keys()[skill_def.effect_type].capitalize()
	effect_lbl.text = " • Type: %s (%s)" % [effect_name, element_name]
	effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	effect_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	box.add_child(effect_lbl)

	if not skill_def.scalings.is_empty():
		var scaling_title := Label.new()
		scaling_title.text = " • Damage scaling:"
		scaling_title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
		scaling_title.add_theme_font_size_override("font_size", FONT_BODY)
		box.add_child(scaling_title)

		for scaling in skill_def.scalings:
			var stat_key := _get_stat_key_from_enum(scaling.stat)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			box.add_child(row)

			var indent := Control.new()
			indent.custom_minimum_size = Vector2(16, 0)
			row.add_child(indent)

			if stat_display.has(stat_key):
				var stat_info = stat_display[stat_key]

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

	if skill_def.bonus_hits_per_stat:
		var bonus = skill_def.bonus_hits_per_stat
		var bonus_stat_key = _get_stat_key_from_enum(bonus.stat)
		var stat_name = stat_display[bonus_stat_key][0] if stat_display.has(bonus_stat_key) else GameEnums.Stat.keys()[bonus.stat].capitalize()

		var bonus_lbl := Label.new()
		bonus_lbl.text = " • Bonus Hits: +1 hit per %.1f %s" % [bonus.weight, stat_name]
		bonus_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		bonus_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		box.add_child(bonus_lbl)

	if owning_item_def != null             and skill_def.effect_type == GameEnums.SkillEffect.DAMAGE             and skill_def.damage_element != GameEnums.DamageElement.PHYSICAL             and skill_def.damage_element != GameEnums.DamageElement.NONE:
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
		box.add_child(aff_lbl)


func _clear() -> void:
	icon.texture = null
	name_label.text = ""
	category_label.text = ""
	price_label.text = ""

	price_box.visible = false
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
