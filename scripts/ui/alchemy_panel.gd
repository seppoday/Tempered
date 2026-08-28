extends PanelContainer

@onready var grid: GridContainer = %AlchemyGrid
@onready var result_grid: GridContainer = %AlchemyGridResults
@onready var craft_button: Button = %CraftButton

const INGREDIENT_SLOT_COUNT: int = 2
const SLOT_SIZE: int = 64
const SLOT_GAP: int = 4

func _ready() -> void:
	_setup_grid(grid, INGREDIENT_SLOT_COUNT)
	_setup_grid(result_grid, 1)
	_create_slots(grid, INGREDIENT_SLOT_COUNT)
	_create_slots(result_grid, 1)
	craft_button.pressed.connect(_on_craft_button_pressed)

func _create_slots(target_grid: GridContainer, count: int) -> void:
	for i in range(count):
		var slot: Panel = _make_slot()
		target_grid.add_child(slot)

func _make_slot() -> Panel:
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.size_flags_horizontal = Control.SIZE_FILL
	slot.size_flags_vertical = Control.SIZE_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 1.0)
	style.border_color = Color(0.32, 0.32, 0.36, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.visible = false
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var count_label: Label = Label.new()
	count_label.name = "CountLabel"
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.offset_left = -24
	count_label.offset_top = -18
	count_label.offset_right = -2
	count_label.offset_bottom = -2
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count_label)

	slot.set_script(preload("res://scripts/ui/slot.gd"))
	slot.slot_changed.connect(_on_alchemy_slot_changed)
	return slot

func _setup_grid(target_grid: GridContainer, columns: int) -> void:
	target_grid.columns = columns
	target_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	target_grid.add_theme_constant_override("v_separation", SLOT_GAP)

func get_ingredient_items() -> Array:
	var items = []
	for slot in grid.get_children():
		items.append(slot.item_data)
	return items

func get_result_slot() -> Panel:
	return result_grid.get_children()[0]

# ==========================================
# LOGIKA ALCHEMII (TRANSFORM & ENHANCE)
# ==========================================

func _on_craft_button_pressed() -> void:
	var items = get_ingredient_items()

	var item1: Dictionary = items[0] if typeof(items[0]) == TYPE_DICTIONARY else {}
	var item2: Dictionary = items[1] if typeof(items[1]) == TYPE_DICTIONARY else {}

	if item1.is_empty() or item2.is_empty():
		print("[ALCHEMY] Brak składników w obu slotach!")
		return

	var id1 = item1.get("id", "")
	var id2 = item2.get("id", "")

	print("[ALCHEMY] Próba połączenia: ", item1.get("name"), " + ", item2.get("name"))

	if _is_upgrade_stone(item1) and id2 == "lucky_powder":
		_brew_success(_enhance_stone(item1, 0.02))
		return
	elif _is_upgrade_stone(item2) and id1 == "lucky_powder":
		_brew_success(_enhance_stone(item2, 0.02))
		return

	if id1 == "dust_magic" and id2 == "dust_magic":
		_brew_success(_make_elixir(0.20, "rare"))
		return

	print("[ALCHEMY] Nieznany przepis!")

func _is_upgrade_stone(item: Dictionary) -> bool:
	return item.get("item_type", "") == "upgrade_stone"

func _enhance_stone(base: Dictionary, bonus: float) -> Dictionary:
	var result = base.duplicate(true)
	var chance: float = float(result.get("success_chance", 0.1))
	var enhance_level: int = int(result.get("enhance_level", 0))

	chance = min(chance + bonus, 0.95)
	enhance_level += 1

	var chance_int: int = int(round(chance * 100))

	var base_id: String = result.get("id", "").split("_c")[0]
	result["id"] = "%s_c%d" % [base_id, chance_int]

	result["success_chance"] = chance
	result["enhance_level"] = enhance_level
	result["count"] = 1

	var clean_name: String = result.get("name", "Stone").split(" (+")[0]
	result["name"] = "%s (+%d%%)" % [clean_name, enhance_level * int(bonus * 100)]
	result["description"] = "Wzmocniony kamień ulepszeń.\nSzansa na sukces: %d%%" % chance_int

	if enhance_level >= 3 and result.get("rarity", "common") == "rare":
		result["rarity"] = "epic"
	if enhance_level >= 7:
		result["rarity"] = "legendary"

	return result

func _make_elixir(chance: float, rarity: String) -> Dictionary:
	return {
		"id": "stone_elixir_weapon_c%d" % int(chance * 100),
		"name": "Elixir of Weapon",
		"description": "Służy do ulepszania broni.\nSzansa: %d%%" % int(chance * 100),
		"item_type": "upgrade_stone",
		"success_chance": chance,
		"enhance_level": 0,
		"count": 1,
		"stackable": true,
		"rarity": rarity,
		"texture": load("res://icon.svg")
	}

func _brew_success(result_item: Dictionary) -> void:
	var ingredient_slots = grid.get_children()

	for slot in ingredient_slots:
		if not slot.is_empty():
			var count = slot.item_data.get("count", 1)
			if count > 1:
				slot.item_data["count"] -= 1
				slot._update_visual()
			else:
				slot.clear()

	var result_slot = get_result_slot()

	if not result_slot.is_empty() \
		and result_slot.item_data.get("id") == result_item.get("id") \
		and result_slot.item_data.get("stackable", false):
		result_slot.item_data["count"] += result_item.get("count", 1)
		result_slot._update_visual()
	else:
		result_slot.set_item(result_item)

	print("[ALCHEMY] Sukces! Stworzono: ", result_item.name)

func _on_alchemy_slot_changed(_slot: Panel) -> void:
	var items = get_ingredient_items()
	var has1 = typeof(items[0]) == TYPE_DICTIONARY and not items[0].is_empty()
	var has2 = typeof(items[1]) == TYPE_DICTIONARY and not items[1].is_empty()
	craft_button.disabled = not (has1 and has2)
