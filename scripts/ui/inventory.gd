# inventory.gd
extends PanelContainer

@onready var grid: GridContainer = $MarginContainer/GridContainer

const SLOT_COUNT: int = 55
const SLOT_GAP: int = 4
const GRID_COLUMNS: int = 5

# Jedyna linijka potrzebna do tworzenia slotów:
const SlotScene: PackedScene = preload("res://scenes/slot.tscn")

@export var test_items: Array[ItemDefinition]

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
	if item.definition.stackable:
		for slot in grid.get_children():
			if not slot.is_empty() and slot.item_data.definition.id == item.definition.id:
				var current_qty = slot.item_data.quantity
				var max_stack = slot.item_data.definition.max_stack_size
				if current_qty < max_stack:
					var to_add = min(max_stack - current_qty, item.quantity)
					slot.item_data.quantity += to_add
					item.quantity -= to_add
					slot._update_visual()
					if item.quantity <= 0:
						return true

	if item.quantity > 0:
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
		print("[INVENTORY] Slot: ", slot.item_data.definition.item_name, " x", slot.item_data.quantity)
	else:
		print("[INVENTORY] Slot cleared")

func _on_item_pickup_requested(item_def: ItemDefinition, drop_node: Node) -> void:
	var instance := ItemInstance.new(item_def)
	if add_item(instance):
		if is_instance_valid(drop_node):
			if drop_node.has_method("on_collected"):
				drop_node.on_collected()
			else:
				drop_node.queue_free()