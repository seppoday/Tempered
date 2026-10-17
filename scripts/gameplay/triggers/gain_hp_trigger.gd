class_name GainHpTrigger
extends AmountTriggerBase

@export var heal_amount: float = 5.0

func get_base_amount() -> float:
	return heal_amount

func apply(combat_manager, hit_data: Dictionary) -> void:
	var amount := get_amount(combat_manager, hit_data)
	combat_manager._apply_heal_to_player(hit_data["skill"], int(round(amount)))

func get_effect_description() -> String:
	return describe_amount("HP")
