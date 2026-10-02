class_name BattleManager # (lub inna nazwa klasy jaką masz)
extends Node3D

# Zamiast dwóch przycisków, mamy teraz jeden kontekstowy
@export var action_button: Button
@export var result_label: Label
@export var dice_roller: DiceRoller
@export var dice_hand: DiceHand
@export var enemy_scene: PackedScene
@export var wave_manager: WaveManager

@onready var camera = %Camera3D
@onready var box: Node3D = %Box


func _ready() -> void:
	AudioManager.play_music(AudioLibrary.get_music(AudioKeys.MUSIC_TEST), -10.0)

	# Podłączamy tylko jeden przycisk do wspólnej funkcji obsługującej kliknięcie
	action_button.pressed.connect(_on_action_button_pressed)
	
	dice_hand.results_ready.connect(_on_dice_hand_results_ready)
	GameManager.state_changed.connect(_on_game_state_changed)
	GameManager.set_state(GameManager.State.INTRO, self)

	# --- SYGNAŁY WALKI I OBRAŻEŃ ---
	CombatManager.player_died.connect(_on_player_died)
	CombatManager.enemy_died.connect(_on_enemy_died)
	EventBus.player_damaged.connect(_on_player_damaged)
	PlayerData.player_dodged.connect(_on_player_dodged)
	
	# --- Sygnały statusów i efektów na wrogu ---
	CombatManager.status_applied_to_enemy.connect(_on_enemy_status_applied)
	CombatManager.status_tick_on_enemy.connect(_on_enemy_status_tick)
	
	dice_roller.spawn_dice()
	
	box.shake_finished.connect(_on_box_shake_finished)
	box.shake(camera)


func _on_box_shake_finished() -> void:
	GameManager.set_state(GameManager.State.PLAYER_TURN, self)


# ── KONTEKSTOWA OBSŁUGA STANU PRZYCISKU ──

func _on_game_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.PLAYER_TURN:
			action_button.disabled = false
			action_button.text = "RZUĆ KOŚĆMI"
			
		GameManager.State.SELECTING:
			action_button.disabled = false
			action_button.text = "ZATWIERDŹ WYBÓR"
			
		GameManager.State.RESOLVING:
			action_button.disabled = true
			action_button.text = "ROZGRYWANIE..."
			
		GameManager.State.ENEMY_TURN:
			action_button.disabled = true
			action_button.text = "TURA PRZECIWNIKA"
			
		_:
			action_button.disabled = true
			action_button.text = "CZEKAJ..."


# ── KLIKNIĘCIE JEDYNEGO PRZYCISKU ──

func _on_action_button_pressed() -> void:
	# Animacja uderzenia przycisku
	UIAnim.pop(action_button)
	
	# Decydujemy co zrobić na podstawie aktualnego stanu gry
	match GameManager.current_state:
		GameManager.State.PLAYER_TURN:
			_execute_roll()
		GameManager.State.SELECTING:
			_execute_confirm()


# ── WYDZIELONE METODY LOGIKI WALKI ──

func _execute_roll() -> void:
	if dice_hand.is_rolling or CombatManager.is_game_over:
		return

	camera.shake()
	dice_hand.start_rolling()
	GameManager.set_state(GameManager.State.RESOLVING, self)
	result_label.text = "Toczenie kości..."
	dice_roller.roll()


func _execute_confirm() -> void:
	if not dice_hand.has_selection() or CombatManager.is_game_over:
		# Możesz tu dodać delikatny shake przycisku (UIAnim.shake) informujący, 
		# że gracz musi najpierw wybrać kości.
		UIAnim.shake(action_button, 4.0, 0.2)
		return

	GameManager.set_state(GameManager.State.RESOLVING, self)

	var selected_results := await dice_hand.confirm_selection()
	await CombatManager.resolve_player_attack(selected_results)
	
	dice_hand.reset_for_new_roll()

	if CombatManager.is_game_over or CombatManager.current_enemy == null:
		return

	await get_tree().create_timer(0.5).timeout
	GameManager.set_state(GameManager.State.ENEMY_TURN, self)
	CombatManager.enemy_take_turn()

	if not CombatManager.is_game_over:
		GameManager.set_state(GameManager.State.PLAYER_TURN, self)


# ── REAKCJA NA OBRAŻEŃ GRACZA (2D) ──

func _on_player_damaged(hp_amount: int, shield_amount: int) -> void:
	var pos = %HpProgressBar.global_position + Vector2(0, -20)
	if shield_amount > 0:
		FloatingTextManager.spawn_shield_block(shield_amount, pos)
		pos += Vector2(0, -25) 
		
	if hp_amount > 0:
		FloatingTextManager.spawn_screen("-%d" % hp_amount, pos, FloatingTextManager.COLOR_DAMAGE)


func _on_player_dodged() -> void:
	var pos = %HpProgressBar.global_position + Vector2(0, -20)
	FloatingTextManager.spawn_screen("DODGE! ✨", pos, FloatingTextManager.COLOR_DODGE)


# ── REAKCJA NA EFEKTY I STATUSY WROGA (3D) ──

func _on_enemy_status_applied(status_name: String) -> void:
	if CombatManager.current_enemy == null:
		return
	var status_type: GameEnums.StatusType = GameEnums.StatusType[status_name] as GameEnums.StatusType
	var enemy_pos: Vector3 = CombatManager.current_enemy.global_position
	FloatingTextManager.spawn_status_applied(status_type, enemy_pos)


func _on_enemy_status_tick(status_name: String, damage: int) -> void:
	if CombatManager.current_enemy == null:
		return
	var status_type: GameEnums.StatusType = GameEnums.StatusType[status_name] as GameEnums.StatusType
	var enemy_pos: Vector3 = CombatManager.current_enemy.global_position
	FloatingTextManager.spawn_status_tick(damage, status_type, enemy_pos)


# ── REAKCJA NA ŚMIERĆ PRZECIWNIKA ──

func _on_enemy_died(enemy) -> void:
	box.close_lid()
	await get_tree().create_timer(1.0).timeout
	GameManager.set_state(GameManager.State.ENEMY_REWARDS, self)


func _on_dice_hand_results_ready() -> void:
	GameManager.set_state(GameManager.State.SELECTING, self)


func _on_player_died() -> void:
	GameManager.set_state(GameManager.State.GAME_OVER, self)


func _on_next_enemy_button_pressed() -> void:
	box.open_lid()
	wave_manager.request_next_enemy()
	dice_roller._clear_previous_dice()
	dice_roller._spawn_dice_for_equipped_items()
	GameManager.set_state(GameManager.State.PLAYER_TURN, self)
