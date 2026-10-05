extends Node

signal gold_changed(new_amount: int)
signal item_unlocked(item_id: String)

const SAVE_PATH := "user://meta_progression.save"

var gold: int = 0
var unlocked_item_ids: Array[String] = []
var starting_loadout_ids: Array[String] = ["berserker_cleaver", "healers_amulet", "iron_ring"]


func _ready() -> void:
	load_from_disk()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	save_to_disk()


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	save_to_disk()
	return true


func unlock_item(item_id: String) -> void:
	if item_id in unlocked_item_ids:
		return
	unlocked_item_ids.append(item_id)
	item_unlocked.emit(item_id)
	save_to_disk()


func is_item_unlocked(item_id: String) -> bool:
	return item_id in unlocked_item_ids


func get_starting_loadout() -> Array[String]:
	return starting_loadout_ids


func save_to_disk() -> void:
	var data := {
		"gold": gold,
		"unlocked_item_ids": unlocked_item_ids,
		"starting_loadout_ids": starting_loadout_ids,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data == null:
		return

	gold = data.get("gold", 0)
	unlocked_item_ids.assign(data.get("unlocked_item_ids", []))
	starting_loadout_ids.assign(data.get("starting_loadout_ids", ["rusty_sword", "iron_shield"]))
