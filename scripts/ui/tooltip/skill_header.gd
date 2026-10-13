extends HBoxContainer

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %Name
@onready var subtitle_label: RichTextLabel = %Subtitle

func setup(skill_icon: Texture2D, skill_name: String, subtitle_bbcode: String) -> void:
	var has_name := not skill_name.is_empty()
	icon_rect.visible = has_name and skill_icon != null
	icon_rect.texture = skill_icon
	name_label.visible = has_name
	name_label.text = skill_name

	subtitle_label.text = subtitle_bbcode
