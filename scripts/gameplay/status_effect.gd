class_name StatusEffect extends RefCounted

var status_type: GameEnums.StatusType
var remaining_rounds: int
var tick_damage: float
var initial_damage: float
var stacks: int = 1


func _init(
	type: GameEnums.StatusType,
	duration: int,
	tick: float,
	initial: float = 0.0
) -> void:
	status_type = type
	remaining_rounds = duration
	tick_damage = tick
	initial_damage = initial


func get_total_tick_damage() -> float:
	return tick_damage * stacks


## Zmniejsza czas trwania o 1. Zwraca true jeśli wygasł.
func tick() -> bool:
	remaining_rounds -= 1
	return remaining_rounds <= 0


## Łączy stacki (dla Poison)
func add_stack(other: StatusEffect) -> void:
	stacks += other.stacks
