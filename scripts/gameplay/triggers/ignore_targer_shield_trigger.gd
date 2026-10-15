class_name IgnoreTargetShieldTrigger
extends SkillTriggerBase

func is_pre_hit() -> bool:
	return true

func apply(combat_manager, hit_data: Dictionary) -> void:
	hit_data["ignore_shield"] = true

func get_effect_description() -> String:
	return "Ignore Shield"

func is_valid_for_enemy_cast() -> bool:
	return true
