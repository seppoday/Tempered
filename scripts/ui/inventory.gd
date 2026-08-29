# inventory.gd
extends PanelContainer

@onready var grid: GridContainer = $MarginContainer/GridContainer

const SLOT_COUNT: int = 48
const SLOT_GAP: int = 12
const GRID_COLUMNS: int = 6

# Jedyna linijka potrzebna do tworzenia slotów:
const SlotScene: PackedScene = preload("res://scenes/slot.tscn")

@export var test_items: Array[InventoryEntry] = []

func _ready() -> void:
	EventBus.item_pickup_requested.connect(_on_item_pickup_requested)
	_setup_grid()
	_create_slots()

	for definition in test_items:
		if definition:
			add_item(ItemInstance.new(definition))

func _create_slots() -> void:
	for i in range(SLOT_COUNT):
		var slot: Panel = SlotScene.instantiate()
		slot.slot_changed.connect(_on_slot_changed)
		grid.add_child(slot)

func _setup_grid() -> void:
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)

# ==========================================
# PUBLIC API
# ==========================================

func add_item(item: ItemInstance) -> bool:
	# Najpierw próbujemy dołożyć do istniejących stacków.
	if item.is_stackable():
		var max_stack := item.get_max_stack_size()

		for slot in grid.get_children():
			if slot.is_empty():
				continue

			var slot_item: ItemInstance = slot.item_data

			if not slot_item.is_stackable():
				continue

			if slot_item.definition.id != item.definition.id:
				continue

			if slot_item.quantity >= max_stack:
				continue

			var space := max_stack - slot_item.quantity
			var to_add = min(space, item.quantity)

			slot_item.quantity += to_add
			item.quantity -= to_add

			slot._update_visual()

			if item.quantity <= 0:
				return true

	# Jeżeli nadal coś zostało, szukamy pustych slotów.
	while item.quantity > 0:
		var empty_slot = null

		for slot in grid.get_children():
			if slot.is_empty():
				empty_slot = slot
				break

		if empty_slot == null:
			print("[INVENTORY] Full! Remaining: ", item.quantity)
			return false

		if item.is_stackable():
			var stack_size = min(item.quantity, item.get_max_stack_size())

			var new_item := ItemInstance.new(
				item.definition,
				stack_size
			)

			empty_slot.set_item(new_item)
			item.quantity -= stack_size
		else:
			# Zwykły ItemDefinition = jeden item na slot.
			var new_item := ItemInstance.new(item.definition, 1)

			empty_slot.set_item(new_item)
			item.quantity -= 1

	return true

func remove_item(item_id: String, amount: int = 1) -> bool:
	var remaining: int = amount
	for slot in grid.get_children():
		if remaining <= 0:
			break
		if not slot.is_empty() and slot.item_data.definition.id == item_id:
			var have: int = slot.item_data.quantity
			if have <= remaining:
				remaining -= have
				slot.clear()
			else:
				slot.item_data.quantity -= remaining
				slot._update_visual()
				remaining = 0
	return remaining == 0

func get_all_items() -> Array[ItemInstance]:
	var items: Array[ItemInstance] = []
	for slot in grid.get_children():
		if not slot.is_empty():
			items.append(slot.item_data)
	return items

func _on_slot_changed(slot: Panel) -> void:
	if slot.item_data:
		print("[INVENTORY] Slot: ", slot.item_data.definition.name, " x", slot.item_data.quantity)
	else:
		print("[INVENTORY] Slot cleared")

func _on_item_pickup_requested(item_instance: ItemInstance, drop_node: Node) -> void:
	if add_item(item_instance):
		if is_instance_valid(drop_node):
			if drop_node.has_method("on_collected"):
				drop_node.on_collected()
			else:
				drop_node.queue_free()
