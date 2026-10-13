extends PanelContainer

@onready var skills_box: VBoxContainer = %SkillsBox

const FONT_SIZE: int = 24

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	PlayerData.item_equipped.connect(_on_item_equipped)

	_update_ui()
	

func _on_item_equipped(slot_type: EquipmentSlot.Type, _item_instance: ItemInstance) -> void:
	_update_ui(slot_type)

func _update_ui(changed_slot: int = -1) -> void:
	if not skills_box: return

	Utilities.clear_children(skills_box)

	for slot_type in PlayerData.equipped_items:
		var item: ItemInstance = PlayerData.equipped_items[slot_type]
		if item == null or not item.definition is ItemDefinition:
			continue

		var skill: SkillDefinition = item.equipped_skill if item.equipped_skill else item.definition.default_skill
		if skill == null:
			continue

		var slot_name: String = EquipmentSlot.Type.keys()[slot_type].capitalize()
		var row := _add_label("%s: %s" % [slot_name, tr(skill.skill_name)], Color.WHITE, FONT_SIZE, str(slot_type))

		if slot_type == changed_slot:
			_pop_label(row)


func _add_label(text_val: String, color: Color, font_size: int = 11, stat_key: String = "") -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if stat_key != "": row.set_meta("stat_key", stat_key)
	skills_box.add_child(row)

	var lbl := Label.new()
	lbl.text = text_val
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	row.add_child(lbl)

	return row


func _pop_label(control: Control) -> void:
	Utilities.center_pivot(control)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(control, "scale", Vector2.ONE, 0.15)
