extends Node

signal state_changed(new_state: State)

enum State { 
	INTRO, 
	WEAPON_SELECT,
	PLAYER_TURN, 
	RESOLVING, 
	ENEMY_TURN, 
	WAVE_CLEARED, 
	GAME_OVER, 
	VICTORY }

var current_state: State = State.WEAPON_SELECT

# Ekonomia
var gold: int = 0
var exp: int = 0
var level: int = 1

# Stan fali
var current_wave: int = 0
var enemies_spawned_this_wave: int = 0
var enemies_killed_this_wave: int = 0

func _ready() -> void:
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.enemy_died.connect(_on_enemy_died)

func set_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(new_state)

func _on_enemy_spawned(enemy: Node2D) -> void:
	enemies_spawned_this_wave += 1

func _on_enemy_died(enemy: Node2D, death_position: Vector2) -> void:
	enemies_killed_this_wave += 1
