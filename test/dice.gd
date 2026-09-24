extends StaticBody2D

signal roll_done(value: int)

@export var dice_name: String = "D6"

@onready var faces: Node2D = $Faces

var is_rolling: bool = false
var current_index: int = 0

func _ready() -> void:
	_show_only(current_index)

func roll_to(target_value: int) -> void:
	if is_rolling:
		return
	_animate_to(target_value)

func _animate_to(target_value: int) -> void:
	is_rolling = true
	var face_count := faces.get_child_count()
	if face_count == 0:
		is_rolling = false
		return

	var steps := 12
	var base_delay := 0.05

	for i in steps:
		var is_last_step := i == steps - 1
		var new_index: int

		if is_last_step:
			new_index = target_value - 1  # docelowa ścianka, ZNANA z zewnątrz
		else:
			new_index = RNG.randi_range(0, face_count - 1)  # czysto wizualne "miganie"

		_show_only(new_index)
		current_index = new_index

		var t := float(i) / float(steps)
		var delay := base_delay + t * t * 0.15
		await get_tree().create_timer(delay).timeout

	is_rolling = false
	roll_done.emit(target_value)
	Log.print("%s → %d" % [dice_name, target_value])

func _show_only(index: int) -> void:
	for c in faces.get_children():
		c.visible = false
	if index >= 0 and index < faces.get_child_count():
		faces.get_child(index).visible = true
