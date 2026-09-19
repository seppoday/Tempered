extends CharacterBody2D

@export var floating_text_scene: PackedScene

@export_group("Swing Settings")
@export var swing_arc_deg: float = 120.0       # Kąt zamachu w stopniach
@export var swing_extension_max: float = 18.0  # Max wysunięcie miecza
@export var swing_duration: float = 0.2        # Czas trwania jednego zamachu
@export var base_swing_interval: float = 0.45  # Przerwa między zamachami
@export var rotation_speed: float = 10.0       # Szybkość obracania się do wroga
@export var attack_range_margin: float = 100.0  # Dodatkowy margines na promień wroga/hitboxa

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
	GameManager.state_changed.connect(func(new_state): print("GameFlow zmienił stan na: ", new_state))

	PlayerData.hp_changed.connect(_on_player_hp_changed)
	PlayerData.damage_taken.connect(_on_player_damage_taken)
	# 1. Wypisanie receptur
	var all_recipes := RecipeDatabase.get_all()

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
		PlayerData.equip_item(instance)

	# 4. Odpalenie opóźnienia walki w tle
	_enable_combat_delayed()


func _enable_combat_delayed() -> void:
	await get_tree().create_timer(1.0).timeout
	
	var collision_shape := sword_hitbox.get_node("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = false
		
	_combat_active = true
	# Nie wywołujemy pętli na sztywno – zajmie się tym _physics_process, gdy wróg będzie w zasięgu

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



func _on_swing_completed() -> void:
	is_swinging = false
	swing_arc_offset = 0.0
	swing_extension = 0.0

func _update_swing_progress(t: float) -> void:
	swing_arc_offset = lerp(_anim_start_angle, _anim_end_angle, t)
	swing_extension = sin(t * PI) * _anim_max_ext


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

func _on_player_hp_changed(current_hp: float, max_hp: float) -> void:
	pass

func _on_player_damage_taken(damage_amount: float, was_dodged: bool) -> void:
	if was_dodged:
		_spawn_floating_text(global_position + Vector2(0, -16), "DODGE!", Color(0.6, 0.6, 0.65))
	else:
		_spawn_floating_text(global_position + Vector2(0, -16), "-%d" % int(damage_amount), Color(1.0, 0.3, 0.3))
