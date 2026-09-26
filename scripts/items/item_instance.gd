class_name ItemInstance
extends RefCounted

enum UpgradeResult {
	SUCCESS,
	WRONG_DIE,
	MAX_LEVEL_REACHED,
}

var definition: InventoryEntry
var quantity: int = 1
var slot_assignments: Dictionary = {}
var dice_level: int = 0

func _init(item_definition: InventoryEntry, amount: int = 1, level: int = 0) -> void:
	definition = item_definition
	quantity = amount
	dice_level = level


func is_stackable() -> bool:
	return definition.stackable


func get_max_stack_size() -> int:
	return definition.max_stack_size

func attempt_upgrade(dice_item: MaterialDefinition) -> UpgradeResult:
	if dice_level >= GameEnums.DICE_PROGRESSION.size() - 1:
		return UpgradeResult.MAX_LEVEL_REACHED

	if dice_item.dice_index != dice_level + 1:
		return UpgradeResult.WRONG_DIE

	dice_level += 1
	return UpgradeResult.SUCCESS

func roll_skill() -> Dictionary:
	if not definition is ItemDefinition:
		Log.error("ItemInstance.roll_skill(): definition nie jest ItemDefinition (%s)" % definition)
		return {}

	var item_def := definition as ItemDefinition
	var max_face: int = GameEnums.DICE_PROGRESSION[dice_level]
	var face: int = RNG.randi_range(1, max_face)
	var slot: int = RNG.randi_range(1, 6) # 6 Slotów na skille na każdym itemie
	var skill: SkillDefinition = slot_assignments.get(slot, item_def.default_skill)

	if skill == null:
		Log.error("ItemInstance.roll_skill(): brak skilla dla ścianki %d i brak default_skill w '%s'" % [face, item_def.name])
		return {}

	return {
		"face": face,
		"skill": skill,
		"slot": slot,
		"dice_level_on_item": max_face,
	}

func use() -> void:
	if definition is ConsumableDefinition:
		var consumable_def: ConsumableDefinition = definition as ConsumableDefinition
		var heal_hp: float = consumable_def.heal_hp

		if heal_hp > 0.0:
			PlayerData.health.heal(heal_hp)
