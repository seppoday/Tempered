extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://resources/items", ItemDefinition)

func get_item_definition(id: String) -> ItemDefinition:
	return _resource_database.get_entry(id)