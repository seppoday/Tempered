extends Node

enum State {
	WEAPON_SELECT,
	COMBAT,
	RESULTS
}

signal state_changed(new_state: State)

var current_state: State = State.WEAPON_SELECT

func set_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(new_state)