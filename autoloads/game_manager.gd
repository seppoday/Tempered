extends Node

# --- Ekonomia / progresja (na razie placeholdery, bez UI-podpięcia) ---
var gold: int = 0
var exp: int = 0
var level: int = 1

# --- Stan fali ---
var current_wave: int = 0
var enemies_spawned_this_wave: int = 0
var enemies_killed_this_wave: int = 0

func _ready() -> void:
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.enemy_died.connect(_on_enemy_died)

func _on_enemy_spawned(enemy: Node2D) -> void:
	enemies_spawned_this_wave += 1
	print("[GameManager] enemy spawned: ", enemy.name, " (total this wave: ", enemies_spawned_this_wave, ")")

func _on_enemy_died(enemy: Node2D, death_position: Vector2) -> void:
	enemies_killed_this_wave += 1
	print("[GameManager] enemy died at ", death_position, " (killed this wave: ", enemies_killed_this_wave, "/", enemies_spawned_this_wave, ")")