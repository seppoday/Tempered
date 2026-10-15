class_name GainShieldTrigger
extends AmountTriggerBase

@export var shield_amount: float = 5.0

func get_base_amount() -> float:
	return shield_amount

func apply(combat_manager, hit_data: Dictionary) -> void:
	var amount := get_amount(hit_data["value"])
	combat_manager._apply_shield_to_player(hit_data["skill"], int(round(amount)))

func get_effect_description() -> String:
	return "+Shield" if scale_with_hit_value else "+%s Shield" % format_amount(shield_amount)
