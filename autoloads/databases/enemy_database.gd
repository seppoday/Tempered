extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://definitions/enemies", EnemyDefinition)

func get_by_id(id: String) -> EnemyDefinition:
	return _resource_database.get_entry(id)

func get_all() -> Array[EnemyDefinition]:
	var result: Array[EnemyDefinition] = []
	result.assign(_resource_database.get_entries())
	return result