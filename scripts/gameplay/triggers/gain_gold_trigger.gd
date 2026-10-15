class_name GainGoldTrigger
extends AmountTriggerBase

@export var gold_amount: float = 1.0

func get_base_amount() -> float:
	return gold_amount

func apply(combat_manager, hit_data: Dictionary) -> void:
	var amount := get_amount(hit_data["value"])
	combat_manager._apply_gold_to_player(hit_data["skill"], int(round(amount)))

func get_effect_description() -> String:
	return "+Gold" if scale_with_hit_value else "+%s Gold" % format_amount(gold_amount)
