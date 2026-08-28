extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval_min: float = 1.5
@export var spawn_interval_max: float = 3.0
@export var spawn_margin: float = 40.0  

# Opcjonalnie: Panel UI areny
@export var arena_ui_panel: Control

@export_group("Drop Settings")
@export var drop_scene: PackedScene
@export_range(0.0, 1.0) var drop_chance: float = 0.1
@export var max_ground_drops: int = 50  

# === NOWE: PULA ŁUPÓW (LOOT POOL) ===
# Tutaj w Inspektorze przeciągasz swoje pliki .tres (np. steel_sword.tres, shield.tres)
@export var loot_pool: Array[ItemDefinition] = []

@export_group("Gold & Exp Settings")
@export var floating_text_scene: PackedScene 
@export var min_gold_drop: int = 5
@export var max_gold_drop: int = 15

@onready var enemy_layer: Node2D = get_node_or_null("%EnemyLayer")
@onready var drop_layer: Node2D = get_node_or_null("%DropLayer")
@onready var player: CharacterBody2D = %Player

var spawn_timer: float = 0.0

func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	_reset_spawn_timer()

func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_reset_spawn_timer()
		_spawn_enemy()

func _reset_spawn_timer() -> void:
	spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)

func _spawn_enemy() -> void:
	if enemy_scene == null or player == null:
		return

	var enemy := enemy_scene.instantiate()
	
	if enemy_layer != null:
		enemy_layer.add_child(enemy)
	else:
		add_child(enemy)
	
	enemy.global_position = _get_random_edge_position()
	enemy.target_position = player.global_position

	EventBus.enemy_spawned.emit(enemy)

# ==========================================
# OBLICZANIE POZYCJI SPAWNU W 2D
# ==========================================
func _get_random_edge_position() -> Vector2:
	var rect: Rect2

	if arena_ui_panel != null:
		rect = arena_ui_panel.get_global_rect()
	else:
		rect = get_viewport_rect()

	var side := randi() % 4
	match side:
		0: # Góra
			return Vector2(randf_range(rect.position.x, rect.position.x + rect.size.x), rect.position.y - spawn_margin)
		1: # Dół
			return Vector2(randf_range(rect.position.x, rect.position.x + rect.size.x), rect.position.y + rect.size.y + spawn_margin)
		2: # Lewo
			return Vector2(rect.position.x - spawn_margin, randf_range(rect.position.y, rect.position.y + rect.size.y))
		_: # Prawo
			return Vector2(rect.position.x + rect.size.x + spawn_margin, randf_range(rect.position.y, rect.position.y + rect.size.y))

# ==========================================
# OBSŁUGA ŚMIERCI WROGA (Drop + Złoto + EXP)
# ==========================================
func _on_enemy_died(enemy: Node, death_position: Vector2) -> void:
	spawn_drop(enemy, death_position)
	
	if PlayerData != null:
		# Złoto
		var earned_gold := randi_range(min_gold_drop, max_gold_drop)
		PlayerData.add_gold(earned_gold)
		_spawn_floating_text(death_position + Vector2(0, -15), "+%d$" % earned_gold, Color(1.0, 0.85, 0.2))
		
		# EXP
		var earned_exp: int = 10
		if "exp_reward" in enemy:
			earned_exp = enemy.exp_reward
			
		PlayerData.add_exp(earned_exp)
		_spawn_floating_text(death_position + Vector2(15, -5), "+%d XP" % earned_exp, Color(0.8, 0.4, 1.0))

func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	if floating_text_scene == null:
		return
	
	var text_node := floating_text_scene.instantiate()
	text_node.z_index = 100
	
	if drop_layer != null:
		drop_layer.add_child(text_node)
	else:
		add_child(text_node)
		
	text_node.global_position = pos
	text_node.setup(text, color)

# ==========================================
# GENEROWANIE PRZEDMIOTU (DROP)
# ==========================================
func spawn_drop(_enemy: Node, death_position: Vector2) -> void:
	# Jeśli nie ma zdefiniowanej sceny dropu, warstwy lub pula przedmiotów jest pusta
	if drop_scene == null or drop_layer == null or loot_pool.is_empty():
		return

	# Szansa na drop zmodyfikowana o Luck z PlayerData
	var stats := PlayerData.get_total_stats()
	var luck_stat: float = stats.get("luck", 0.0)
	var final_drop_chance: float = drop_chance + (luck_stat / 100.0)

	if randf() > final_drop_chance:
		return

	# Limit przedmiotów leżących na ziemi (zapobiega lagom)
	if drop_layer.get_child_count() >= max_ground_drops:
		var oldest_drop = drop_layer.get_child(0)
		if is_instance_valid(oldest_drop):
			oldest_drop.queue_free()

	# 1. Losujemy definicję przedmiotu z puli
	var random_definition: ItemDefinition = loot_pool.pick_random()
	if random_definition == null:
		return

	# 2. Tworzymy instancję tego przedmiotu (ilość: 1)
	var item_instance := ItemInstance.new(random_definition, 1)

	# 3. Tworzymy fizyczny obiekt na ziemi
	var drop := drop_scene.instantiate()
	
	# Przekazujemy nowo utworzoną instancję do obiektu dropu
	if "item_data" in drop:
		drop.item_data = item_instance

	drop_layer.add_child(drop)
	drop.global_position = death_position