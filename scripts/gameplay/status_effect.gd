class_name StatusEffect extends RefCounted

var status_type: GameEnums.StatusType
var tick_damage: float
var initial_damage: float
var stacks: int


func _init(
	type: GameEnums.StatusType,
	stack_count: int,
	tick: float,
	initial: float = 0.0
) -> void:
	status_type = type
	stacks = stack_count
	tick_damage = tick
	initial_damage = initial


## Obrażenia na najbliższy tick (tick_damage × liczba stacków).
func get_total_tick_damage() -> float:
	return tick_damage * stacks


## Po każdym ticku status traci 1 stack. Zwraca true, jeśli wygasł.
func tick() -> bool:
	stacks -= 1
	return stacks <= 0
