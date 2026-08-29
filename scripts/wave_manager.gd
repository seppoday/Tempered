class_name WaveManager extends Node

signal enemy_spawn_requested(enemy_definition: EnemyDefinition, hp_multiplier: float)
signal wave_completed

var current_wave: WaveDefinition = null
var _time_remaining: float = 0.0
var _spawn_timer: float = 0.0

func start_wave(wave_definition: WaveDefinition) -> void:
	current_wave = wave_definition
	_time_remaining = current_wave.duration
	_spawn_timer = 0.0

func _process(delta: float) -> void:
	if current_wave == null:
		return

	_time_remaining -= delta
	if _time_remaining <= 0.0:
		wave_completed.emit()
		current_wave = null
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 1.0 / current_wave.spawn_rate
		_try_spawn()

func _try_spawn() -> void:
	var wave_enemy_entry: WaveEnemyEntry = RNG.weighted_pick(current_wave.enemies)

	if wave_enemy_entry == null:
		return

	enemy_spawn_requested.emit(wave_enemy_entry.enemy, current_wave.hp_multiplier)
