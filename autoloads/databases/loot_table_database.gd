extends Node

var _resource_database:= ResourceDatabase.new()

func _ready() -> void:
	# Przykład użycia ResourceDatabase
	_resource_database.load_folder("res://resources/loot_tables", LootTable)

func get_loot_table(id: String) -> LootTable:
	return _resource_database.get_entry(id)