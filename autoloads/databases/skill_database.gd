extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://definitions/skills", SkillDefinition)

func get_by_id(id: String) -> SkillDefinition:
	return _resource_database.get_entry(id)

func get_all() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	result.assign(_resource_database.get_entries())
	return result