extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://resources/recipes", RecipeDefinition)


func get_recipe_definition(id: String) -> RecipeDefinition:
	return _resource_database.get_entry(id)

func get_all_recipes() -> Array[RecipeDefinition]:
	var result: Array[RecipeDefinition] = []
	result.assign(_resource_database.get_entries())
	return result
