class_name Health
extends RefCounted

signal changed(current: int, max_hp: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

var current: int:
	set(value):
		var clamped := clampi(value, 0, max_hp)
		if clamped == current:
			return
		current = clamped
		changed.emit(current, max_hp)
		if current <= 0:
			died.emit()

var max_hp: int

func _init(starting_max_hp: int) -> void:
	max_hp = starting_max_hp
	current = starting_max_hp

func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	current -= amount
	damaged.emit(amount)

func heal(amount: int) -> void:
	if amount <= 0:
		return
	current += amount
	healed.emit(amount)

func set_max_hp(new_max: int, heal_to_full: bool = false) -> void:
	max_hp = new_max
	if heal_to_full:
		current = max_hp
	else:
		current = current  # re-clamp przez setter, gdyby nowy max był niższy

func is_dead() -> bool:
	return current <= 0

func percentage() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current) / float(max_hp)
