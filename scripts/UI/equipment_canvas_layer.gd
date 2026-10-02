extends CanvasLayer

@onready var main: Control = %Main
@onready var color_rect: ColorRect = %ColorRect

func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	visible = GameManager.current_state == GameManager.State.WEAPON_SELECT

func _on_state_changed(new_state: GameManager.State) -> void:
	var is_active = (new_state == GameManager.State.WEAPON_SELECT)
	var screen_height := get_viewport().get_visible_rect().size.y
	
	if is_active:
		visible = true
		
		# Start: przesunięty w górę + niewidoczny
		main.position.y = -screen_height
		main.modulate.a = 0.0
		color_rect.modulate.a = 0.0
		
		await get_tree().create_timer(0.45).timeout
		
		var t := create_tween()
		
		# ColorRect fade in pierwszy (tło pojawia się jako pierwsze)
		t.tween_property(color_rect, "modulate:a", 1.0, 0.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		
		# Potem Main wjeżdża z góry + fade in
		t.tween_property(main, "position:y", 0.0, 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(main, "modulate:a", 1.0, 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			
	else:
		if not visible:
			return
		
		var t := create_tween()
		
		# Main wyjazd w dół + fade out
		t.tween_property(main, "position:y", screen_height, 0.3) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.parallel().tween_property(main, "modulate:a", 0.0, 0.25) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		
		# ColorRect fade out na końcu (tło znika jako ostatnie)
		t.tween_property(color_rect, "modulate:a", 0.0, 0.2) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		
		await t.finished
		visible = false
		main.position.y = 0.0
