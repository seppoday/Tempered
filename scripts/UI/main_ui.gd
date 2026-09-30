extends CanvasLayer

@onready var hp_progress_bar: ProgressBar = %HpProgressBar
@onready var hp_current_label: Label = %HpCurrent
@onready var hp_max_label: Label = %HpMax

@onready var shield_progress_bar: ProgressBar = %ShieldProgressBar
@onready var shield_current: Label = %ShieldCurrent
@onready var shield_max: Label = %ShieldMax

var _shield_tween: Tween
var _hp_tween: Tween

func _ready() -> void:
	PlayerData.health.changed.connect(_on_player_health_changed)
	_on_player_health_changed(PlayerData.health.current, PlayerData.health.max_hp)

	PlayerData.shield_changed.connect(_on_player_shield_changed)
	_on_player_shield_changed(int(PlayerData.pending_block), PlayerData.max_shield)
	
	PlayerData.player_dodged.connect(_on_player_dodged)

func _on_player_dodged() -> void:
	# TODO: dopisać tutaj spawning floating textu
	pass


func _on_player_health_changed(current: int, max_hp: int) -> void:
	hp_progress_bar.max_value = max_hp
	hp_current_label.text = str(current)
	hp_max_label.text = str(max_hp)
	
	# Zawsze zatrzymaj poprzedni tween zanim stworzysz nowy
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()

	_hp_tween = create_tween()
	_hp_tween.tween_property(hp_progress_bar, "value", float(current), 0.25)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func _on_player_shield_changed(current: int, max_shield: int) -> void:
	shield_progress_bar.max_value = max_shield
	shield_current.text = str(current)
	shield_max.text = str(max_shield)

	# Zawsze zatrzymaj poprzedni tween zanim stworzysz nowy
	if _shield_tween != null and _shield_tween.is_valid():
		_shield_tween.kill()

	_shield_tween = create_tween()
	_shield_tween.tween_property(shield_progress_bar, "value", float(current), 0.25)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
