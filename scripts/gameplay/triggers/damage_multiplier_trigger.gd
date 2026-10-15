class_name DamageMultiplierTrigger
extends SkillTriggerBase

@export var multiplier: float = 2.0   # 2.0 = ×200%

func is_pre_hit() -> bool:
	return true

func apply(combat_manager, hit_data: Dictionary) -> void:
	hit_data["value"] *= multiplier

func get_effect_description() -> String:
	return "×%s Dmg" % format_amount(multiplier)

func is_valid_for_enemy_cast() -> bool:
	return true
