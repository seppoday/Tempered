class_name Utilities extends RefCounted

static func center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5

static func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
	
static func world_to_screen(camera: Camera3D, world_position: Vector3) -> Variant:
	if camera == null or camera.is_position_behind(world_position):
		return null
	return camera.unproject_position(world_position)


static func clamp_rect_to_viewport(position: Vector2, size: Vector2, viewport_size: Vector2, margin: float = 16.0) -> Vector2:
	var clamped := position
	clamped.x = clamp(clamped.x, margin, viewport_size.x - margin - size.x)
	clamped.y = clamp(clamped.y, margin, viewport_size.y - margin - size.y)
	return clamped

static func safe_free(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


## Formatuj duże liczby (np. 1100 -> "1.1k", 11000 -> "11k", 1250000 -> "1.3M")
static func format_large_number(value: float) -> String:
	var rounded = round(value) # Pracujemy na zaokrąglonej wartości całkowitej
	var abs_val = abs(rounded)
	
	if abs_val < 1000.0:
		return str(int(rounded))
		
	elif abs_val < 1000000.0:
		var thousands = rounded / 1000.0
		
		if fmod(thousands, 1.0) == 0.0:
			return "%dk" % int(thousands)
		else:
			return "%.1fk" % thousands
			
	else:
		var millions = rounded / 1000000.0
		if fmod(millions, 1.0) == 0.0:
			return "%dM" % int(millions)
		else:
			return "%.1fM" % millions

static func free_children(node: Node) -> void:
	for child in node.get_children():
		if is_instance_valid(child):
			child.queue_free()
