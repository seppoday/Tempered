extends PanelContainer

@onready var alchemy_grid: GridContainer = %AlchemyGrid
@onready var result_grid: GridContainer = %AlchemyGridResults

var slot_content: Dictionary = {}

const SLOT_COUNT: int = 4
const SLOT_GAP: int = 12
const GRID_COLUMNS: int = 6

# Jedyna linijka potrzebna do tworzenia slotów:
const SlotScene: PackedScene = preload("res://scenes/slot.tscn")

func _ready() -> void:
	_setup_grid()
	_create_slots()

func _setup_grid() -> void:
	alchemy_grid.columns = GRID_COLUMNS
	alchemy_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	alchemy_grid.add_theme_constant_override("v_separation", SLOT_GAP)
	
	result_grid.columns = 1
	result_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	result_grid.add_theme_constant_override("v_separation", SLOT_GAP)


func _create_slots() -> void:
	for i in range(SLOT_COUNT):
		var slot: Panel = SlotScene.instantiate()
		slot.slot_changed.connect(_on_slot_changed)
		alchemy_grid.add_child(slot)
	
	var result_grid_slot: Panel = SlotScene.instantiate()
	result_grid.add_child(result_grid_slot)

func _on_slot_changed(slot: Panel) -> void:
	if slot.item_data:
		print("[ALCHEMY] Slot: ", slot.item_data.definition.name, " x", slot.item_data.quantity)
	else:
		print("[ALCHEMY] Slot cleared")
	
	_collect_slot_contents()

func _collect_slot_contents():
	slot_content.clear()

	for slot in alchemy_grid.get_children():
		if slot.is_empty():
			continue
		else:
			if slot_content.has(slot.item_data.definition.name):
				slot_content[slot.item_data.definition.name] += slot.item_data.quantity
			else:
				slot_content.get_or_add(slot.item_data.definition.name, slot.item_data.quantity)

	print(slot_content)
