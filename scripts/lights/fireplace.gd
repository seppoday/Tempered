extends Node3D

@onready var fireplace: Light3D = %Fireplace

var base_energy: float = 2.0
var base_range: float = 10.0
var base_color: Color

@export var min_energy_mult: float = 0.85
@export var max_energy_mult: float = 1.12
@export var flicker_speed_min: float = 0.2
@export var flicker_speed_max: float = 0.5

var fireplace_tween: Tween

func _ready() -> void:
	if fireplace:
		base_energy = fireplace.light_energy
		base_color = fireplace.light_color
		
		if fireplace is OmniLight3D:
			base_range = fireplace.omni_range
		elif fireplace is SpotLight3D:
			base_range = fireplace.spot_range
			
		start_fireplace()


func start_fireplace() -> void:
	_flicker_step()

func stop_fireplace() -> void:
	if fireplace_tween:
		fireplace_tween.kill()

func _flicker_step() -> void:
	if not is_instance_valid(fireplace):
		return

	fireplace_tween = create_tween().set_parallel(true)

	var duration := randf_range(flicker_speed_min, flicker_speed_max)

	var energy_factor := randf_range(min_energy_mult, max_energy_mult)
	var target_energy := base_energy * energy_factor
	var target_range := base_range * randf_range(0.9, 1.1)

	var target_color := base_color
	if energy_factor < 1.0:
		target_color = base_color.lerp(Color(1.0, 0.15, 0.0), (1.0 - energy_factor) * 0.6)
	else:
		target_color = base_color.lerp(Color(1.0, 0.85, 0.3), (energy_factor - 1.0) * 0.5)

	fireplace_tween.tween_property(fireplace, "light_energy", target_energy, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	fireplace_tween.tween_property(fireplace, "light_color", target_color, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var range_property = "omni_range" if fireplace is OmniLight3D else "spot_range"
	fireplace_tween.tween_property(fireplace, range_property, target_range, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	fireplace_tween.chain().tween_callback(_flicker_step)
