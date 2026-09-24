extends Node

var _active: Dictionary = {}


func _register(node: Node, tween: Tween) -> Tween:
	# Rejestruje tween i podpina auto-czyszczenie po zakończeniu
	if not _active.has(node):
		_active[node] = []
		# Jeśli węzeł zostanie usunięty, czyścimy po nim
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


## Zabija wszystkie aktywne tweens na danym węźle (opcjonalnie przed nową animacją).
func kill_all(node: Node) -> void:
	if _active.has(node):
		for t: Tween in _active[node]:
			if t.is_valid():
				t.kill()
		_active[node].clear()



#  ANIMACJE

func scale_to(control: Control, target: Vector2, duration: float = 0.12, key: StringName = &"scale") -> Tween:
	# pivot w środku, inaczej skaluje się od lewego-górnego rogu
	Utilities.center_pivot(control)

	if control.has_meta(key):
		var old := control.get_meta(key) as Tween
		if old and old.is_valid():
			old.kill()

	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", target, duration)
	control.set_meta(key, tween)
	return tween

## Skala 1 → big → 1 (klasyczny "pop" przycisku).
func pop(node: CanvasItem, scale_amount: float = 1.2, duration: float = 0.2, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var original: Vector2 = node.scale
	var big: Vector2 = original * scale_amount

	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(node, "scale", big, duration * 0.4)
	t.tween_property(node, "scale", original, duration * 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)

	return _register(node, t)


## Drżenie w miejscu (błąd, obrażenia, alert).
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


## Pojawienie przez fade (modulate.a: 0 → 1).
func fade_in(node: CanvasItem, duration: float = 0.3, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	node.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(node, "modulate:a", 1.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return _register(node, t)


## Zniknięcie przez fade (modulate.a: 1 → 0).
func fade_out(node: CanvasItem, duration: float = 0.3, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var t := create_tween()
	t.tween_property(node, "modulate:a", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	return _register(node, t)


## Wjazd z krawędzi (direction = Vector2.LEFT / RIGHT / UP / DOWN).
func slide_in(node: CanvasItem, direction: Vector2 = Vector2.LEFT, distance: float = 200.0, duration: float = 0.35, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var target: Vector2 = node.position
	var start: Vector2 = target + direction.normalized() * distance
	node.position = start

	var t := create_tween()
	t.tween_property(node, "position", target, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return _register(node, t)


## Wyjazd za krawędź.
func slide_out(node: CanvasItem, direction: Vector2 = Vector2.RIGHT, distance: float = 200.0, duration: float = 0.3, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var target: Vector2 = node.position + direction.normalized() * distance
	var t := create_tween()
	t.tween_property(node, "position", target, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	return _register(node, t)


## Pulsowanie skali (nieskończone, np. "kliknij mnie!").
func pulse(node: CanvasItem, scale_amount: float = 1.08, duration: float = 0.8) -> Tween:
	kill_all(node)

	var original: Vector2 = node.scale
	var big: Vector2 = original * scale_amount

	var t := create_tween().set_loops()
	t.tween_property(node, "scale", big, duration * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", original, duration * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	return _register(node, t)


## Kołysanie rotacyjne (np. ikony powiadomień).
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


## Mignięcie kolorem (np. damage flash na biało/czerwono).
func flash(node: CanvasItem, color: Color = Color.WHITE, duration: float = 0.15, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var original: Color = node.modulate
	var t := create_tween()
	t.tween_property(node, "modulate", color, duration * 0.3)
	t.tween_property(node, "modulate", original, duration * 0.7) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return _register(node, t)


## Bounce — "upuszczenie" elementu z góry z odbiciem.
func bounce_in(node: CanvasItem, distance: float = 150.0, duration: float = 0.5, kill_existing: bool = true) -> Tween:
	if kill_existing:
		kill_all(node)

	var target: Vector2 = node.position
	node.position.y -= distance

	var t := create_tween()
	t.tween_property(node, "position", target, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	return _register(node, t)
