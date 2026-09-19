extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://definitions/recipes", RecipeDefinition)


func get_by_id(id: String) -> RecipeDefinition:
	return _resource_database.get_entry(id)

func get_all() -> Array[RecipeDefinition]:
	var result: Array[RecipeDefinition] = []
	result.assign(_resource_database.get_entries())
	return result
