extends Label

func setup(text_value: String, color: Color) -> void:
	text = text_value
	add_theme_color_override("font_color", color)
