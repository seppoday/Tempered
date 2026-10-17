class_name GainGoldTrigger
extends AmountTriggerBase

@export var gold_amount: float = 1.0

func get_base_amount() -> float:
	return gold_amount

func apply(combat_manager, hit_data: Dictionary) -> void:
	var amount := get_amount(combat_manager, hit_data)
	combat_manager._apply_gold_to_player(hit_data["skill"], int(round(amount)))

func get_effect_description() -> String:
	return describe_amount("Gold")
