# execute_trigger.gd
class_name ExecuteTrigger
extends AmountTriggerBase

@export var bonus_damage: float = 50.0

func get_base_amount() -> float:
	return bonus_damage

func apply(combat_manager, hit_data: Dictionary) -> void:
	if hit_data.get("enemy_died", false):
		return   # cios już zabił — nie ma kogo egzekwować
	combat_manager._apply_damage_to_enemy(hit_data["skill"], int(round(get_amount(hit_data["value"]))))
func get_effect_description() -> String:
	return "Execute: +%s Dmg" % format_amount(bonus_damage)
