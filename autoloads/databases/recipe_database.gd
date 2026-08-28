extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://resources/recipes", RecipeDefinition)


func get_recipe_definition(id: String) -> RecipeDefinition:
	return _resource_database.get_entry(id)