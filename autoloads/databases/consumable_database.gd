extends Node
var _resource_database := ResourceDatabase.new()

func _ready() -> void:
	_resource_database.load_folder("res://definitions/consumable", ConsumableDefinition)

func get_by_id(id: String) -> ConsumableDefinition:
	return _resource_database.get_entry(id)

func get_all() -> Array[ConsumableDefinition]:
	var result: Array[ConsumableDefinition] = []
	result.assign(_resource_database.get_entries())
	return result
