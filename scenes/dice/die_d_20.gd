extends RigidBody3D

func _ready() -> void:
	var material = $D20.get_active_material(0)
	material.albedo_color = Color(RNG.randf_range(0.3, 0.7), RNG.randf_range(0.3, 0.7), RNG.randf_range(0.3, 0.7))
