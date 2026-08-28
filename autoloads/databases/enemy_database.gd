extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://resources/enemies", EnemyDefinition)

func get_enemy_definition(id: String) -> EnemyDefinition:
	return _resource_database.get_entry(id)