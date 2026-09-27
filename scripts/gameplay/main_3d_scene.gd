extends Node3D

@export var roll_button: Button
@export var confirm_button: Button
@export var result_label: Label
@export var dice_roller: DiceRoller
@export var dice_hand: DiceHand
@export var enemy_scene: PackedScene

@onready var camera = %Camera3D
@onready var equipment_canvas_layer: CanvasLayer = %EquipmentCanvasLayer
@onready var box: Node3D = %Box


func _ready() -> void:
	AudioManager.play_music(AudioLibrary.get_music(AudioKeys.MUSIC_TEST), -10.0)

	roll_button.pressed.connect(_on_roll_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	dice_hand.results_ready.connect(_on_dice_hand_results_ready)
	GameManager.state_changed.connect(_on_game_state_changed)

	CombatManager.player_died.connect(_on_player_died)
	CombatManager.enemy_died.connect(_on_enemy_died)
	EventBus.player_damaged.connect(_on_player_damaged)

	dice_roller.spawn_dice()
	box.shake(camera)

	GameManager.set_state(GameManager.State.PLAYER_TURN, self)


## JEDYNE miejsce decydujące o stanie roll_button/confirm_button/result_label.
func _on_game_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.PLAYER_TURN:
			roll_button.disabled = false
			confirm_button.disabled = true
			result_label.text = "Naciśnij RZUĆ"
		GameManager.State.SELECTING:
			roll_button.disabled = true
			confirm_button.disabled = false
			result_label.text = "Wybierz karty"
		GameManager.State.GAME_OVER:
			roll_button.disabled = true
			confirm_button.disabled = true
			result_label.text = "PRZEGRANA"
		GameManager.State.WEAPON_SELECT:
			roll_button.disabled = true
			confirm_button.disabled = true
		GameManager.State.RESOLVING, GameManager.State.ENEMY_TURN:
			roll_button.disabled = true
			confirm_button.disabled = true


func _on_player_died() -> void:
	GameManager.set_state(GameManager.State.GAME_OVER, self)


func _on_player_damaged(final_amount) -> void:
	var pos = %HpProgressBar.global_position + Vector2(0, -20)
	FloatingTextManager.spawn_screen("%d" % final_amount, pos, FloatingTextManager.COLOR_DAMAGE)


func _on_enemy_died(enemy) -> void:
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

	if CombatManager.is_game_over:
		dice_hand.reset_for_new_roll()
		return

	if CombatManager.current_enemy == null:
		# Wróg padł w trakcie tego ataku — _on_enemy_died już ustawił WEAPON_SELECT.
		# Zatrzymujemy się tu celowo: gracz sam decyduje kiedy iść dalej
		# (przycisk "next enemy" w ekwipunku ustawia PLAYER_TURN).
		dice_hand.reset_for_new_roll()
		return

	GameManager.set_state(GameManager.State.ENEMY_TURN, self)
	CombatManager.enemy_take_turn()

	dice_hand.reset_for_new_roll()

	if not CombatManager.is_game_over:
		GameManager.set_state(GameManager.State.PLAYER_TURN, self)


func _on_next_enemy_button_pressed() -> void:
	dice_roller._clear_previous_dice()
	dice_roller._spawn_dice_for_equipped_items()
	GameManager.set_state(GameManager.State.PLAYER_TURN, self)
