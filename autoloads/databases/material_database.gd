extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://definitions/materials", MaterialDefinition)

func get_by_id(id: String) -> MaterialDefinition:
	return _resource_database.get_entry(id)

func get_all() -> Array[MaterialDefinition]:
	var result: Array[MaterialDefinition] = []
	result.assign(_resource_database.get_entries())
	return result