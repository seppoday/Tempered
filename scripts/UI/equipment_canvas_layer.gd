extends CanvasLayer

func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	visible = GameManager.current_state == GameManager.State.WEAPON_SELECT

func _on_state_changed(new_state: GameManager.State) -> void:
	visible = new_state == GameManager.State.WEAPON_SELECT
