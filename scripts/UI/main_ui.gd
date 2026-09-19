extends CanvasLayer

@onready var exp_progress_bar: ProgressBar = %ExpProgressBar
@onready var hp_progress_bar: ProgressBar = %HpProgressBar
@onready var mana_progress_bar: ProgressBar = %ManaProgressBar
@onready var hp_current_label: Label = %HpCurrent
@onready var hp_max_label: Label = %HpMax

func _ready() -> void:
	PlayerData.health.changed.connect(_on_player_health_changed)
	_on_player_health_changed(PlayerData.health.current, PlayerData.health.max_hp)

func _on_player_health_changed(current: int, max_hp: int) -> void:
	hp_progress_bar.max_value = max_hp
	hp_progress_bar.value = current
	hp_current_label.text = str(current)
	hp_max_label.text = str(max_hp)
