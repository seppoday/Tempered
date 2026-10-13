extends HBoxContainer

@onready var icon_rect: TextureRect = %Icon
@onready var prefix_label: Label = %Prefix
@onready var suffix_label: Label = %Suffix

func setup(percentage: int, icon: Texture2D, stat_name: String, stat_color: Color, raw_stat: float, scaling_contrib: float) -> void:
	prefix_label.text = "+%d%% of" % percentage

	icon_rect.visible = icon != null
	icon_rect.texture = icon

	if raw_stat > 0:
		var contrib_str: String
		if is_equal_approx(scaling_contrib, round(scaling_contrib)):
			contrib_str = "x%d" % int(round(scaling_contrib))
		else:
			contrib_str = "x%.1f" % scaling_contrib
		suffix_label.text = "%s (%s)" % [stat_name, contrib_str]
	else:
		suffix_label.text = stat_name

	suffix_label.add_theme_color_override("font_color", stat_color)
