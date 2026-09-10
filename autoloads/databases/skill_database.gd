extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://resources/skills", SkillDefinition)

func get_skill_definition(id: String) -> SkillDefinition:
	return _resource_database.get_entry(id)