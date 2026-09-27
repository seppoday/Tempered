# wave_manager.gd
class_name WaveManager
extends Node

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal all_waves_cleared

var current_enemy_index = 0
var current_wave = 0

@onready var enemy_spawn_point: Marker3D = %EnemySpawnPoint

@export var waves: Array[WaveSequence]

var enemy_scene = preload("uid://ckvbsvfexndh8")


func _ready() -> void:
	start_next_wave()
	_spawn_current_enemy()


## Wywoływane jawnie z zewnątrz (np. przycisk "Next enemy" w ekwipunku),
## nigdy automatycznie po śmierci wroga.
func request_next_enemy() -> void:
	_advance_and_spawn()


func _advance_and_spawn() -> void:
	current_enemy_index += 1
	if current_enemy_index >= waves[current_wave].enemies_list.size():
		current_enemy_index = 0
		wave_cleared.emit(current_wave + 1)
		current_wave += 1
		if current_wave >= waves.size():
			all_waves_cleared.emit()
			return
		start_next_wave()
	_spawn_current_enemy()


func start_next_wave() -> void:
	wave_started.emit(current_wave)


func _spawn_current_enemy() -> void:
	if waves.is_empty() or waves[current_wave].enemies_list.is_empty():
		Log.warning("Brak fal lub wrogów w Wave Manager")
		return

	var enemy_def = waves[current_wave].enemies_list[current_enemy_index]
	if enemy_def:
		var enemy_inst = enemy_scene.instantiate()
		enemy_inst.definition = enemy_def
		enemy_spawn_point.add_child(enemy_inst)
		CombatManager.set_enemy(enemy_inst)
