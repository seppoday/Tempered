# reduce_next_picks_trigger.gd — TYMCZASOWY DEBUG
class_name ReduceNextPicksTrigger
extends SkillTriggerBase

@export var picks_to_remove: int = 1

func apply(combat_manager, hit_data: Dictionary) -> void:
	var skill: SkillDefinition = hit_data.get("skill")
	var skill_id := skill.id if skill != null else "UNKNOWN"
	Log.print("⚠️ ReduceNextPicksTrigger.apply() ODPALIŁ SIĘ dla skilla: %s (resource_path tego triggera: %s)" % [skill_id, resource_path])
	PlayerData.pending_picks_penalty += picks_to_remove

func get_effect_description() -> String:
	return "-%d Picks" % picks_to_remove
