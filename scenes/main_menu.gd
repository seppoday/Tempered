extends CanvasLayer


func _ready() -> void:
	GameManager.set_state(GameManager.State.SETTINGS, self)
	
	
func _on_start_button_pressed() -> void:
	PlayerData.reset_for_new_run()
	CombatManager.is_game_over = false
	SceneTransition.fade_to_scene("uid://cm0pwye2hbeox")

func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_settings_button_pressed() -> void:
	SceneTransition.fade_to_scene("uid://kprej8gd1emx")
