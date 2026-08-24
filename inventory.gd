# inventory.gd
extends PanelContainer

@onready var grid: GridContainer = $MarginContainer/GridContainer

const SLOT_COUNT: int = 55
const SLOT_SIZE: int = 64
const SLOT_GAP: int = 4
const GRID_COLUMNS: int = 5

@export var clover_fragment: CompressedTexture2D
@export var dragons_eye: CompressedTexture2D
@export var dust_magic: CompressedTexture2D
@export var lucky_powder: CompressedTexture2D
@export var quicksilver_oil: CompressedTexture2D
@export var stone_elixir_weapon: CompressedTexture2D
@export var whetstone: CompressedTexture2D

# TODO: podmień test_icon na docelowe tekstury tych przedmiotów, gdy będą gotowe
@export var obsidian_blade_icon: CompressedTexture2D
@export var iron_shield_icon: CompressedTexture2D
@export var leather_helmet_icon: CompressedTexture2D
@export var chainmail_armor_icon: CompressedTexture2D
@export var worn_boots_icon: CompressedTexture2D
@export var jade_amulet_icon: CompressedTexture2D
@export var copper_ring_icon: CompressedTexture2D

func _ready() -> void:
	EventBus.item_pickup_requested.connect(_on_item_pickup_requested)
	_setup_grid()

	# ROZWIĄZANIE: Jeśli grid jest pusty w edytorze, tworzymy sloty kodem
	if grid.get_child_count() == 0:
		_create_slots()
	else:
		# Jeśli stworzyłeś sloty ręcznie w edytorze, upewnij się, że mają skrypt i podepnij sygnały:
		for slot in grid.get_children():
			if slot.has_signal("slot_changed"):
				slot.slot_changed.connect(_on_slot_changed)
				slot._update_visual()

	# DODAJEMY TESTOWE PRZEDMIOTY
	# Domyślna ikonka Godota (fallback dla itemów bez własnej tekstury)
	var test_icon = load("res://icon.svg")

	# ==========================================
	# EKWIPUNEK (item_type = "equipment") — pełny zestaw 7 slotów
	# Te trafiają do equip slotów w CharacterPanel
	# ==========================================

	add_item({
		"id": "obsidian_blade",
		"name": "Obsidian Blade",
		"description": "Podstawowy miecz do ulepszania kamieniami i zwojami.",
		"item_type": "equipment",
		"equip_slot": "weapon",
		"base_damage": 125,
		"attack_speed": 5.2,
		"crit_chance": 0.15,
		"crit_multiplier": 2.5,
		"attack_range": 1.5,
		"target_count": 1,
		"count": 1,
		"stackable": false,
		"rarity": "rare",
		"texture": obsidian_blade_icon if obsidian_blade_icon else test_icon
	})

	add_item({
		"id": "iron_shield",
		"name": "Iron Shield",
		"description": "Podstawowa tarcza zwiększająca szansę bloku.",
		"item_type": "equipment",
		"equip_slot": "shield",
		"block_chance": 0.15,
		"thorns": 3,
		"count": 1,
		"stackable": false,
		"rarity": "common",
		"texture": iron_shield_icon if iron_shield_icon else test_icon
	})

	add_item({
		"id": "leather_helmet",
		"name": "Leather Helmet",
		"description": "Lekki hełm, niewielki bonus do uniku.",
		"item_type": "equipment",
		"equip_slot": "helmet",
		"dodge_chance": 0.05,
		"count": 1,
		"stackable": false,
		"rarity": "common",
		"texture": leather_helmet_icon if leather_helmet_icon else test_icon
	})

	add_item({
		"id": "chainmail_armor",
		"name": "Chainmail Armor",
		"description": "Solidna zbroja, dobra podstawa obrony.",
		"item_type": "equipment",
		"equip_slot": "armor",
		"block_chance": 0.08,
		"thorns": 2,
		"execute_threshold": 0.0,
		"count": 1,
		"stackable": false,
		"rarity": "common",
		"texture": chainmail_armor_icon if chainmail_armor_icon else test_icon
	})

	add_item({
		"id": "worn_boots",
		"name": "Worn Boots",
		"description": "Znoszone buty, niewielki bonus do uniku.",
		"item_type": "equipment",
		"equip_slot": "boots",
		"dodge_chance": 0.03,
		"count": 1,
		"stackable": false,
		"rarity": "common",
		"texture": worn_boots_icon if worn_boots_icon else test_icon
	})

	add_item({
		"id": "jade_amulet",
		"name": "Jade Amulet",
		"description": "Amulet zwiększający skuteczność egzekucji słabych przeciwników.",
		"item_type": "equipment",
		"equip_slot": "amulet",
		"execute_threshold": 0.1,
		"crit_chance": 0.03,
		"count": 1,
		"stackable": false,
		"rarity": "uncommon",
		"texture": jade_amulet_icon if jade_amulet_icon else test_icon
	})

	add_item({
		"id": "copper_ring",
		"name": "Copper Ring",
		"description": "Prosty pierścień poprawiający szczęście w dropach.",
		"item_type": "equipment",
		"equip_slot": "ring",
		"luck": 2,
		"lifesteal": 0.02,
		"count": 1,
		"stackable": false,
		"rarity": "common",
		"texture": copper_ring_icon if copper_ring_icon else test_icon
	})

	# ==========================================
	# MATERIAŁY / MODYFIKATORY (bez zmian)
	# ==========================================

	# Zwykły składnik - NIE zadziała na broń (Tylko do łączenia w AlchemyPanel)
	add_item({
		"id": "dust_magic",
		"name": "Magiczny Pył",
		"description": "Zwykły materiał alchemiczny. Połącz go, by uzyskać kamień.",
		"item_type": "material",
		"count": 50,
		"stackable": true,
		"rarity": "common",
		"texture": dust_magic
	})

	# Kamień ulepszenia - działa na broń (Drag & Drop)
	add_item({
		"id": "stone_elixir_weapon",
		"name": "Elixir of Weapon",
		"description": "Służy do ulepszania broni. Szansa: 20%",
		"item_type": "upgrade_stone",
		"success_chance": 0.50, # 20% szansy na sukces
		"count": 30,
		"stackable": true,
		"rarity": "rare",
		"texture": stone_elixir_weapon
	})

	# Zwoje/materiały dodające statystyki - działają na broń (generyczny stat_target)
	add_item({
		"id": "whetstone",
		"name": "Whetstone",
		"description": "Ostrzy ostrze. Dodaje +2 do obrażeń bazowych.",
		"item_type": "stat_scroll",
		"stat_target": "base_damage",
		"stat_amount": 2,
		"count": 10,
		"stackable": true,
		"rarity": "common",
		"texture": whetstone
	})

	add_item({
		"id": "quicksilver_oil",
		"name": "Quicksilver Oil",
		"description": "Przyspiesza ataki. Dodaje +0.05 do szybkości ataku.",
		"item_type": "stat_scroll",
		"stat_target": "attack_speed",
		"stat_amount": 0.05,
		"count": 10,
		"stackable": true,
		"rarity": "uncommon",
		"texture": quicksilver_oil
	})

	add_item({
		"id": "dragons_eye",
		"name": "Dragon's Eye",
		"description": "Rzadki klejnot. Dodaje +10 obrażeń od ognia.",
		"item_type": "stat_scroll",
		"stat_target": "fire_damage",
		"stat_amount": 10,
		"count": 3,
		"stackable": true,
		"rarity": "epic",
		"texture": dragons_eye
	})

	add_item({
		"id": "clover_fragment",
		"name": "Clover Fragment",
		"description": "Dodaje +1% do szczęścia (Luck) - lepsze dropy.",
		"item_type": "stat_scroll",
		"stat_target": "luck",
		"stat_amount": 1,
		"count": 5,
		"stackable": true,
		"rarity": "rare",
		"texture": clover_fragment
	})

	add_item({
		"id": "lucky_powder",
		"name": "Lucky Powder",
		"item_type": "modifier",
		"count": 5,
		"stackable": true,
		"rarity": "uncommon",
		"description": "W alchemii: +2% szansy do kamienia ulepszeń.",
		"texture": lucky_powder
	})

