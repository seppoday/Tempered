extends Node2D

# Opcjonalnie: Panel UI areny
@export var arena_ui_panel: Control
@export var spawn_margin: float = 120.0

@export_group("Drop Settings")
@export var drop_scene: PackedScene
@export_range(0.0, 1.0) var drop_chance: float = 0.5
@export var max_ground_drops: int = 50  

@export_group("Wave Settings")
@export var wave_sequence: WaveSequence

@export_group("Gold & Exp Settings")
@export var floating_text_scene: PackedScene 

@onready var enemy_layer: Node2D = get_node_or_null("%EnemyLayer")
@onready var drop_layer: Node2D = get_node_or_null("%DropLayer")
@onready var wave_manager: WaveManager = get_node_or_null("%WaveManager")
@onready var player: CharacterBody2D = %Player

func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	wave_manager.start_sequence(wave_sequence)  # tymczasowo, żeby ominąć brakujący ekran wyboru broni
	wave_manager.enemy_spawn_requested.connect(_on_enemy_spawn_requested)
	wave_manager.wave_completed.connect(_on_wave_completed)

func _on_wave_completed() -> void:
	GameFlow.set_state(GameFlow.State.RESULTS)

func _spawn_enemy(enemy_definition: EnemyDefinition, hp_multiplier: float) -> void:
	if enemy_definition.scene == null or player == null:
		return

	var enemy := enemy_definition.scene.instantiate()
	
	if enemy_layer != null:
		enemy_layer.add_child(enemy)
	else:
		add_child(enemy)
	
	enemy.global_position = _get_random_edge_position()
	enemy.target_position = player.global_position
	enemy.setup(enemy_definition, hp_multiplier)

	EventBus.enemy_spawned.emit(enemy)


# OBLICZANIE POZYCJI SPAWNU W 2D
func _get_random_edge_position() -> Vector2:
	var rect: Rect2 = get_viewport_rect()

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

func _on_enemy_spawn_requested(enemy_definition: EnemyDefinition, hp_multiplier: float) -> void:
	_spawn_enemy(enemy_definition, hp_multiplier)

# OBSŁUGA ŚMIERCI WROGA (Drop + Złoto + EXP)
func _on_enemy_died(enemy: Node, death_position: Vector2) -> void:
	spawn_drop(enemy, death_position)
	
	if PlayerData != null:
		# Złoto
		if enemy.definition.loot_table != null:
			var enemy_loot = enemy.definition.loot_table
			var earned_gold := RNG.randi_range(enemy_loot.gold_min, enemy_loot.gold_max)
			PlayerData.add_gold(earned_gold)
			_spawn_floating_text(death_position + Vector2(0, -16), "+%d$" % earned_gold, Color(1.0, 0.85, 0.2))
		
		# EXP
		var earned_exp = enemy.get_exp_reward()
			
		PlayerData.add_exp(earned_exp)
		_spawn_floating_text(death_position + Vector2(16, -12), "+%d XP" % earned_exp, Color(0.8, 0.4, 1.0))

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

# GENEROWANIE PRZEDMIOTU (DROP)
func spawn_drop(enemy: Node, death_position: Vector2) -> void:
	# 1. WYMAGANIA WSTĘPNE — bez sceny dropu/warstwy nie ma gdzie nic stworzyć,
	# a bez loot_table na wrogu nie wiemy, co mógłby wylosować.
	if drop_scene == null or drop_layer == null:
		return

	var loot_table: LootTable = enemy.definition.loot_table if "definition" in enemy else null
	if loot_table == null:
		return

	# 2. SZANSA NA DROP — czy w ogóle coś wypadnie z tego konkretnego wroga,
	# modyfikowana przez Luck gracza (jeśli kiedyś dodasz tę statystykę).
	var stats := PlayerData.get_total_stats()
	var luck_stat: float = stats.get("luck", 0.0)
	var final_drop_chance: float = drop_chance + (luck_stat / 100.0)

	if randf() > final_drop_chance:
		return

	# 3. LOSOWANIE KONKRETNEGO WPISU — ważone losowanie z LootTable
	# (patrz LootTable.roll_entry()), null jeśli tabela jest pusta.
	var entry: LootEntry = loot_table.roll_entry()
	if entry == null:
		return

	# 4. zaciągnięcie definicji itemu z lootentry
	var definition: InventoryEntry = entry.entry

	# Zabezpieczenie na literówkę/brak pliku w danych — entry_id, który
	# nie istnieje w żadnej bazie, nie powinien wywalić gry.
	if definition == null:
		return

	# 5. STWORZENIE INSTANCJI — konkretny, jednoegzemplarzowy przedmiot,
	# gotowy do włożenia do drop.gd na scenie.
	var item_instance := ItemInstance.new(definition, 1)

	# 6. FIZYCZNY OBIEKT NA ZIEMI — instancjonujemy scenę dropu, wstrzykujemy
	# do niej item_instance, i stawiamy w miejscu śmierci wroga.
	var drop := drop_scene.instantiate()

	if "item_data" in drop:
		drop.item_data = item_instance

	drop_layer.add_child(drop)
	drop.global_position = death_position
