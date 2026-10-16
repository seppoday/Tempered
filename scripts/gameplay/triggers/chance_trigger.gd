## Owija inny trigger w "% szansy". Warunek (trigger_type/threshold), koszt HP oraz
## apply_status/status_stacks są brane Z TEGO wrappera (nie z inner_trigger) i wszystkie
## podlegają losowaniu. Z inner_trigger liczy się tylko efekt: apply() i is_pre_hit().
class_name ChanceTrigger
extends SkillTriggerBase

@export_range(0.0, 1.0, 0.01) var chance: float = 0.5
@export var inner_trigger: SkillTriggerBase

func is_pre_hit() -> bool:
	return inner_trigger != null and inner_trigger.is_pre_hit()

func is_valid_for_enemy_cast() -> bool:
	return inner_trigger != null and inner_trigger.is_valid_for_enemy_cast()

func should_fire(hit_data: Dictionary) -> bool:
	if inner_trigger == null and apply_status == GameEnums.StatusType.NONE:
		return false
	if RNG.randf() >= chance:
		return false
	return inner_trigger == null or inner_trigger.should_fire(hit_data)

func apply(combat_manager, hit_data: Dictionary) -> void:
	if inner_trigger != null:
		inner_trigger.apply(combat_manager, hit_data)

func get_effect_description() -> String:
	var pct := "%d%% chance" % int(round(chance * 100.0))
	var inner_desc := inner_trigger.get_effect_description() if inner_trigger != null else ""
	return pct if inner_desc == "" else "%s: %s" % [pct, inner_desc]
