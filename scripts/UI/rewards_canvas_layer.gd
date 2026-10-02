extends CanvasLayer

@onready var rewards_container: BoxContainer = %RewardsContainer

func _ready() -> void:
	await get_tree().physics_frame
	GameManager.state_changed.connect(_on_state_changed)
	visible = GameManager.current_state == GameManager.State.ENEMY_REWARDS

func _on_state_changed(new_state: GameManager.State) -> void:
	var is_active = (new_state == GameManager.State.ENEMY_REWARDS)
	
	if is_active:
		visible = true
		
		# Resetujemy offsety kart do pozycji startowej (wysunięte w górę)
		for child in rewards_container.get_children():
			child.offset_transform_enabled = true
			child.offset_transform_position = Vector2(0, -200)
			child.modulate.a = 0.0
		
		# Animacja wejścia z kaskadą
		var delay := 0.0
		for child in rewards_container.get_children():
			UIAnim.slide_and_fade_in(child, Vector2.DOWN, 200.0, 0.5, true, delay)
			delay += 0.1
			
	else:
		# Animacja wyjścia z kaskadą (tylko jeśli kontener jest aktualnie widoczny)
		if not visible:
			return
			
		var delay := 0.0
		var last_tween: Tween = null
		
		for child in rewards_container.get_children():
			last_tween = UIAnim.slide_and_fade_out(child, Vector2.DOWN, 200.0, 0.3, true, delay)
			delay += 0.08
		
		# Czekamy na zakończenie ostatniej animacji, potem ukrywamy
		if last_tween:
			await last_tween.finished
		
		visible = false

func _on_reward_selected() -> InventoryEntry:
	return
