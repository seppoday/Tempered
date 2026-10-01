extends Node3D

@export var roll_button: Button
@export var confirm_button: Button
@export var result_label: Label
@export var dice_roller: DiceRoller
@export var dice_hand: DiceHand
@export var enemy_scene: PackedScene
@export var wave_manager: WaveManager

@onready var camera = %Camera3D
@onready var equipment_canvas_layer: CanvasLayer = %EquipmentCanvasLayer
@onready var box: Node3D = %Box


func _ready() -> void:
	AudioManager.play_music(AudioLibrary.get_music(AudioKeys.MUSIC_TEST), -10.0)

	roll_button.pressed.connect(_on_roll_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	dice_hand.results_ready.connect(_on_dice_hand_results_ready)
	GameManager.state_changed.connect(_on_game_state_changed)

	# --- SYGNAŁY WALKI I OBRAŻEŃ ---
	CombatManager.player_died.connect(_on_player_died)
	CombatManager.enemy_died.connect(_on_enemy_died)
	EventBus.player_damaged.connect(_on_player_damaged)
	PlayerData.player_dodged.connect(_on_player_dodged) # <--- NOWE
	
	# --- NOWE: Sygnały statusów i efektów na wrogu ---
	#CombatManager.effect_applied.connect(_on_combat_effect_applied)
	CombatManager.status_applied_to_enemy.connect(_on_enemy_status_applied)
	CombatManager.status_tick_on_enemy.connect(_on_enemy_status_tick)

	dice_roller.spawn_dice()
	box.shake(camera)

	GameManager.set_state(GameManager.State.PLAYER_TURN, self)


func _on_game_state_changed(new_state: GameManager.State) -> void:
	roll_button.disabled = (new_state != GameManager.State.PLAYER_TURN)
	confirm_button.disabled = (new_state != GameManager.State.SELECTING)


func _on_player_died() -> void:
	GameManager.set_state(GameManager.State.GAME_OVER, self)


# ── REAKCJA NA OBRAŻEŃ GRACZA (2D) ──

func _on_player_damaged(hp_amount: int, shield_amount: int) -> void:
	# Pozycja startowa nad paskiem HP
	var pos = %HpProgressBar.global_position + Vector2(0, -20)
	
	# 1. Jeśli zeszła tarcza, spawnujemy niebieski tekst np. "-10 🛡️"
	if shield_amount > 0:
		FloatingTextManager.spawn_shield_block(shield_amount, pos)
		# Przesuwamy pozycję następnego tekstu w górę, aby się nie nałożyły
		pos += Vector2(0, -25) 
		
	# 2. Jeśli ucierpiało HP, spawnujemy czerwony tekst damage
	if hp_amount > 0:
		# Używamy dedykowanej metody dla heala/damage, ale na ekranie 2D
		FloatingTextManager.spawn_screen("-%d" % hp_amount, pos, FloatingTextManager.COLOR_DAMAGE)


func _on_player_dodged() -> void:
	var pos = %HpProgressBar.global_position + Vector2(0, -20)
	FloatingTextManager.spawn_screen("DODGE! ✨", pos, FloatingTextManager.COLOR_DODGE)


# ── REAKCJA NA EFEKTY I STATUSY WROGA (3D) ──

#func _on_combat_effect_applied(skill: SkillDefinition, value: int, target: String) -> void:
	## Jeśli gracz zadał bezpośrednie obrażenia wrogowi, spawnowany jest tekst w 3D
	#if target == "enemy" and CombatManager.current_enemy != null:
		#var enemy_pos: Vector3 = CombatManager.current_enemy.global_position + Vector3(0, 1.2, 0)
		#FloatingTextManager.spawn_damage(value, enemy_pos)


func _on_enemy_status_applied(status_name: String) -> void:
	if CombatManager.current_enemy == null:
		return
		
	# POPRAWKA: Używamy zapisu słownikowego [] zamiast .get()
	var status_type: GameEnums.StatusType = GameEnums.StatusType[status_name] as GameEnums.StatusType
	var enemy_pos: Vector3 = CombatManager.current_enemy.global_position
	FloatingTextManager.spawn_status_applied(status_type, enemy_pos)


func _on_enemy_status_tick(status_name: String, damage: int) -> void:
	if CombatManager.current_enemy == null:
		return
		
	# POPRAWKA: Używamy zapisu słownikowego [] zamiast .get()
	var status_type: GameEnums.StatusType = GameEnums.StatusType[status_name] as GameEnums.StatusType
	var enemy_pos: Vector3 = CombatManager.current_enemy.global_position
	FloatingTextManager.spawn_status_tick(damage, status_type, enemy_pos)


# ── RESTA SYSTEMÓW WALK / TURY ──

func _on_enemy_died(enemy) -> void:
	box.close_lid()
	GameManager.set_state(GameManager.State.WEAPON_SELECT, self)


func _on_dice_hand_results_ready() -> void:
	GameManager.set_state(GameManager.State.SELECTING, self)


func _on_roll_button_pressed() -> void:
	camera.shake()
	UIAnim.pop(roll_button)
	if dice_hand.is_rolling or CombatManager.is_game_over:
		return

	dice_hand.start_rolling()
	GameManager.set_state(GameManager.State.RESOLVING, self)
	result_label.text = "Toczenie kości..."
	dice_roller.roll()


func _on_confirm_button_pressed() -> void:
	if not dice_hand.has_selection() or CombatManager.is_game_over:
		return

	GameManager.set_state(GameManager.State.RESOLVING, self)

	var selected_results := await dice_hand.confirm_selection()
	await CombatManager.resolve_player_attack(selected_results)
	
	# Kości resetujemy raz – faza rzutu gracza dobiegła końca
	dice_hand.reset_for_new_roll()

	# Jeśli gra się skończyła LUB wróg padł (przejście do WEAPON_SELECT) – kończymy
	if CombatManager.is_game_over or CombatManager.current_enemy == null:
		return

	# Tura wroga
	GameManager.set_state(GameManager.State.ENEMY_TURN, self)
	CombatManager.enemy_take_turn()

	if not CombatManager.is_game_over:
		GameManager.set_state(GameManager.State.PLAYER_TURN, self)


func _on_next_enemy_button_pressed() -> void:
	box.open_lid()
	wave_manager.request_next_enemy()
	dice_roller._clear_previous_dice()
	dice_roller._spawn_dice_for_equipped_items()
	GameManager.set_state(GameManager.State.PLAYER_TURN, self)
