class_name WaveManager
extends Node

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal all_waves_cleared

var current_enemy = 0
var current_wave = 0
var _pending_next_enemy := false

@onready var enemy_spawn_point: Marker3D = %EnemySpawnPoint

@export var waves: Array[WaveSequence]

var enemy_scene = preload("uid://ckvbsvfexndh8")

func _ready() -> void:
	CombatManager.enemy_died.connect(_on_enemy_died)
	CombatManager.player_attack_finished.connect(_on_player_attack_finished)
	start_next_wave()
	_spawn_current_enemy()

func _on_enemy_died(_enemy) -> void:
	if CombatManager.is_game_over:
		return
	_pending_next_enemy = true

func _on_player_attack_finished() -> void:
	if not _pending_next_enemy:
		return
	_pending_next_enemy = false
	_advance_and_spawn()

func _advance_and_spawn() -> void:
	current_enemy += 1
	if current_enemy >= waves[current_wave].enemies_list.size():
		current_enemy = 0
		wave_cleared.emit(current_wave + 1)
		current_wave += 1
		if current_wave >= waves.size():
			all_waves_cleared.emit()
			return
		start_next_wave()
	_spawn_current_enemy()

func start_next_wave() -> void:
	wave_started.emit(current_wave)
	print("next wave")
	pass


func _spawn_current_enemy() -> void:
	if waves.is_empty() or waves[current_wave].enemies_list.is_empty():
		push_warning("Brak fal lub wrogów w Wave Manager")
		return
		
	var enemy_def = waves[current_wave].enemies_list[current_enemy]
	
	if enemy_def:
		var enemy_inst = enemy_scene.instantiate()
		enemy_inst.definition = enemy_def
		
		enemy_spawn_point.add_child(enemy_inst)
		
		CombatManager.set_enemy(enemy_inst)
