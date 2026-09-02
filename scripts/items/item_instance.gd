class_name ItemInstance extends RefCounted

enum UpgradeResult {
	SUCCESS,
	FAILURE,
	NO_CURVE,
	MAX_LEVEL_REACHED,
}

var definition: InventoryEntry
var quantity: int = 1
var upgrade_level: int = 0


func _init(item_definition: InventoryEntry, amount: int = 1, level: int = 0) -> void:
	definition = item_definition
	quantity = amount
	upgrade_level = level


func is_stackable() -> bool:
	return definition.stackable


func get_max_stack_size() -> int:
	return definition.max_stack_size

func attempt_upgrade() -> UpgradeResult:
	if definition.upgrade_curve == null:
		return UpgradeResult.NO_CURVE

	var levels = definition.upgrade_curve.levels
	if upgrade_level >= levels.size():
		return UpgradeResult.MAX_LEVEL_REACHED

	var next_level :ItemUpgradeLevel = levels[upgrade_level]
	var chance :float = next_level.success_chance
	var roll :float = RNG.randf()
	if roll <= chance:
		upgrade_level += 1
		return UpgradeResult.SUCCESS
	else:
		return UpgradeResult.FAILURE