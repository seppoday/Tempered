extends Node

var _active: Dictionary = {}


func _register(node: Node, tween: Tween) -> Tween:
	if not _active.has(node):
		_active[node] = []
		if not node.tree_exiting.is_connected(_on_node_exiting):
			node.tree_exiting.connect(_on_node_exiting.bind(node))

	_active[node].append(tween)
	tween.finished.connect(_on_tween_finished.bind(node, tween))
	return tween


func _on_tween_finished(node: Node, tween: Tween) -> void:
	if _active.has(node):
		_active[node].erase(tween)


func _on_node_exiting(node: Node) -> void:
	_active.erase(node)

func kill_all(node: Node) -> void:
	if _active.has(node):
		for t: Tween in _active[node]:
			if t.is_valid():
				t.kill()
		_active[node].clear()

## Znikanie ze zmniejszeniem skali (np. odrzucenie karty)
func fade_out_shrink(node: Control, duration: float = 0.45, kill_existing: bool = true) -> Tween:
	if not is_instance_valid(node):
		return null
	if kill_existing:
		kill_all(node)

	Utilities.center_pivot(node)
	node.offset_transform_enabled = true

	var t := node.create_tween()
	t.tween_property(node, "offset_transform_scale", Vector2.ZERO, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(node, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	return _register(node, t)


## Pojawienie się z "odbiciem" (pop-in)
func pop_in(node: Control, duration: float = 0.35, kill_existing: bool = true) -> Tween:
	if not is_instance_valid(node):
		return null
	if kill_existing:
		kill_all(node)

	node.show()
	Utilities.center_pivot(node)
	node.offset_transform_enabled = true
	node.offset_transform_scale = Vector2.ZERO
	node.modulate.a = 0.0

	var t := node.create_tween()
	t.tween_property(node, "offset_transform_scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node, "modulate:a", 1.0, duration * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return _register(node, t)


## Uderzenie / puls (np. po kliknięciu lub hoverze)
func punch_scale(node: Control, target_scale: Vector2 = Vector2(1.15, 1.15), duration: float = 0.15, kill_existing: bool = true) -> Tween:
	if not is_instance_valid(node):
		return null
	if kill_existing:
		kill_all(node)

	Utilities.center_pivot(node)
	
	node.offset_transform_enabled = true
	node.offset_transform_visual_only = false
	
	var t := node.create_tween()
	t.tween_property(node, "offset_transform_scale", target_scale, duration * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "offset_transform_scale", Vector2.ONE, duration * 0.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	return _register(node, t)

func scale_to(control: Control, target: Vector2, duration: float = 0.12, key: StringName = &"scale") -> Tween:
	Utilities.center_pivot(control)
	
	control.offset_transform_enabled = true
	control.offset_transform_visual_only = false
	
	if control.has_meta(key):
		var old := control.get_meta(key) as Tween
		if old and old.is_valid():
			old.kill()

	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "offset_transform_scale", target, duration)
	control.set_meta(key, tween)
	return tween

func pop(node: CanvasItem, scale_amount: float = 1.2, duration: float = 0.2, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)
	
	node.offset_transform_enabled = true
	node.offset_transform_visual_only = false
	
	var original: Vector2 = node.scale
	var big: Vector2 = original * scale_amount

	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(node, "offset_transform_scale", big, duration * 0.4)
	t.tween_property(node, "offset_transform_scale", original, duration * 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)

	return _register(node, t)

func shake(node: CanvasItem, intensity: float = 6.0, duration: float = 0.3, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var original: Vector2 = node.position
	var t := create_tween()
	var steps := int(duration / 0.03)

	for i in steps:
		var offset := Vector2(
			RNG.randf_range(-intensity, intensity),
			RNG.randf_range(-intensity, intensity)
		)
		t.tween_property(node, "position", original + offset, 0.03)

	t.tween_property(node, "position", original, 0.05)
	return _register(node, t)

func fade_in(node: CanvasItem, duration: float = 0.3, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	node.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(node, "modulate:a", 1.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return _register(node, t)

func fade_out(node: CanvasItem, duration: float = 0.3, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var t := create_tween()
	t.tween_property(node, "modulate:a", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	return _register(node, t)

func slide_in(node: CanvasItem, direction: Vector2 = Vector2.LEFT, distance: float = 200.0, duration: float = 0.35, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	node.offset_transform_enabled = true
	node.offset_transform_visual_only = false
	
	var target: Vector2 = node.position
	var start: Vector2 = target + direction.normalized() * distance
	node.position = start

	var t := create_tween()
	t.tween_property(node, "offset_transform_position", target, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).as_relative()
	return _register(node, t)

func slide_and_fade_in(node: CanvasItem, direction: Vector2 = Vector2.DOWN, distance: float = 200.0, duration: float = 0.35, kill_existing: bool = true, delay: float = 0.0) -> Tween:
	if kill_existing:
		kill_all(node)

	node.offset_transform_enabled = true
	node.offset_transform_visual_only = false
	
	# Ustawiamy przezroczystość na start
	node.modulate.a = 0.0
	
	# Obliczamy cel: aktualny offset + przesunięcie w podanym kierunku
	# np. (0, -200) + (0, 1) * 200 = (0, 0)
	var start_offset: Vector2 = node.offset_transform_position
	var target_offset: Vector2 = start_offset + direction.normalized() * distance

	var t := create_tween()
	
	# Animacja ruchu z aktualnej pozycji do obliczonego celu
	var move_tween = t.tween_property(node, "offset_transform_position", target_offset, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
	# Animacja przezroczystości
	var fade_tween = t.parallel().tween_property(node, "modulate:a", 1.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Opóźnienie dla efektu kaskady
	if delay > 0.0:
		move_tween.set_delay(delay)
		fade_tween.set_delay(delay)
		
	return _register(node, t)

func slide_and_fade_out(node: CanvasItem, direction: Vector2 = Vector2.DOWN, distance: float = 200.0, duration: float = 0.3, kill_existing: bool = true, delay: float = 0.0) -> Tween:
	if not is_instance_valid(node):
		return null
	if kill_existing:
		kill_all(node)

	node.offset_transform_enabled = true
	node.offset_transform_visual_only = false
	
	# Obliczamy cel: aktualny offset + ruch w stronę wskazaną przez direction
	# Np. jeśli karta jest na 0, a chcemy ją wysunąć w dół o 200: 0 + (0, 1) * 200 = (0, 200)
	var start_offset: Vector2 = node.offset_transform_position
	var target_offset: Vector2 = start_offset + direction.normalized() * distance

	var t := create_tween()
	
	# Przy znikaniu (Out) zazwyczaj używamy EASE_IN (animacja przyspiesza na końcu, gdy element opuszcza ekran)
	var move_tween = t.tween_property(node, "offset_transform_position", target_offset, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		
	# Jednoczesne zanikanie do 0.0
	var fade_tween = t.parallel().tween_property(node, "modulate:a", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Obsługa opóźnienia kaskadowego
	if delay > 0.0:
		move_tween.set_delay(delay)
		fade_tween.set_delay(delay)
		
	return _register(node, t)

func slide_out(node: CanvasItem, direction: Vector2 = Vector2.RIGHT, distance: float = 200.0, duration: float = 0.3, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var target: Vector2 = node.position + direction.normalized() * distance
	var t := create_tween()
	t.tween_property(node, "position", target, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).as_relative()
	return _register(node, t)

func pulse(node: CanvasItem, scale_amount: float = 1.08, duration: float = 0.8) -> Tween:
	kill_all(node)
	node.offset_transform_enabled = true
	
	var original: Vector2 = node.scale
	var big: Vector2 = original * scale_amount

	var t := create_tween().set_loops()
	t.tween_property(node, "offset_transform_scale", big, duration * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "offset_transform_scale", original, duration * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	return _register(node, t)

func wiggle(node: CanvasItem, angle_deg: float = 8.0, duration: float = 0.5, loops: int = 3) -> Tween:
	kill_all(node)

	var rad := deg_to_rad(angle_deg)
	var t := create_tween().set_loops(loops)
	t.tween_property(node, "rotation", rad, duration * 0.25) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "rotation", -rad, duration * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "rotation", 0.0, duration * 0.25) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	return _register(node, t)

func flash(node: CanvasItem, color: Color = Color.WHITE, duration: float = 0.15, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var original: Color = node.modulate
	var t := create_tween()
	t.tween_property(node, "modulate", color, duration * 0.3)
	t.tween_property(node, "modulate", original, duration * 0.7) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return _register(node, t)


func bounce_in(node: CanvasItem, distance: float = 150.0, duration: float = 0.5, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var target: Vector2 = node.position
	node.position.y -= distance

	var t := create_tween()
	t.tween_property(node, "position", target, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	return _register(node, t)