func _create_slots() -> void:
	for i in range(SLOT_COUNT):
		var slot: Panel = _make_slot()
		grid.add_child(slot)

func _make_slot() -> Panel:
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.size_flags_horizontal = Control.SIZE_FILL
	slot.size_flags_vertical = Control.SIZE_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_STOP  # 🔴 ważne

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
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 🔴 ważne
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
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 🔴 ważne
	slot.add_child(count_label)

	slot.set_script(preload("res://slot.gd"))
	slot.slot_changed.connect(_on_slot_changed)

	return slot

func _setup_grid() -> void:
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", SLOT_GAP)  # FIX: odstępy
	grid.add_theme_constant_override("v_separation", SLOT_GAP)  # FIX: odstępy

# ==========================================
# PUBLIC API (bez zmian)
# ==========================================

func add_item(item: Dictionary) -> bool:
	if item.get("stackable", false):
		for slot in grid.get_children():
			if not slot.is_empty() and slot.item_data.get("id") == item.get("id"):
				slot.item_data["count"] = slot.item_data.get("count", 1) + item.get("count", 1)
				slot._update_visual()
				return true

	for slot in grid.get_children():
		if slot.is_empty():
			slot.set_item(item)
			return true

	print("[INVENTORY] Full!")
	return false

func remove_item(item_id: String, amount: int = 1) -> bool:
	var remaining: int = amount
	for slot in grid.get_children():
		if remaining <= 0:
			break
		if not slot.is_empty() and slot.item_data.get("id") == item_id:
			var have: int = slot.item_data.get("count", 1)
			if have <= remaining:
				remaining -= have
				slot.clear()
			else:
				slot.item_data["count"] -= remaining
				slot._update_visual()
				remaining = 0
	return remaining == 0

func get_all_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for slot in grid.get_children():
		if not slot.is_empty():
			items.append(slot.item_data.duplicate())
	return items

func _on_slot_changed(slot: Panel) -> void:
	print("[INVENTORY] Slot changed: ", slot.item_data)


# Obsługa sygnału podnoszenia przedmiotu
func _on_item_pickup_requested(item_data: Dictionary, drop_node: Node) -> void:
	# Próbujemy dodać przedmiot do ekwipunku
	if add_item(item_data):
		# Jeśli dodawanie się powiodło (było miejsce), usuwamy drop z ziemi
		if is_instance_valid(drop_node):
			if drop_node.has_method("on_collected"):
				drop_node.on_collected()
			else:
				drop_node.queue_free()