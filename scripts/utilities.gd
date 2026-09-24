class_name Utilities extends RefCounted

## Ustawia pivot_offset na środek node'a — wymaga, żeby size był już finalny
## (czyli wołaj to PO ustawieniu tekstu/layoutu, nie przed).
static func center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5


## Niszczy wszystkie dzieci node'a — do UI budowanego od nowa przy każdym odświeżeniu
## (lista statów, siatka pól kości w skill_face_picker, itp.).
static func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
	
## Rzutuje punkt świata 3D na ekran; null jeśli punkt jest za kamerą.
## To dokładnie ten fragment powtórzony w main_3d_scene._update_all_tag_positions()
## i w FloatingTextManager.spawn_world().
static func world_to_screen(camera: Camera3D, world_position: Vector3) -> Variant:
	if camera == null or camera.is_position_behind(world_position):
		return null
	return camera.unproject_position(world_position)


## Przycina prostokąt (tag, tooltip) do widocznego obszaru viewportu z marginesem.
## To ta sama logika co linie 111-112 w main_3d_scene.gd.
static func clamp_rect_to_viewport(position: Vector2, size: Vector2, viewport_size: Vector2, margin: float = 16.0) -> Vector2:
	var clamped := position
	clamped.x = clamp(clamped.x, margin, viewport_size.x - margin - size.x)
	clamped.y = clamp(clamped.y, margin, viewport_size.y - margin - size.y)
	return clamped


## queue_free(), które nie wybucha, jeśli node już jest nieprawidłowy.
## Masz to "ręcznie" powtórzone jako `if is_instance_valid(x): x.queue_free()`
## w dice_roller.gd, main_3d_scene.gd (kilka razy) i inventory.gd.
static func safe_free(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()

static func free_children(node: Node) -> void:
	for child in node.get_children():
		if is_instance_valid(child):
			child.queue_free()
