class_name StatusManager extends RefCounted

signal status_applied(status: StatusEffect)
signal status_tick(status: StatusEffect, damage: int)
signal status_removed(status: StatusEffect)

var active_statuses: Array[StatusEffect] = []


## Nakłada nowy status. Jeśli ten typ już istnieje:
## - Poison → dodaje stack (nie odświeża czasu)
## - Burn/Bleed → odświeża czas i bierze wyższy tick
func apply_status(new_status: StatusEffect) -> void:
	for existing in active_statuses:
		if existing.status_type == new_status.status_type:
			if new_status.status_type == GameEnums.StatusType.POISON:
				existing.add_stack(new_status)
				Log.print("Poison stack! Teraz %d stacków" % existing.stacks)
			else:
				existing.remaining_rounds = max(
					existing.remaining_rounds,
					new_status.remaining_rounds
				)
				existing.tick_damage = max(
					existing.tick_damage,
					new_status.tick_damage
				)
			status_applied.emit(existing)
			return

	active_statuses.append(new_status)
	status_applied.emit(new_status)
	Log.print("Nałożono %s na %d rund (tick: %.1f)" % [
		GameEnums.StatusType.keys()[new_status.status_type],
		new_status.remaining_rounds,
		new_status.get_total_tick_damage()
	])


## Tickuje wszystkie aktywne statusy. Zwraca listę obrażeń do zadania.
## Wywołaj na końcu tury gracza.
func tick_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for status in active_statuses:
		var dmg := int(round(status.get_total_tick_damage()))
		if dmg > 0:
			results.append({
				"type": status.status_type,
				"damage": dmg
			})
			status_tick.emit(status, dmg)

	# Zmniejsz duration i zbierz wygasłe
	var expired: Array[StatusEffect] = []
	for status in active_statuses:
		if status.tick():
			expired.append(status)

	for status in expired:
		active_statuses.erase(status)
		status_removed.emit(status)
		Log.print("Status %s wygasł" % GameEnums.StatusType.keys()[status.status_type])

	return results


func has_status(type: GameEnums.StatusType) -> bool:
	for s in active_statuses:
		if s.status_type == type:
			return true
	return false


func get_status(type: GameEnums.StatusType) -> StatusEffect:
	for s in active_statuses:
		if s.status_type == type:
			return s
	return null


func clear_all() -> void:
	active_statuses.clear()
