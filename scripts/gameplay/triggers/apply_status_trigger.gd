class_name ApplyStatusTrigger
extends SkillTriggerBase

## Trigger "tylko status": nie ma własnego efektu liczbowego.
## Cała robota to apply_status / status_stacks z klasy bazowej,
## które CombatManager nakłada po apply().

func is_valid_for_enemy_cast() -> bool:
	return true

func get_effect_description() -> String:
	return ""
