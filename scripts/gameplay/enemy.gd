extends Node2D

var hp: float
var max_hp: float
var definition: EnemyDefinition
var active_statuses: Array[Dictionary] = []

@onready var sprite: Sprite2D = $Sprite2D

func setup(enemy_definition: EnemyDefinition, hp_multiplier: float) -> void:
	definition = enemy_definition
	max_hp = float(definition.max_hp * hp_multiplier)
	hp = max_hp

func take_damage(amount: float) -> void:
	_flash()
	hp -= amount
	if hp <= 0.0:
		die()

func apply_status(damage_per_round: float, rounds: int) -> void:
	active_statuses.append({"remaining": rounds, "damage": damage_per_round})

func tick_statuses() -> void:
	for status in active_statuses.duplicate():
		if hp <= 0.0:
			return
		take_damage(status["damage"])
		status["remaining"] -= 1
		if status["remaining"] <= 0:
			active_statuses.erase(status)

func perform_attack_on_player() -> void:
	PlayerData.take_damage(definition.damage)

func is_dead() -> bool:
	return hp <= 0.0 or is_queued_for_deletion()

func die() -> void:
	EventBus.enemy_died.emit(self, global_position)
	queue_free()

func _flash() -> void:
	if sprite.material == null:
		return
	sprite.material.set_shader_parameter("flash_amount", 1.0)
	var tween := get_tree().create_tween()
	tween.tween_method(func(v): sprite.material.set_shader_parameter("flash_amount", v), 1.0, 0.0, 0.2)
