extends CharacterBody2D

var hp: float = 15.0
var max_hp: float = 15.0
var move_speed: float = 100.0

var target_position: Vector2 = Vector2.ZERO

# DoT
var fire_dps: float = 0.0
var poison_dps: float = 0.0
var poison_duration: float = 0.0
var dot_timer: float = 0.0

func _physics_process(delta: float) -> void:
	var direction := (target_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

# Otrzymywanie obrażeń
func take_damage(amount: float) -> void:
	hp -= amount
	
	# Jeśli HP spadnie do 0 lub poniżej -> wróg umiera
	if hp <= 0.0:
		die()

# Śmierć przeciwnika
func die() -> void:
	EventBus.enemy_died.emit(self, global_position)
	queue_free()
