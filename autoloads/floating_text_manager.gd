extends CanvasLayer
# Autoload

@export var floating_text_scene: PackedScene = preload("res://scenes/UI/floating_text.tscn")

const COLOR_DAMAGE := Color(1.0, 0.3, 0.3)
const COLOR_HEAL := Color(0.3, 1.0, 0.4)
const COLOR_DODGE := Color(0.6, 0.6, 0.65)
const COLOR_INFO := Color(0.167, 0.167, 0.192, 1.0)

func _ready() -> void:
	layer = 998


func spawn_world(text: String, world_position: Vector3, color: Color = Color.WHITE) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(world_position):
		return
	spawn_screen(text, camera.unproject_position(world_position), color)


func spawn_screen(text: String, screen_position: Vector2, color: Color = Color.WHITE) -> void:
	var text_node := floating_text_scene.instantiate()
	add_child(text_node)

	var random_offset := Vector2(RNG.randf_range(-4.0, 4.0), RNG.randf_range(-6.0, -2.0))
	text_node.global_position = screen_position + random_offset
	text_node.setup(text, color)

func spawn_damage(value: int, world_position: Vector3) -> void:
	var text = Utilities.format_large_number(value)
	spawn_world("-" + text, world_position, COLOR_DAMAGE)

func spawn_heal(value: int, position: Vector2) -> void:
	var text = Utilities.format_large_number(value)
	spawn_screen("+" + text, position, COLOR_HEAL)

func spawn_dodge(world_position: Vector3) -> void:
	spawn_world("DODGE!", world_position, COLOR_DODGE)

func spawn_info(value: String, world_position: Vector3) -> void:
	spawn_world(value, world_position, COLOR_INFO)
