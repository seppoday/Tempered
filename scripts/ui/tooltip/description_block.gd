extends VBoxContainer

@onready var title_label: Label = %Title
@onready var body_label: RichTextLabel = %Body

func setup(title_text: String, body_bbcode: String) -> void:
	title_label.visible = not title_text.is_empty()
	title_label.text = title_text
	body_label.text = body_bbcode
