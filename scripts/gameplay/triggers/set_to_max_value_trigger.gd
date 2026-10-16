class_name SetToMaxValueTrigger
extends SkillTriggerBase

func is_pre_hit() -> bool:
	return true

func apply(combat_manager, hit_data: Dictionary) -> void:
	var skill: SkillDefinition = hit_data["skill"]
	var item_def: ItemDefinition = hit_data["item_def"]
	var context: Dictionary = hit_data["context"]
	hit_data["value"] = combat_manager.calculate_effect_value(skill, item_def, context["max_face"])

func get_effect_description() -> String:
	return "Max Roll Value"
