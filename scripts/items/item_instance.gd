class_name ItemInstance extends RefCounted

var definition: InventoryEntry
var quantity: int = 1
var upgrade_level: int = 0


func _init(item_definition: InventoryEntry, amount: int = 1, level: int = 0) -> void:
	definition = item_definition
	quantity = amount
	upgrade_level = level


func is_stackable() -> bool:
	return definition.stackable


func get_max_stack_size() -> int:
	return definition.max_stack_size