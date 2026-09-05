extends CharacterBody2D

var hp: float
var max_hp: float # Dodane dla spójności z mechaniką execute
var definition: EnemyDefinition
var _attack_timer: float = 0.0

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

const KNOCKBACK_DURATION: float = 0.1
const KNOCKBACK_STRENGTH: float = 50


var target_position: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D

# --- BARDZO WAŻNA ZMIENNA OCHRONNA ---
var _is_spawn_protected: bool = true

func _ready() -> void:
	# Czekamy dokładnie 2 klatki fizyki, aż silnik zsynchronizuje 
	# pozycję przeciwnika na arenie i usunie jego "ducha" z punktu (0,0).
	await get_tree().physics_frame
	await get_tree().physics_frame
	_is_spawn_protected = false

	$Label.text = definition.id

func _physics_process(delta: float) -> void:
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity = knockback_velocity
		move_and_slide()
		return

	var distance_to_target := global_position.distance_to(target_position)

	# Ruch tylko wtedy, gdy wróg jest poza zasięgiem ataku
	if distance_to_target > definition.attack_range:
		var direction := (target_position - global_position).normalized()
		velocity = direction * definition.movement_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO # Zatrzymaj się w zasięgu ataku
		
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = definition.attack_interval
			_perform_attack()


func _perform_attack() -> void:
	if definition == null:
		return

	PlayerData.take_damage(definition.damage)


func take_damage(amount: float) -> void:
	# Jeśli wróg dopiero się narodził i fizyka go nie rozstawiła - ignoruj obrażenia!
	if _is_spawn_protected:
		return

	_flash()

	knockback_velocity = (global_position - target_position).normalized() * KNOCKBACK_STRENGTH
	knockback_timer = KNOCKBACK_DURATION

	hp -= amount
	if hp <= 0.0:
		die()

func _flash() -> void:
	sprite.material.set_shader_parameter("flash_amount", 1.0)
	var tween = get_tree().create_tween()
	tween.tween_method(
		func(value): sprite.material.set_shader_parameter("flash_amount", value), 1.0, 0.0, 0.2
	)

func is_dead() -> bool:
	return hp <= 0.0 or is_queued_for_deletion()


func die() -> void:
	EventBus.enemy_died.emit(self, global_position)
	queue_free()


func setup(enemy_definition: EnemyDefinition, hp_multiplier: float) -> void:
	definition = enemy_definition
	if definition != null:
		max_hp = float(definition.max_hp * hp_multiplier)
		hp = max_hp


func get_exp_reward() -> int:
	if definition == null:
		return 0

	return definition.exp_reward
