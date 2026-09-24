extends CanvasLayer

@onready var color_rect: ColorRect

func _ready() -> void:
	if false:
		layer = 999  # zawsze na wierzchu wszystkiego innego
		color_rect.color.a = 0.0
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_to_scene(scene_path: String, fade_duration: float = 0.3) -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # blokuj klikanie w trakcie fade'u

	var fade_out := create_tween()
	fade_out.tween_property(color_rect, "color:a", 1.0, fade_duration)
	await fade_out.finished

	get_tree().change_scene_to_file(scene_path)

	var fade_in := create_tween()
	fade_in.tween_property(color_rect, "color:a", 0.0, fade_duration)
	await fade_in.finished

	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
