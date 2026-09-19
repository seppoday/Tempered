extends PopupPanel

signal assignment_confirmed(face: int, skill: SkillDefinition)

@onready var faces_grid: GridContainer = %FacesGrid

var _target_item: ItemInstance
var _pending_skill: SkillDefinition

func setup(target_item: ItemInstance, skill: SkillDefinition) -> void:
	_target_item = target_item
	_pending_skill = skill
	_rebuild_grid()
	popup_centered()

func _rebuild_grid() -> void:
	for child in faces_grid.get_children():
		child.queue_free()

	var max_face: int = GameEnums.DICE_PROGRESSION[_target_item.dice_level]
	for face in range(1, max_face + 1):
		var assigned: SkillDefinition = _target_item.slot_assignments.get(face)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(128, 128)
		btn.text = str(face) + ("\n" + assigned.skill_name if assigned else "\n—")
		btn.pressed.connect(_on_face_pressed.bind(face, assigned))
		faces_grid.add_child(btn)

func _on_face_pressed(face: int, existing_skill: SkillDefinition) -> void:
	if existing_skill == null:
		_confirm_face(face)
		return

	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Nadpisać \"%s\" skillem \"%s\" w polu %d?" % [
		existing_skill.skill_name, _pending_skill.skill_name, face
	]
	confirm.confirmed.connect(func():
		_confirm_face(face)
		confirm.queue_free()
	)
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered()

func _confirm_face(face: int) -> void:
	assignment_confirmed.emit(face, _pending_skill)
	queue_free()
