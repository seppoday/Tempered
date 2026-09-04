extends CharacterBody2D

var hp: float
var max_hp: float # Dodane dla spójności z mechaniką execute
var definition: EnemyDefinition
var _attack_timer: float = 0.0

var target_position: Vector2 = Vector2.ZERO

# --- BARDZO WAŻNA ZMIENNA OCHRONNA ---
var _is_spawn_protected: bool = true

func _ready() -> void:
	# Czekamy dokładnie 2 klatki fizyki, aż silnik zsynchronizuje 
	# pozycję przeciwnika na arenie i usunie jego "ducha" z punktu (0,0).
	await get_tree().physics_frame
	await get_tree().physics_frame
	_is_spawn_protected = false


func _physics_process(delta: float) -> void:
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
	print("Enemy attacking player for %f damage!" % definition.damage)
	if definition == null:
		return
	print("Enemy attacking player for %f damage!" % definition.damage)
	PlayerData.take_damage(definition.damage)

func take_damage(amount: float) -> void:
	# Jeśli wróg dopiero się narodził i fizyka go nie rozstawiła - ignoruj obrażenia!
	if _is_spawn_protected:
		return

	hp -= amount
	if hp <= 0.0:
		die()


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
