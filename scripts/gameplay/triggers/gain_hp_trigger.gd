class_name GainHpTrigger
extends AmountTriggerBase

@export var heal_amount: float = 5.0

func get_base_amount() -> float:
	return heal_amount

func apply(combat_manager, hit_data: Dictionary) -> void:
	var amount := get_amount(hit_data["value"])
	combat_manager._apply_heal_to_player(hit_data["skill"], int(round(amount)))

func get_effect_description() -> String:
	return "+HP" if scale_with_hit_value else "+%s HP" % format_amount(heal_amount)
