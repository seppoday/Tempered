class_name ItemInstance extends RefCounted

var definition: ItemDefinition
var quantity: int = 1

func _init(item_definition: ItemDefinition, amount: int = 1) -> void:
	definition = item_definition
	quantity = amount