extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://definitions/items", ItemDefinition)

func get_by_id(id: String) -> ItemDefinition:
	return _resource_database.get_entry(id)

func get_all() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	result.assign(_resource_database.get_entries())
	return result