extends PanelContainer

@onready var stats_box: VBoxContainer = %StatsBox

const FONT_SIZE: int = 24

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	if not PlayerData.stats_changed.is_connected(_on_stats_changed):
		PlayerData.stats_changed.connect(_on_stats_changed)
	PlayerData.stat_preview_started.connect(_on_preview_started)
	PlayerData.stat_preview_ended.connect(_on_preview_ended)

	_update_ui()


func _on_stats_changed(changed_stat: String) -> void:
	_update_ui(changed_stat)

func _on_preview_started(preview_totals: Dictionary) -> void:
	_update_ui("", preview_totals)

func _on_preview_ended() -> void:
	_update_ui()


func _update_ui(changed_stat: String = "", preview_totals: Dictionary = {}) -> void:
	if not stats_box: return

	var totals := PlayerData.get_total_stats()
	var is_previewing := not preview_totals.is_empty()

	Utilities.clear_children(stats_box)

	for key in ["dmg", "magic", "def", "speed", "luck", "status", "crit", "hp", "dodge"]:
		var delta: float = (preview_totals[key] - totals[key]) if is_previewing else 0.0
		_add_label("%s: %d" % [key.capitalize(), totals[key]], Color.WHITE, FONT_SIZE, key, _format_delta(delta), delta >= 0.0)

	#_add_spacer()
#
	#var hp_delta: float = (preview_totals["hp"] - totals["hp"]) if is_previewing else 0.0
	#_add_label("Max HP: %d" % totals["hp"], Color(0.4, 0.8, 0.4), FONT_SIZE, "hp", _format_delta(hp_delta), hp_delta >= 0.0)
#
	#var dodge_delta: float = (preview_totals["dodge"] - totals["dodge"]) if is_previewing else 0.0
	#_add_label("Dodge: %d%%" % int(totals["dodge"] * 100), Color(0.6, 0.6, 0.65), FONT_SIZE, "dodge", _format_delta(dodge_delta, true), dodge_delta >= 0.0)
#
	#_add_spacer()

	#if changed_stat != "" and not is_previewing:
		#for stat_key in ["dmg", "magic", "def", "speed", "luck", "status", "crit", "hp", "dodge"]:
			#call_deferred("_pop_stat_label", stat_key)


func _format_delta(value: float, is_percent: bool = false) -> String:
	if is_zero_approx(value):
		return ""
	var sign_str := "+" if value > 0.0 else ""
	if is_percent:
		return "%s%d%%" % [sign_str, int(round(value * 100))]
	return "%s%.2f" % [sign_str, value]


func _add_label(text_val: String, color: Color, font_size: int = 11, stat_key: String = "", delta_text: String = "", delta_positive: bool = true) -> Control:
	var row := HBoxContainer.new()
	if stat_key != "": row.set_meta("stat_key", stat_key)
	stats_box.add_child(row)

	var lbl := Label.new()
	lbl.text = text_val
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	row.add_child(lbl)

	if delta_text != "":
		var delta_lbl := Label.new()
		delta_lbl.text = " (%s)" % delta_text
		delta_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4) if delta_positive else Color(1.0, 0.4, 0.4))
		delta_lbl.add_theme_font_size_override("font_size", font_size)
		row.add_child(delta_lbl)

	return row

func _add_spacer() -> void:
	var space = Control.new()
	space.custom_minimum_size = Vector2(0, 4)
	stats_box.add_child(space)

func _pop_stat_label(stat_key: String) -> void:
	for child in stats_box.get_children():
		if child.has_meta("stat_key") and child.get_meta("stat_key") == stat_key:
			_pop_label(child)

func _pop_label(control: Control) -> void:
	Utilities.center_pivot(control)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(control, "scale", Vector2.ONE, 0.15)
