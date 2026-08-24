extends CharacterBody2D

@export var floating_text_scene: PackedScene  # Przypisz floating_text.tscn w edytorze!

@export var stab_distance: float = 10.0
@export var stab_duration: float = 0.15
@export var base_stab_interval: float = 0.5
@export var rotation_speed: float = 8.0

@onready var sword_hitbox: Area2D = $SwordHitbox

var current_target: Node2D = null
var base_distance: float
var current_angle: float = 0.0
var stab_extension: float = 0.0

var enemies_in_range: Array[Node2D] = []

func _ready() -> void:
	base_distance = sword_hitbox.position.length()
	current_angle = sword_hitbox.position.angle()

	sword_hitbox.body_entered.connect(_on_sword_body_entered)
	sword_hitbox.body_exited.connect(_on_sword_body_exited)

	_perform_stab_cycle()

func _physics_process(delta: float) -> void:
	_update_target()
	_face_target(delta)
	_update_sword_position()

func _update_target() -> void:
	if current_target != null and is_instance_valid(current_target):
		return
	current_target = _find_nearest_enemy()

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _face_target(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	var target_angle := (current_target.global_position - global_position).angle()
	current_angle = lerp_angle(current_angle, target_angle, rotation_speed * delta)

func _update_sword_position() -> void:
	var distance := base_distance + stab_extension
	sword_hitbox.position = Vector2.RIGHT.rotated(current_angle) * distance
	sword_hitbox.rotation = current_angle

# ==========================================
# ZARZĄDZANIE LISTĄ WROGÓW
# ==========================================

func _on_sword_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		var enemy := body as Node2D
		if not enemy in enemies_in_range:
			enemies_in_range.append(enemy)

func _on_sword_body_exited(body: Node) -> void:
	if body is Node2D and body in enemies_in_range:
		enemies_in_range.erase(body)

func _clean_enemies_in_range() -> void:
	var valid_enemies: Array[Node2D] = []
	for enemy in enemies_in_range:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			valid_enemies.append(enemy)
	enemies_in_range = valid_enemies

# ==========================================
# PĘTLA ATAKU, ATTACK RANGE & EXECUTE
# ==========================================

func _perform_stab_cycle() -> void:
	var stats := PlayerData.get_total_stats()
	
	# 1. POBIERAMY ATTACK RANGE (skaluje dystans pchnięcia miecza)
	var attack_range: float = stats.get("attack_range", 1.0)
	var actual_stab_distance: float = stab_distance * attack_range

	var tween := create_tween()
	
	# Pchnięcie do przodu
	tween.tween_method(_set_stab_extension, 0.0, actual_stab_distance, stab_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Zadanie obrażeń w szczytowym momencie pchnięcia
	tween.tween_callback(_deal_damage_to_enemies_in_range)

	# Powrót miecza
	tween.tween_method(_set_stab_extension, actual_stab_distance, 0.0, stab_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Obliczenie przerwy na podstawie Attack Speed
	var attack_speed: float = stats.get("attack_speed", 1.0)
	attack_speed = maxf(0.1, attack_speed)
	var current_interval: float = base_stab_interval / attack_speed

	tween.tween_interval(current_interval)
	tween.tween_callback(_perform_stab_cycle)

func _set_stab_extension(value: float) -> void:
	stab_extension = value

func _deal_damage_to_enemies_in_range() -> void:
	_clean_enemies_in_range()

	if enemies_in_range.is_empty():
		return

	var stats := PlayerData.get_total_stats()
	var max_targets: int = stats.get("target_count", 1)
	var execute_threshold: float = stats.get("execute_threshold", 0.0) # np. 0.10 (10%)
	var hit_count := 0

	var current_targets := enemies_in_range.duplicate()

	for enemy in current_targets:
		if hit_count >= max_targets:
			break
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue

		# 1. Wyliczenie podstawowego ataku
		var attack_info: Dictionary = PlayerData.calculate_attack()
		var damage: int = attack_info["damage"]
		var is_crit: bool = attack_info["is_crit"]
		var text_color: Color = attack_info["color"]

		# 2. Zadanie obrażeń
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)

		var display_str := str(damage) + ("!" if is_crit else "")
		_spawn_floating_text(enemy.global_position, display_str, text_color)

		# 3. SPRAWDZANIE EXECUTE (< 10% HP)
		if execute_threshold > 0.0 and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			if "hp" in enemy and "max_hp" in enemy and enemy.max_hp > 0.0:
				var hp_percent: float = enemy.hp / enemy.max_hp
				if hp_percent > 0.0 and hp_percent <= execute_threshold:
					# Pokazujemy fioletowy napis "EXECUTE!" kawałek wyżej
					_spawn_floating_text(enemy.global_position + Vector2(0, -10), "EXECUTE!", Color(0.75, 0.2, 0.95))
					enemy.die()

		hit_count += 1

func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	if floating_text_scene == null:
		return

	var text_node := floating_text_scene.instantiate()
	get_tree().current_scene.add_child(text_node)
	text_node.global_position = pos
	text_node.setup(text, color)
