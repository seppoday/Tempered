class_name PermanentDamageBuffTrigger
extends AmountTriggerBase

@export var damage_bonus: float = 1.0

func get_base_amount() -> float:
	return damage_bonus

func apply(combat_manager, hit_data: Dictionary) -> void:
	var amount := get_amount(combat_manager, hit_data)
	combat_manager.permanent_damage_bonus += amount
	Log.print("Trwały bonus dmg: +%.1f (razem: %.1f)" % [amount, combat_manager.permanent_damage_bonus])

func get_effect_description() -> String:
	return describe_amount("Dmg (perm)")
