class_name StatusManager extends RefCounted

signal status_applied(status: StatusEffect)
signal status_tick(status: StatusEffect, damage: int)
signal status_removed(status: StatusEffect)

var active_statuses: Array[StatusEffect] = []
const MAX_STACKS := 10

## Nakłada nowy status. Jeśli ten typ już istnieje:
## - Poison → dodaje stack (nie odświeża czasu)
## - Burn/Bleed → odświeża czas i bierze wyższy tick



## Nakłada status. Jeśli ten typ już jest: dodaje stacki (do MAX_STACKS) i bierze wyższy tick.
func apply_status(new_status: StatusEffect) -> void:
	for existing in active_statuses:
		if existing.status_type == new_status.status_type:
			existing.stacks = min(existing.stacks + new_status.stacks, MAX_STACKS)
			existing.tick_damage = max(existing.tick_damage, new_status.tick_damage)
			status_applied.emit(existing)
			return

	new_status.stacks = min(new_status.stacks, MAX_STACKS)
	active_statuses.append(new_status)
	status_applied.emit(new_status)
	Log.print("Nałożono %s x%d (tick: %.1f)" % [
		GameEnums.StatusType.keys()[new_status.status_type],
		new_status.stacks,
		new_status.tick_damage
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
