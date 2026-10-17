class_name ExecuteTrigger
extends AmountTriggerBase

## true: zabija wroga na miejscu (obrażenia = pozostałe HP, bez pancerza).
## Pola ilości (bonus_damage, hit_value_ratio, stat_scalings) są wtedy ignorowane.
@export var kills_target: bool = false
@export var bonus_damage: float = 50.0

func get_base_amount() -> float:
	return bonus_damage

func apply(combat_manager, hit_data: Dictionary) -> void:
	if hit_data.get("enemy_died", false):
		return   # cios już zabił — nie ma kogo egzekwować
	if kills_target:
		combat_manager._kill_enemy(hit_data["skill"])
		return
	var amount := get_amount(combat_manager, hit_data)
	combat_manager._apply_damage_to_enemy(hit_data["skill"], int(round(amount)))

func get_effect_description() -> String:
	if kills_target:
		return "Execute: Kill"
	return "Execute: " + describe_amount("Dmg")
