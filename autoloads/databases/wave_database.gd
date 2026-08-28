extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://resources/waves", WaveDefinition)

func get_wave_definition(id: String) -> WaveDefinition:
	return _resource_database.get_entry(id)