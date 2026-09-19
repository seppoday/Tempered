extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	_resource_database.load_folder("res://definitions/characters", CharacterDefinition)

func get_by_id(id: String) -> CharacterDefinition:
	return _resource_database.get_entry(id)

func get_all() -> Array[CharacterDefinition]:
	var characters: Array[CharacterDefinition] = []
	characters.assign(_resource_database.get_entries())
	return characters