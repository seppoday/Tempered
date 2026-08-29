extends CharacterBody2D

var hp: float
var definition: EnemyDefinition

var target_position: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var direction := (target_position - global_position).normalized()
	velocity = direction * definition.movement_speed
	move_and_slide()

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		die()

func die() -> void:
	EventBus.enemy_died.emit(self, global_position)
	queue_free()

func setup(enemy_definition: EnemyDefinition, hp_multiplier: float) -> void:
	definition = enemy_definition
	# Inicjalizujemy HP przeciwnika na podstawie definicji
	if definition != null:
		hp = float(definition.max_hp * hp_multiplier)

func get_exp_reward() -> int:
	if definition == null:
		return 0

	return definition.exp_reward
