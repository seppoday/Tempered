class_name WaveManager
extends Node

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal all_waves_cleared

@onready var enemy: EnemyInstance = %Enemy

func _ready() -> void:
	CombatManager.set_enemy(enemy)

@export var waves: Array[Array]  # np. Array[Array[EnemyDefinition]]

func start_next_wave() -> void:
	pass
	
func _on_enemy_died() -> void:
	pass
