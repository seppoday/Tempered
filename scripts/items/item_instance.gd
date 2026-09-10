class_name ItemInstance extends RefCounted

enum UpgradeResult {
	SUCCESS,
	FAILURE,
	NO_CURVE,
	MAX_LEVEL_REACHED,
}

var definition: InventoryEntry
var quantity: int = 1
var slot_assignments: Dictionary = {}

func _init(item_definition: InventoryEntry, amount: int = 1, level: int = 0) -> void:
	definition = item_definition
	quantity = amount


func is_stackable() -> bool:
	return definition.stackable


func get_max_stack_size() -> int:
	return definition.max_stack_size

func attempt_upgrade() -> void:
	pass

	# TODO: Do przepisania na dice, ale chyba pójdziemy w upgrade zawsze 100% dla uproszczenia rozgrywki


func use() -> void:
	if definition is ConsumableDefinition:
		var consumable_def: ConsumableDefinition = definition as ConsumableDefinition
		var heal_hp: float = consumable_def.heal_hp

		if heal_hp > 0.0:
			# Heal the player
			PlayerData.heal(heal_hp)