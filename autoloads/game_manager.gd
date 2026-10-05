extends Node

signal state_changed(new_state: State)

enum State {
	INTRO, 
	PAUSED,
	PLAYER_TURN, 
	WEAPON_SELECT,
	ENEMY_REWARDS,
	WAVE_REWARD,
	SELECTING,
	RESOLVING, 
	ENEMY_TURN, 
	WAVE_CLEARED, 
	GAME_OVER,
	DEFEAT_SUMMARY,
	META_PROGRESSION,
	MAIN_MENU,
	TUTORIAL,
	VICTORY 
}

var current_state: State = State.PLAYER_TURN

func set_state(new_state: State, node: Node) -> void:
	current_state = new_state
	state_changed.emit(new_state)
	Log.print("Nowy state: %s, wywołany przez %s" % [State.keys()[new_state], node])

# TODO: Można w przyszłości dodać can_transition_to...
