# slot.gd
class_name InventorySlot
extends Panel

var item_data: ItemInstance = null

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $CountLabel
@onready var name_label: Label = $Name

signal slot_changed(slot: Panel)

const SkillFacePickerScene := preload("res://scenes/UI/skill_face_picker.tscn")

# Słownik definiujący dokładny wygląd nazwy statystyki oraz jej kolor.
# Wszystkie wartości są teraz traktowane jako czyste liczby całkowite (jak siła/zręczność).
# Słownik definiujący wygląd, kolor oraz ikonę statystyki.
const STAT_DISPLAY := {
	"dmg":    ["DAMAGE", Color(0.95, 0.3, 0.3), preload("res://assets/icons/stats/sword.svg")],
	"magic":  ["MAGIC", Color(0.0, 0.3, 0.9), preload("res://assets/icons/stats/sword.svg")],
	"def":    ["DEFENSE", Color(0.6, 0.6, 0.65), preload("res://assets/icons/stats/sword.svg")],
	"vit":    ["VITALITY", Color(0.2, 0.8, 0.2), preload("res://assets/icons/stats/sword.svg")],
	"speed":  ["SPEED", Color(0.95, 0.95, 0.95), preload("res://assets/icons/stats/sword.svg")],
	"luck":   ["LUCK", Color(0.2, 0.8, 0.8), preload("res://assets/icons/stats/sword.svg")],
	"status": ["STATUS", Color(0.85, 0.3, 0.4), preload("res://assets/icons/stats/sword.svg")],
	"crit":   ["CRIT", Color(0.9, 0.7, 0.2), preload("res://assets/icons/stats/sword.svg")],
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
const FONT_TITLE := 28
const FONT_BODY := 20
const TOOLTIP_WIDTH := 500

func _make_custom_tooltip(_for_text: String) -> Control:
	if is_empty() or not item_data.definition:
		return null

	var def = item_data.definition
	var rarity_color := _get_rarity_color()

	# ── Root ──────────────────────────────────────────────
	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.111, 0.127, 0.157, 0.96)
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
		icon_rect.custom_minimum_size = Vector2(64, 64)
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
	if item_data.definition is ItemDefinition and item_data.dice_level >= 0:
		var dice_size := GameEnums.DICE_PROGRESSION[item_data.dice_level]
		name_label.text = "%s (d%d)" % [def.name, dice_size]
	else:
		name_label.text = def.name
	name_label.add_theme_color_override("font_color", Color(0.91, 0.84, 0.58))
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
		stats_box.add_theme_constant_override("separation", 2) # Lekki odstęp między wierszami
		root.add_child(stats_box)

		for row in stat_rows:
			var row_h := HBoxContainer.new()
			row_h.add_theme_constant_override("separation", 6) # <--- ZMIENIONE Z 0 NA 6 (odstęp ikona <-> tekst)
			stats_box.add_child(row_h)

			if row.has("icon") and row["icon"]:
				var s_icon := TextureRect.new()
				s_icon.texture = row["icon"]
				s_icon.custom_minimum_size = Vector2(32, 32) # <--- ZMIENIONE NA 18x18 (lepiej pasuje do czcionki 20px)
				s_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				s_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				s_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				s_icon.modulate = Color.ALICE_BLUE
				row_h.add_child(s_icon)

			var stat_lbl := Label.new()
			stat_lbl.text = row["text"]
			stat_lbl.add_theme_color_override("font_color", row.get("color", Color(0.85, 0.78, 0.50)))
			stat_lbl.add_theme_font_size_override("font_size", FONT_BODY)
			row_h.add_child(stat_lbl)

		root.add_child(_make_separator())

	# ── AFFINITIES ────────────────────────────────────────
	if item_data.definition is ItemDefinition:
		var item_def: ItemDefinition = item_data.definition
		if not item_def.affinities.is_empty():
			var aff_box := VBoxContainer.new()
			aff_box.add_theme_constant_override("separation", 2)
			root.add_child(aff_box)

			var aff_title := Label.new()
			aff_title.text = "Elemental Affinities:"
			aff_title.add_theme_color_override("font_color", Color(0.4, 0.75, 0.95))
			aff_title.add_theme_font_size_override("font_size", FONT_BODY)
			aff_box.add_child(aff_title)

			for affinity in item_def.affinities:
				var row := HBoxContainer.new()
				aff_box.add_child(row)

				var aff_lbl := Label.new()
				var element_name = GameEnums.DamageElement.keys()[affinity.element].capitalize()
				aff_lbl.text = " • %s: x%.2f Damage" % [element_name, affinity.multiplier]
				aff_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
				aff_lbl.add_theme_font_size_override("font_size", FONT_BODY)
				row.add_child(aff_lbl)

			root.add_child(_make_separator())
	
	# ── SKILLE NA KOŚCI ──────────────────
	if item_data.definition is ItemDefinition and item_data.dice_level >= 0:
		var item_def: ItemDefinition = item_data.definition

		var skills_box := VBoxContainer.new()
		skills_box.add_theme_constant_override("separation", 2)
		root.add_child(skills_box)

		var skills_title := Label.new()
		skills_title.text = "Skill slots"
		skills_title.add_theme_color_override("font_color", Color(0.91, 0.75, 0.35))
		skills_title.add_theme_font_size_override("font_size", FONT_BODY)
		skills_box.add_child(skills_title)

		for face in range(1, 7):
			var assigned: SkillDefinition = item_data.slot_assignments.get(face)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			skills_box.add_child(row)

			var face_lbl := Label.new()
			face_lbl.text = "%d:" % face
			face_lbl.custom_minimum_size = Vector2(18, 0)
			face_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			face_lbl.add_theme_font_size_override("font_size", FONT_BODY)
			row.add_child(face_lbl)

			var skill_lbl := Label.new()
			if assigned:
				skill_lbl.text = assigned.skill_name
				skill_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.50))
			elif item_def.default_skill:
				skill_lbl.text = "%s (Default)" % item_def.default_skill.skill_name
				skill_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			else:
				skill_lbl.text = "—"
				skill_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			skill_lbl.add_theme_font_size_override("font_size", FONT_BODY)
			row.add_child(skill_lbl)

		root.add_child(_make_separator())

	# ── SZCZEGÓŁY I SKALOWANIE SKILLA ──────────────────────
	var skill_def: SkillDefinition = null
	if def is SkillItemDefinition:
		skill_def = def.skill

	if skill_def:
		var skill_box := VBoxContainer.new()
		skill_box.add_theme_constant_override("separation", 4)
		root.add_child(skill_box)

		# Nagłówek sekcji skilla
		var skill_header := Label.new()
		skill_header.text = "Skill Properties:"
		skill_header.add_theme_color_override("font_color", Color(0.91, 0.75, 0.35))
		skill_header.add_theme_font_size_override("font_size", FONT_BODY)
		skill_box.add_child(skill_header)

		# Typ efektu i żywioł (np. Damage: Physical)
		var effect_lbl := Label.new()
		var element_name = GameEnums.DamageElement.keys()[skill_def.damage_element].capitalize()
		var effect_name = GameEnums.SkillEffect.keys()[skill_def.effect_type].capitalize()
		effect_lbl.text = " • Type: %s (%s)" % [effect_name, element_name]
		effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
		effect_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		skill_box.add_child(effect_lbl)

		# Wyświetlanie skalowania (Scalings)
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
				
				# Małe wcięcie z lewej strony
				var indent := Control.new()
				indent.custom_minimum_size = Vector2(16, 0)
				row.add_child(indent)

				# Pobieramy ikonę i kolor z Twojego STAT_DISPLAY
				if STAT_DISPLAY.has(stat_key):
					var stat_info = STAT_DISPLAY[stat_key]
					
					# Mini-ikonka statystyki
					if stat_info.size() > 2 and stat_info[2]:
						var s_icon := TextureRect.new()
						s_icon.texture = stat_info[2]
						s_icon.custom_minimum_size = Vector2(18, 18)
						s_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
						s_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						s_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
						row.add_child(s_icon)

					# Nazwa statystyki + waga (np. "DAMAGE x1.20")
					var scaling_lbl := Label.new()
					scaling_lbl.text = "%s x%.2f" % [stat_info[0], scaling.weight]
					scaling_lbl.add_theme_color_override("font_color", stat_info[1])
					scaling_lbl.add_theme_font_size_override("font_size", FONT_BODY)
					row.add_child(scaling_lbl)
				else:
					# Awaryjny fallback na wypadek braku wpisu w STAT_DISPLAY
					var scaling_lbl := Label.new()
					var fallback_name = GameEnums.Stat.keys()[scaling.stat].capitalize()
					scaling_lbl.text = "%s x%.2f" % [fallback_name, scaling.weight]
					scaling_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
					scaling_lbl.add_theme_font_size_override("font_size", FONT_BODY)
					row.add_child(scaling_lbl)

				skill_box.add_child(row)

		# Dodatkowe trafienia (bonus_hits_per_stat)
		if skill_def.bonus_hits_per_stat:
			var bonus = skill_def.bonus_hits_per_stat
			var stat_key = _get_stat_key_from_enum(bonus.stat)
			var stat_name = STAT_DISPLAY[stat_key][0] if STAT_DISPLAY.has(stat_key) else GameEnums.Stat.keys()[bonus.stat].capitalize()
			
			var bonus_lbl := Label.new()
			bonus_lbl.text = " • Bonus Hits: +1 hit per %.1f %s" % [bonus.weight, stat_name]
			bonus_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
			bonus_lbl.add_theme_font_size_override("font_size", FONT_BODY)
			skill_box.add_child(bonus_lbl)

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
				p_desc.custom_minimum_size = Vector2(300, 0)
				p_desc.add_theme_color_override("default_color", Color(0.72, 0.72, 0.70))
				p_desc.add_theme_font_size_override("normal_font_size", FONT_BODY)
				p_desc.text = _colorize_numbers("\n".join(lines.slice(1)))
				passive_box.add_child(p_desc)
			else:
				var desc := RichTextLabel.new()
				desc.bbcode_enabled = true
				desc.fit_content = true
				desc.scroll_active = false
				desc.custom_minimum_size = Vector2(300, 0)
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

			# Ignoruj puste/zerowe wartości
			if value == 0 or value == 0.0:
				continue
				
			var info = STAT_DISPLAY[property]
			
			# Bezwarunkowe rzutowanie na czystą liczbę całkowitą (int)
			var value_str := "%d" % int(round(value))
				
			# Format: "NAZWA: WARTOŚĆ" (np. "DAMAGE: 5")
			var formatted_text = "%s: %s" % [info[0], value_str]
			
			# Pobieramy ikonę, jeśli istnieje w słowniku
			var icon_texture: Texture2D = null
			if info.size() > 2:
				icon_texture = info[2]
			
			rows.append({
				"text": formatted_text, 
				"color": info[1],
				"icon": icon_texture
			})
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
	if not is_empty() and dragged_instance.definition is SkillItemDefinition and item_data.definition is ItemDefinition:
		_open_skill_face_picker(dragged_instance.definition.skill, source_slot)
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

func _open_skill_face_picker(skill: SkillDefinition, source_slot: Panel) -> void:
	var picker := SkillFacePickerScene.instantiate()
	get_tree().root.add_child(picker)
	picker.assignment_confirmed.connect(_on_skill_assignment_confirmed.bind(source_slot))
	picker.setup(item_data, skill)

func _on_skill_assignment_confirmed(face: int, skill: SkillDefinition, source_slot: Panel) -> void:
	item_data.slot_assignments[face] = skill
	_update_visual()

	source_slot.item_data.quantity -= 1
	if source_slot.item_data.quantity <= 0:
		source_slot.clear()
	else:
		source_slot._update_visual()
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
	
	# Jeżeli w Enumie masz np. "VITALITY", a w STAT_DISPLAY używasz "vit",
	# tutaj robimy mapowanie wyjątków:
	match enum_name:
		"vitality": return "vit"
		"defense": return "def"
		"damage": return "dmg"
		_: return enum_name
