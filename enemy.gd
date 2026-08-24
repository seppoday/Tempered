extends CharacterBody2D

@export var exp_reward: int = 25  # EXP za tego wroga

var hp: float = 50.0
var max_hp: float = 50.0
var move_speed: float = 100.0

var target_position: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var direction := (target_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		die()

func die() -> void:
	EventBus.enemy_died.emit(self, global_position)
	queue_free()
