extends Node
var _resource_database := ResourceDatabase.new()

func _ready() -> void:
	_resource_database.load_folder("res://definitions/skill_items", SkillItemDefinition)

func get_by_id(id: String) -> SkillItemDefinition:
	return _resource_database.get_entry(id)

func get_all() -> Array[SkillItemDefinition]:
	var result: Array[SkillItemDefinition] = []
	result.assign(_resource_database.get_entries())
	return result
