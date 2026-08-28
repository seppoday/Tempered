extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://resources/characters", CharacterDefinition)

func get_character_definition(id: String) -> CharacterDefinition:
	return _resource_database.get_entry(id)