class_name BonusDamageTrigger
extends AmountTriggerBase

@export var flat_damage: float = 10.0

func get_base_amount() -> float:
	return flat_damage

func apply(combat_manager, hit_data: Dictionary) -> void:
	var amount := get_amount(combat_manager, hit_data)
	var skill: SkillDefinition = hit_data["skill"]
	if hit_data.get("target") == "player":
		combat_manager._apply_damage_to_player(skill, int(round(amount)))
	else:
		combat_manager._apply_damage_to_enemy(skill, int(round(amount)))

func is_valid_for_enemy_cast() -> bool:
	return true

func get_effect_description() -> String:
	return describe_amount("Dmg")
