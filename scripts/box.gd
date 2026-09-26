extends Node3D
class_name DiceBox

signal shake_finished
signal lid_opened

@onready var lid: Node3D = %Lid
@export var lid_opening_time: float = 0.5
@export var lid_open_rotation: Vector3 = Vector3(0.0, 0.0, 145.0)

@export_group("Shake Settings")
@export var default_duration: float = 1.5
@export var default_max_intensity: float = 0.15
@export var default_lift_height: float = 1.0
@export var default_fov_zoom: float = 4.0


## Wykonuje pełną sekwencję: uniesienie, trzęsienie, uderzenie o stół i otwarcie wieczka.
func shake(
	camera: Camera3D = null,
	duration: float = -1.0,
	max_intensity: float = -1.0,
	lift_height: float = -1.0,
	fov_zoom: float = -1.0
) -> void:
	# Jeśli podano wartości mniejsze od zera, używamy domyślnych z Inspektora
	duration = default_duration if duration < 0.0 else duration
	max_intensity = default_max_intensity if max_intensity < 0.0 else max_intensity
	lift_height = default_lift_height if lift_height < 0.0 else lift_height
	fov_zoom = default_fov_zoom if fov_zoom < 0.0 else fov_zoom

	# Jeśli kamera nie została przekazana, pobieramy aktywną kamerę z widoku
	if camera == null:
		camera = get_viewport().get_camera_3d()

	var original_pos: Vector3 = position
	var original_rot: Vector3 = rotation
	var original_fov: float = camera.fov if camera != null else 75.0

	var shake_tween := create_tween().set_parallel(true)

	# Podział czasu na fazy
	var lift_duration: float = duration * 0.5
	var fall_duration: float = duration * 0.05
	var shake_duration: float = duration - lift_duration - fall_duration
	var fall_start_time: float = lift_duration + shake_duration

	# --- FAZA 1: UNIESIENIE (Start) ---
	shake_tween.tween_property(self, "position:y", original_pos.y + lift_height, lift_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shake_tween.tween_property(self, "rotation", original_rot + Vector3(0.05, 0.02, -0.05), lift_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if camera != null:
		var total_zoom_duration: float = lift_duration + shake_duration
		shake_tween.tween_property(camera, "fov", original_fov - fov_zoom, total_zoom_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# --- FAZA 2: TRZĘSIENIE (W powietrzu) ---
	var shake_count: int = 12
	var step_duration: float = shake_duration / shake_count

	for i in range(shake_count):
		var progress: float = float(i) / float(shake_count)
		var current_intensity: float = lerp(0.3, 1.0, progress) * max_intensity

		var random_offset := Vector3(
			randf_range(-current_intensity, current_intensity),
			0,
			randf_range(-current_intensity, current_intensity)
		)
		var random_rot := Vector3(
			randf_range(-current_intensity * 2.0, current_intensity * 2.0),
			randf_range(-current_intensity * 1.5, current_intensity * 1.5),
			randf_range(-current_intensity * 2.0, current_intensity * 2.0)
		)

		var t: float = lift_duration + (i * step_duration)
		var target_pos := Vector3(original_pos.x + random_offset.x, original_pos.y + lift_height, original_pos.z + random_offset.z)

		shake_tween.tween_property(self, "position", target_pos, step_duration)\
			.set_delay(t).set_trans(Tween.TRANS_SINE)
		shake_tween.tween_property(self, "rotation", original_rot + random_rot, step_duration)\
			.set_delay(t).set_trans(Tween.TRANS_SINE)

	# --- FAZA 3: OPUSZCZENIE / UPADEK (Koniec) ---
	shake_tween.tween_property(self, "position", original_pos, fall_duration)\
		.set_delay(fall_start_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	shake_tween.tween_property(self, "rotation", original_rot, fall_duration)\
		.set_delay(fall_start_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	if camera != null:
		shake_tween.tween_property(camera, "fov", original_fov, fall_duration)\
			.set_delay(fall_start_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# --- EFEKT UDERZENIA (Micro-bounce) ---
	var bounce_time: float = 0.05
	var bounce_height: float = lift_height * 0.25

	shake_tween.tween_property(self, "position:y", original_pos.y + bounce_height, bounce_time)\
		.set_delay(fall_start_time + fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shake_tween.tween_property(self, "position:y", original_pos.y, bounce_time)\
		.set_delay(fall_start_time + fall_duration + bounce_time).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	await shake_tween.finished
	shake_finished.emit()
	
	await open_lid()


## Otwiera wieczko pudełka
func open_lid() -> void:
	if not is_instance_valid(lid):
		push_warning("DiceBox: Brak przypisanego wieczka (Lid)!")
		return
		
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(lid, "global_rotation_degrees", lid_open_rotation, lid_opening_time)
	
	await tween.finished
	lid_opened.emit()
