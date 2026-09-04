extends CharacterBody2D

@export var floating_text_scene: PackedScene

@export_group("Swing Settings")
@export var swing_arc_deg: float = 120.0       # Kąt zamachu w stopniach
@export var swing_extension_max: float = 18.0  # Max wysunięcie miecza
@export var swing_duration: float = 0.2        # Czas trwania jednego zamachu
@export var base_swing_interval: float = 0.45  # Przerwa między zamachami
@export var rotation_speed: float = 10.0       # Szybkość obracania się do wroga
@export var attack_range_margin: float = 50.0  # Dodatkowy margines na promień wroga/hitboxa

@onready var sword_hitbox: Area2D = $SwordHitbox

var current_target: Node2D = null
var base_distance: float
var current_angle: float = 0.0

# Zmienne animowane przez Tween:
var swing_arc_offset: float = 0.0
var swing_extension: float = 0.0
var is_swing_left_to_right: bool = true
var is_swinging: bool = false                  # Czy trwa animacja / cooldown zamachu

var _anim_start_angle: float = 0.0
var _anim_end_angle: float = 0.0
var _anim_max_ext: float = 0.0

# Pamięta TYLKO wrogów trafionych w obecnym zamachu
var starting_weapon_id: String 

var enemies_hit_this_swing: Array[Node2D] = []

# --- FLAGA BLOKADY WALKI NA STARCIU ---
var _combat_active: bool = false

