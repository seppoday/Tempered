class_name ItemInstance extends RefCounted

var definition: InventoryEntry
var quantity: int = 1


func _init(item_definition: InventoryEntry, amount: int = 1) -> void:
	definition = item_definition
	quantity = amount


func is_stackable() -> bool:
	return definition.stackable


func get_max_stack_size() -> int:
	return definition.max_stack_size