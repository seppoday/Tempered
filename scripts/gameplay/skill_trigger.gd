class_name SkillTrigger extends Resource

## Typ warunku aktywacji
@export var trigger_type: GameEnums.TriggerType = GameEnums.TriggerType.NONE

## Próg procentowy (używany przez ON_HIGH_ROLL, ON_LOW_HP, EXECUTE)
## Np. 0.75 = top 25% kości, 0.30 = poniżej 30% HP, 0.25 = cel poniżej 25% HP
@export_range(0.0, 1.0, 0.01) var threshold: float = 0.0

## Status do nałożenia (używany przez ON_HIT, ON_HIGH_ROLL, ON_MAX_ROLL)
@export var apply_status: GameEnums.StatusType = GameEnums.StatusType.BURN

## Ile stacków statusu nałożyć (domyślnie 1, Venom Cascade daje 2)
@export var status_stacks: int = 1

## Mnożnik base_value gdy trigger się odpala (dla EXECUTE, ON_LOW_HP, ON_MAX_ROLL)
## 0.0 = brak modyfikacji, 2.0 = podwójne base_value
@export var base_value_override: float = 0.0


## Sprawdza czy trigger powinien się odpalić w danym kontekście
func should_activate(context: Dictionary) -> bool:
	match trigger_type:
		GameEnums.TriggerType.NONE:
			return false

		GameEnums.TriggerType.ON_HIT:
			# Zawsze się odpala przy trafieniu
			return true

		GameEnums.TriggerType.ON_HIGH_ROLL:
			# Rzut >= threshold * max_face (np. 0.75 * 8 = 6, czyli 6-8 na d8)
			var face: int = context.get("face", 0)
			var max_face: int = context.get("max_face", 1)
			return face >= int(ceil(max_face * threshold))

		GameEnums.TriggerType.ON_MAX_ROLL:
			# Rzut == max ścianki
			var face: int = context.get("face", 0)
			var max_face: int = context.get("max_face", 1)
			return face == max_face

		GameEnums.TriggerType.ON_LOW_HP:
			# HP castera (gracza) < threshold * max_hp
			var hp_ratio: float = context.get("caster_hp_ratio", 1.0)
			return hp_ratio < threshold

		GameEnums.TriggerType.EXECUTE:
			# HP celu < threshold * max_hp
			var target_hp_ratio: float = context.get("target_hp_ratio", 1.0)
			return target_hp_ratio < threshold

	return false
