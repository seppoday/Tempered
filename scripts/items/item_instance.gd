class_name ItemInstance extends RefCounted

var definition: InventoryEntry
var quantity: int = 1


func _init(item_definition: InventoryEntry, amount: int = 1) -> void:
	definition = item_definition
	quantity = amount


func is_stackable() -> bool:
	if definition is MaterialDefinition:
		return (definition as MaterialDefinition).stackable

	return false


func get_max_stack_size() -> int:
	if definition is MaterialDefinition:
		return (definition as MaterialDefinition).max_stack_size

	return 1