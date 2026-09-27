extends Node

signal state_changed(new_state: State)

enum State { # NA RAZIE NIC Z TEGO NIE JEST PODPIETE
	INTRO, 
	WEAPON_SELECT,
	PLAYER_TURN, 
	SELECTING,
	RESOLVING, 
	ENEMY_TURN, 
	WAVE_CLEARED, 
	GAME_OVER, 
	VICTORY }

var current_state: State = State.PLAYER_TURN

var gold: int = 0
var experience: int = 0
var level: int = 1

var current_wave: int = 0
var enemies_spawned_this_wave: int = 0
var enemies_killed_this_wave: int = 0

func _ready() -> void:
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.enemy_died.connect(_on_enemy_died)

func set_state(new_state: State, node: Node) -> void:
	current_state = new_state
	state_changed.emit(new_state)
	Log.print("Nowy state: %s, wywołany przez %s" % [current_state, node])

func _on_enemy_spawned(_enemy: Node2D) -> void:
	enemies_spawned_this_wave += 1

func _on_enemy_died(_enemy: Node2D, _death_position: Vector2) -> void:
	enemies_killed_this_wave += 1
