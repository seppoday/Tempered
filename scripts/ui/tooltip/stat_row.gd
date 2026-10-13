extends HBoxContainer

@onready var icon_rect: TextureRect = %Icon
@onready var value_label: Label = %Value
@onready var label_label: Label = %Label

func setup(icon: Texture2D, value: float, label_text: String, color: Color) -> void:
	icon_rect.visible = icon != null
	icon_rect.texture = icon

	value_label.text = "%d" % int(round(value))
	value_label.add_theme_color_override("font_color", color.lightened(0.4))

	label_label.text = label_text
	label_label.add_theme_color_override("font_color", color.darkened(0.35))
