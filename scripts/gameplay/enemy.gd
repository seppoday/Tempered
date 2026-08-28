extends CharacterBody2D

var hp: float
var definition: EnemyDefinition
var max_hp: float

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

func setup(enemy_definition: EnemyDefinition) -> void:
	definition = enemy_definition
	# Inicjalizujemy HP przeciwnika na podstawie definicji
	if definition != null:
		max_hp = float(definition.max_hp)
		hp = max_hp

func get_exp_reward() -> int:
	return definition.exp_reward