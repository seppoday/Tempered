class_name GainShieldTrigger
extends AmountTriggerBase

@export var shield_amount: float = 5.0

func get_base_amount() -> float:
	return shield_amount

func apply(combat_manager, hit_data: Dictionary) -> void:
	var amount := get_amount(combat_manager, hit_data)
	combat_manager._apply_shield_to_player(hit_data["skill"], int(round(amount)))

func get_effect_description() -> String:
	return describe_amount("Shield")
