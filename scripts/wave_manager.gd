class_name WaveManager extends Node

signal enemy_spawn_requested(enemy_definition: EnemyDefinition, hp_multiplier: float)
signal wave_completed
signal sequence_completed

var current_wave: WaveDefinition = null
var current_sequence: WaveSequence = null
var _time_remaining: float = 0.0
var _spawn_timer: float = 0.0
var _sequence_index: int = -1

func start_wave(wave_definition: WaveDefinition) -> void:
	current_wave = wave_definition
	_time_remaining = current_wave.duration
	_spawn_timer = 0.0

func start_sequence(sequence: WaveSequence) -> void:
	current_sequence = sequence
	_sequence_index = -1
	advance_to_next_wave()

# Publiczna, bo teraz woła ją EKRAN WYNIKÓW (z zewnątrz), nie ta klasa sama siebie.
func advance_to_next_wave() -> void:
	_sequence_index += 1
	if current_sequence == null or _sequence_index >= current_sequence.waves.size():
		sequence_completed.emit()
		current_sequence = null
		current_wave = null
		return

	start_wave(current_sequence.waves[_sequence_index])

func _process(delta: float) -> void:
	if current_wave == null:
		return

	_time_remaining -= delta
	if _time_remaining <= 0.0:
		current_wave = null  # zatrzymuje _process, dopóki ktoś nie zawoła advance_to_next_wave()
		wave_completed.emit()
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