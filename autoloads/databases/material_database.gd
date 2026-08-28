extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://resources/materials", MaterialDefinition)

func get_material_definition(id: String) -> MaterialDefinition:
	return _resource_database.get_entry(id)