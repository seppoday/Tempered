extends HBoxContainer

@onready var icon_rect: TextureRect = %Icon
@onready var value_label: Label = %Value
@onready var label_label: Label = %Label

## value = aktualna wartość
## next_value >= 0 i różna od value → "2 → 3" (3 na zielono)
## next_value < 0 → tylko aktualna wartość
func setup(icon: Texture2D, value: float, label_text: String, color: Color, next_value: float = -1.0) -> void:
	icon_rect.visible = icon != null
	icon_rect.texture = icon

	value_label.text = _format_num(value)
	value_label.add_theme_color_override("font_color", color.lightened(0.4))

	if next_value >= 0.0 and not is_equal_approx(next_value, value):
		_ensure_arrow_next(_format_num(next_value))
	else:
		_clear_arrow_next()

	label_label.text = label_text
	label_label.add_theme_color_override("font_color", color.darkened(0.35))


func _format_num(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return "%d" % int(round(v))
	return "%.1f" % v


func _ensure_arrow_next(next_txt: String) -> void:
	var arrow := get_node_or_null("Arrow") as Label
	var next_lbl := get_node_or_null("NextValue") as Label

	if arrow == null:
		arrow = Label.new()
		arrow.name = "Arrow"
		arrow.text = " → "
		arrow.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		add_child(arrow)
		move_child(arrow, value_label.get_index() + 1)
	else:
		arrow.visible = true

	if next_lbl == null:
		next_lbl = Label.new()
		next_lbl.name = "NextValue"
		add_child(next_lbl)
		move_child(next_lbl, arrow.get_index() + 1)

	next_lbl.text = next_txt
	next_lbl.visible = true
	next_lbl.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55))


func _clear_arrow_next() -> void:
	var arrow := get_node_or_null("Arrow") as Label
	var next_lbl := get_node_or_null("NextValue") as Label
	if arrow:
		arrow.visible = false
	if next_lbl:
		next_lbl.visible = false
