extends StaticBody2D

signal roll_done(index: int)

@onready var faces = $Faces

var is_rolling: bool = false
var current_index: int = 0

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_roll_dice()

func _roll_dice() -> void:
	var duration: float = 1.0

	is_rolling = true

	while duration > 0.0:
		var new_index = faces.get_children().pick_random().get_index()
		faces.get_child(current_index).visible = false
		faces.get_child(new_index).visible = true

		await get_tree().create_timer(0.1).timeout

		current_index = new_index
		duration -= 0.1
	
	is_rolling = false

	roll_done.emit(current_index + 1)
	print(current_index + 1)
