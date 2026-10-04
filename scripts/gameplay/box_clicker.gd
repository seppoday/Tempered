extends StaticBody3D

signal roll_requested

@export var camera: ShakingCamera3D
@export var highlight_plane: MeshInstance3D   # dedykowany, osobny plane pod glow/outline

var is_hovering: bool = false
var _hover_intensity: float = 0.0
var _hover_tween: Tween


func _ready() -> void:
	GameManager.state_changed.connect(_on_game_state_changed)
	highlight_plane.visible = true
	highlight_plane.set_instance_shader_parameter("intensity", 0.0)


func _on_game_state_changed(new_state: GameManager.State) -> void:
	if new_state != GameManager.State.PLAYER_TURN and is_hovering:
		is_hovering = false
		_set_hover_visual(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_click_box(event.position)


func _raycast_clickable(mouse_pos: Vector2) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 << 1  # tylko "clickable"

	return space_state.intersect_ray(query)


func _update_hover(mouse_pos: Vector2) -> void:
	if GameManager.current_state != GameManager.State.PLAYER_TURN:
		if is_hovering:
			is_hovering = false
			_set_hover_visual(false)
		return

	var result := _raycast_clickable(mouse_pos)

	var now_hovering: bool = not result.is_empty() and result.collider.is_in_group("dice_box_trigger")

	if now_hovering == is_hovering:
		return

	is_hovering = now_hovering
	_set_hover_visual(is_hovering)


func _set_hover_visual(hovering: bool) -> void:
	var target := 1.0 if hovering else 0.0
	if is_equal_approx(_hover_intensity, target):
		return

	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.tween_method(
		func(v: float):
			_hover_intensity = v
			highlight_plane.set_instance_shader_parameter("intensity", v),
		_hover_intensity,
		target,
		0.25
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _try_click_box(mouse_pos: Vector2) -> void:
	if GameManager.current_state != GameManager.State.PLAYER_TURN:
		return

	var result := _raycast_clickable(mouse_pos)
	if result.is_empty():
		return
	if result.collider.is_in_group("dice_box_trigger"):
		roll_requested.emit()
