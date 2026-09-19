extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://definitions/loot_tables", LootTable)

func get_by_id(id: String) -> LootTable:
	return _resource_database.get_entry(id)

func get_all() -> Array[LootTable]:
	var result: Array[LootTable] = []
	result.assign(_resource_database.get_entries())
	return result