func _ready() -> void:
	# 1. Wypisanie receptur
	var all_recipes := RecipeDatabase.get_all_recipes()
	print("Liczba przepisów: ", all_recipes.size())
	for r in all_recipes:
		print(" - ", r.id)

	starting_weapon_id = PlayerData.character_definition.starting_weapon_id
	base_distance = sword_hitbox.position.length()
	current_angle = sword_hitbox.position.angle()

	# 2. Natychmiastowe wyłączenie kolizji miecza na starcie gry
	var collision_shape := sword_hitbox.get_node("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = true

	# 3. Wyposażenie broni startowej
	var item_def = ItemDatabase.get_item_definition(starting_weapon_id)
	if item_def != null:
		var instance := ItemInstance.new(item_def)
		print("Equipping starting weapon: ", item_def.name)
		PlayerData.equip_item(instance)
		print("Starting weapon equipped: ", instance.definition.name)
		print(instance.definition.dmg)

	# 4. Odpalenie opóźnienia walki w tle
	_enable_combat_delayed()


func _enable_combat_delayed() -> void:
	await get_tree().create_timer(1.0).timeout
	
	var collision_shape := sword_hitbox.get_node("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = false
		
	_combat_active = true
	# Nie wywołujemy pętli na sztywno – zajmie się tym _physics_process, gdy wróg będzie w zasięgu


func _physics_process(delta: float) -> void:
	# Szukamy celu i sprawdzamy czy możemy zaatakować, gdy miecz NIE jest w trakcie zamachu
	if not is_swinging:
		_update_target()
		
		# Jeśli walka jest aktywna i cel jest w zasięgu – odpalamy zamach
		if _combat_active and _is_target_in_range():
			_perform_swing_cycle()
		
	_face_target(delta)
	_update_sword_position()

	# Gdy miecz jest w trakcie ruchu wysuwania, aktywnie zadajemy obrażenia
	if _combat_active and swing_extension > 1.0:
		_deal_damage_to_overlapping_enemies()

# ==========================================
# SPRAWDZANIE ZASIĘGU
# ==========================================

func _is_target_in_range() -> bool:
	if current_target == null or not is_instance_valid(current_target):
		return false

	var stats := PlayerData.get_total_stats()
	var attack_range_stat: float = stats.get("attack_range", 1.0)
	
	# Maksymalny zasięg końca miecza przy pełnym wysunięciu + margines na ciało wroga
	var max_reach := base_distance + (swing_extension_max * attack_range_stat) + attack_range_margin
	
	return global_position.distance_to(current_target.global_position) <= max_reach

# ==========================================
# SYSTEM NAMIERZANIA
# ==========================================

func _update_target() -> void:
	current_target = _find_nearest_enemy()

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist_sq := INF
	
	if current_target != null and is_instance_valid(current_target) and not current_target.is_queued_for_deletion():
		var is_dead_check := false
		if "hp" in current_target and current_target.hp <= 0:
			is_dead_check = true
		if current_target.has_method("is_dead") and current_target.is_dead():
			is_dead_check = true
			
		if not is_dead_check:
			var current_target_dist_sq := global_position.distance_squared_to(current_target.global_position)
			nearest = current_target
			# Histereza / lepkość namierzania
			nearest_dist_sq = current_target_dist_sq * 0.56

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy == current_target:
			continue
		if "hp" in enemy and enemy.hp <= 0:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
			
		var dist_sq := global_position.distance_squared_to(enemy.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy
			
	return nearest

func _face_target(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	var target_angle := (current_target.global_position - global_position).angle()
	current_angle = lerp_angle(current_angle, target_angle, rotation_speed * delta)

func _update_sword_position() -> void:
	var effective_angle := current_angle + swing_arc_offset
	var distance := base_distance + swing_extension

	sword_hitbox.position = Vector2.RIGHT.rotated(effective_angle) * distance
	sword_hitbox.rotation = effective_angle

# ==========================================
# PĘTLA ZAMACHU (SWING ANIMATION)
# ==========================================

func _perform_swing_cycle() -> void:
	if not _combat_active or is_swinging:
		return

	is_swinging = true
	enemies_hit_this_swing.clear()

	var stats := PlayerData.get_total_stats()
	var attack_speed: float = stats.get("attack_speed", 1.0)
	
	var speed_factor := log(attack_speed + 1.0) * 1.5 + (attack_speed * 0.1)
	speed_factor = maxf(0.1, speed_factor)
	
	var current_swing_duration: float = maxf(0.05, swing_duration / speed_factor)
	var current_interval: float = maxf(0.02, base_swing_interval / speed_factor)

	_anim_max_ext = swing_extension_max * stats.get("attack_range", 1.0)
	var half_arc := deg_to_rad(swing_arc_deg * 0.5)

	var dir := 1.0 if is_swing_left_to_right else -1.0
	is_swing_left_to_right = not is_swing_left_to_right

	_anim_start_angle = -half_arc * dir
	_anim_end_angle = half_arc * dir

	swing_arc_offset = _anim_start_angle
	swing_extension = 0.0

	var half_duration := current_swing_duration * 0.5
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	# Animacja cięcia tam i z powrotem
	tween.tween_method(_update_swing_progress, 0.0, 0.5, half_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(_update_swing_progress, 0.5, 1.0, half_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(current_interval)
	
	# Zamiast odpalać kolejny zamach, kończymy cykl – następny zamach odpali _physics_process, jeśli wróg nadal jest w zasięgu
	tween.tween_callback(_on_swing_completed)

func _on_swing_completed() -> void:
	is_swinging = false
	swing_arc_offset = 0.0
	swing_extension = 0.0

func _update_swing_progress(t: float) -> void:
	swing_arc_offset = lerp(_anim_start_angle, _anim_end_angle, t)
	swing_extension = sin(t * PI) * _anim_max_ext

# ==========================================
# ZADAWANIE OBRAŻEŃ
# ==========================================

func _deal_damage_to_overlapping_enemies() -> void:
	if not _combat_active:
		return

	var stats := PlayerData.get_total_stats()
	var max_targets: int = stats.get("target_count", 1)

	if enemies_hit_this_swing.size() >= max_targets:
		return

	var space_state := get_world_2d().direct_space_state
	var collision_shape := sword_hitbox.get_node("CollisionShape2D") as CollisionShape2D
	
	if collision_shape == null or collision_shape.shape == null or collision_shape.disabled:
		return

	collision_shape.force_update_transform()

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = sword_hitbox.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [self]

	var results := space_state.intersect_shape(query, 32)
	var execute_threshold: float = stats.get("execute_threshold", 0.0)

	for result in results:
		var body = result["collider"]
		if not is_instance_valid(body) or not body.is_in_group("enemies"):
			continue

		var enemy := body as Node2D
		if enemy == null or enemy.is_queued_for_deletion():
			continue

		if "hp" in enemy and enemy.hp <= 0:
			continue

		if enemy in enemies_hit_this_swing:
			continue

		var hit_pos: Vector2 = enemy.global_position
		if hit_pos == Vector2.ZERO:
			continue

		enemies_hit_this_swing.append(enemy)

		var attack_info: Dictionary = PlayerData.calculate_attack()
		var damage: int = attack_info["damage"]
		var is_crit: bool = attack_info["is_crit"]
		var text_color: Color = attack_info["color"]

		var display_str := str(damage) + ("!" if is_crit else "")
		_spawn_floating_text(hit_pos, display_str, text_color)

		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)

		if execute_threshold > 0.0 and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			if "hp" in enemy and "max_hp" in enemy and enemy.max_hp > 0.0:
				var hp_percent: float = float(enemy.hp) / float(enemy.max_hp)
				if hp_percent > 0.0 and hp_percent <= execute_threshold:
					_spawn_floating_text(hit_pos + Vector2(0, -10), "EXECUTE!", Color(0.75, 0.2, 0.95))
					if enemy.has_method("die"):
						enemy.die()

		if enemies_hit_this_swing.size() >= max_targets:
			break

func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	if floating_text_scene == null:
		return

	var text_node := floating_text_scene.instantiate()
	text_node.z_index = 100
	
	var world_parent = get_parent()
	if world_parent != null:
		world_parent.add_child(text_node)
	else:
		get_tree().current_scene.add_child(text_node)
		
	var random_offset := Vector2(randf_range(-4.0, 4.0), randf_range(-6.0, -2.0))
	text_node.global_position = pos + random_offset
	text_node.setup(text, color)