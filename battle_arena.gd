extends PanelContainer

@export var enemy_scene: PackedScene
@export var spawn_interval_min: float = 1.5
@export var spawn_interval_max: float = 3.0
@export var spawn_margin: float = 40.0  # jak daleko za krawędzią panelu spawnować

@export_group("Drop Settings")
@export var drop_scene: PackedScene
# Bazowa szansa na drop: 0.1 = 10%
@export_range(0.0, 1.0) var drop_chance: float = 0.1 

@export_group("Gold Settings")
@export var floating_text_scene: PackedScene # Przypisz floating_text.tscn w edytorze!
@export var min_gold_drop: int = 5
@export var max_gold_drop: int = 15

@onready var drop_layer: Node2D = %DropLayer
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
	add_child(enemy)
	enemy.global_position = _get_random_edge_position()
	enemy.target_position = player.global_position

	EventBus.enemy_spawned.emit(enemy)

func _get_random_edge_position() -> Vector2:
	var rect: Rect2 = get_global_rect()
	var side := randi() % 4
	match side:
		0: # góra
			return Vector2(randf_range(rect.position.x, rect.position.x + rect.size.x), rect.position.y - spawn_margin)
		1: # dół
			return Vector2(randf_range(rect.position.x, rect.position.x + rect.size.x), rect.position.y + rect.size.y + spawn_margin)
		2: # lewo
			return Vector2(rect.position.x - spawn_margin, randf_range(rect.position.y, rect.position.y + rect.size.y))
		_: # prawo
			return Vector2(rect.position.x + rect.size.x + spawn_margin, randf_range(rect.position.y, rect.position.y + rect.size.y))

# ==========================================
# GŁÓWNA OBSŁUGA ŚMIERCI WROGA (Drop + Gold)
# ==========================================

func _on_enemy_died(enemy: Node, death_position: Vector2) -> void:
	# 1. Próba zdropowania przedmiotu
	spawn_drop(enemy, death_position)

	# 2. Losowanie i przyznawanie złota
	_award_gold(death_position)


func _award_gold(death_position: Vector2) -> void:
	var earned_gold := randi_range(min_gold_drop, max_gold_drop)
	PlayerData.add_gold(earned_gold)
	_spawn_gold_text(death_position, earned_gold)


func _spawn_gold_text(pos: Vector2, amount: int) -> void:
	if floating_text_scene == null:
		return

	var text_node := floating_text_scene.instantiate()
	get_tree().current_scene.add_child(text_node)
	text_node.global_position = pos + Vector2(0, -15) # Kawałek wyżej nad wrogiem
	text_node.setup("+%d$" % amount, Color(1.0, 0.85, 0.2)) # Złoty kolor tekstu


# ==========================================
# GENEROWANIE PRZEDMIOTU (DROP)
# ==========================================

func spawn_drop(_enemy: Node, death_position: Vector2) -> void:
	if drop_scene == null or drop_layer == null:
		return

	var stats := PlayerData.get_total_stats()
	var luck_stat: float = stats.get("luck", 0.0)
	var final_drop_chance: float = drop_chance + (luck_stat / 100.0)

	if randf() > final_drop_chance:
		return

	var drop := drop_scene.instantiate()
	if drop == null:
		return

	if "item_data" in drop:
		drop.item_data = {
			"id": "ognisty_miecz",
			"name": "Ognisty Miecz",
			"description": "Nadal bije od niego ciepło pokonanego wroga.",
			"item_type": "equipment",
			"equip_slot": "weapon",
			"base_damage": 25,
			"fire_damage": 10,
			"crit_chance": 0.15,
			"count": 1,
			"stackable": false,
			"rarity": "rare"
		}

	drop_layer.add_child(drop)
	drop.global_position = death_position
