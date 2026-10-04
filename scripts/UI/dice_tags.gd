extends CanvasLayer

#func _ready() -> void:
	#GameManager.state_changed.connect(_on_state_changed)
	#visible = GameManager.current_state == GameManager.State.SELECTING
#
#func _on_state_changed(new_state: GameManager.State) -> void:
	#var is_active = (new_state == GameManager.State.SELECTING)
	#var screen_height := get_viewport().get_visible_rect().size.y
