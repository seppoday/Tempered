extends Node3D

@export var dice_tag_scene: PackedScene
@export var roll_button: Button
@export var result_label: Label
@export var dice_roller: DiceRoller

@onready var camera = $Camera3D
@onready var canvas_layer = %MainSceneCanvasLayer

var active_tags: Array[Control] = []
var selected_tags: Array[PanelContainer] = []
var pending_results: Array[Dictionary] = []
var is_rolling := false
var update_tags := false


func _ready() -> void:
	roll_button.pressed.connect(_on_roll_button_pressed)
	dice_roller.dice_spawned.connect(_on_dice_spawned)
	dice_roller.dice_settled.connect(_on_dice_settled)
	result_label.text = "Naciśnij RZUĆ"


func _process(delta: float) -> void:
	if update_tags:
		_update_all_tag_positions(delta)


func _update_all_tag_positions(delta: float) -> void:
	var count = min(dice_roller.dice_group.size(), active_tags.size())
	if count == 0: return

	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 16.0
	var tag_rects: Array[Rect2] = []

	for i in range(count):
		var die = dice_roller.dice_group[i]
		var tag = active_tags[i]

		if not is_instance_valid(die) or not is_instance_valid(tag):
			tag_rects.append(Rect2())
			continue

		var world_pos = die.global_position + Vector3(0, 1.2, 0)
		if camera.is_position_behind(world_pos):
			tag_rects.append(Rect2())
			continue

		var screen_pos = camera.unproject_position(world_pos)
		var tag_size = tag.size if tag.size != Vector2.ZERO else Vector2(50, 50)
		var half_size = tag_size * 0.5
		tag_rects.append(Rect2(screen_pos - half_size, tag_size))

	for iter in range(4):
		for i in range(count):
			if tag_rects[i].size == Vector2.ZERO: continue
			for j in range(i + 1, count):
				if tag_rects[j].size == Vector2.ZERO: continue
				if tag_rects[i].intersects(tag_rects[j]):
					var dir = (tag_rects[i].get_center() - tag_rects[j].get_center()).normalized()
					if dir == Vector2.ZERO: dir = Vector2.UP
					var overlap = 15.0
					tag_rects[i].position += dir * overlap
					tag_rects[j].position -= dir * overlap

	for i in range(count):
		var tag = active_tags[i]
		var rect = tag_rects[i]
		if rect.size == Vector2.ZERO: continue

		var target_pos = rect.position
		target_pos.x = clamp(target_pos.x, margin, viewport_size.x - margin - rect.size.x)
		target_pos.y = clamp(target_pos.y, margin, viewport_size.y - margin - rect.size.y)

		if not tag.visible or tag.position == Vector2.ZERO:
			tag.position = target_pos
		else:
			tag.position = tag.position.lerp(target_pos, delta * 18.0)


func _on_roll_button_pressed() -> void:
	UIAnim.pop(roll_button)
	if is_rolling: return
	is_rolling = true
	update_tags = false
	roll_button.disabled = true
	result_label.text = "Toczenie kości..."
	dice_roller.roll()


func _on_dice_spawned(dice: Array[RigidBody3D], results: Array[Dictionary]) -> void:
	_clear_previous_tags()
	pending_results = results

	for i in range(dice.size()):
		var tag := dice_tag_scene.instantiate() as Control
		tag.toggled.connect(_on_card_toggled)
		canvas_layer.add_child(tag)
		active_tags.append(tag)
		tag.hide()


func _on_dice_settled(results: Array[Dictionary]) -> void:
	pending_results = results
	update_tags = true
	await _reveal_results()


func _on_card_toggled(card: PanelContainer, wants_selected: bool) -> void:
	if wants_selected:
		if selected_tags.size() >= PlayerData.picks_per_cycle:
			card.set_selected(false)
			return
		selected_tags.append(card)
		card.set_selected(true)
		AudioManager.play_sfx(AudioLibrary.get_ui(AudioKeys.SFX_CLICK), -5.0)
	else:
		selected_tags.erase(card)
		card.set_selected(false)
		AudioManager.play_sfx(AudioLibrary.get_ui(AudioKeys.SFX_CLICK), -5.0)


func _clear_previous_tags() -> void:
	for tag in active_tags:
		if is_instance_valid(tag): tag.queue_free()
	active_tags.clear()
	selected_tags.clear()


func _reveal_results() -> void:
	for i in range(dice_roller.dice_group.size()):
		var tag := active_tags[i]
		var result: Dictionary = pending_results[i]

		tag.set_value(result["face"], result["item"].definition.name)
		tag.set_icon(result["skill"].icon)
		_update_all_tag_positions(0.016)
		tag.show()
		tag.pop_in(0.0)

		await get_tree().create_timer(0.08).timeout
		AudioManager.play_sfx_random_pitch(AudioLibrary.get_sfx(AudioKeys.SFX_POP), -6.0, 0.5, 1.5)

	update_tags = false
	await _align_tags_to_center_line()

	result_label.text = "Wybierz karty"
	is_rolling = false
	roll_button.disabled = false


func _align_tags_to_center_line() -> void:
	var count = active_tags.size()
	if count == 0: return

	var viewport_size = get_viewport().get_visible_rect().size
	var spacing = 20.0

	var total_width = 0.0
	var tag_widths: Array[float] = []

	for tag in active_tags:
		if is_instance_valid(tag):
			var w = tag.size.x if tag.size.x > 0 else 120.0
			tag_widths.append(w)
			total_width += w
		else:
			tag_widths.append(0.0)

	total_width += spacing * (count - 1)

	var start_x = (viewport_size.x - total_width) * 0.5
	var target_y = viewport_size.y * 0.5

	var align_tween = create_tween().set_parallel(true)
	var current_x = start_x

	AudioManager.play_sfx(AudioLibrary.get_sfx(AudioKeys.SFX_SWOOSH))

	for i in range(count):
		var tag = active_tags[i]
		if not is_instance_valid(tag): continue

		var tag_height = tag.size.y if tag.size.y > 0 else 50.0
		var target_pos = Vector2(current_x, target_y - (tag_height * 0.5))

		align_tween.tween_property(tag, "position", target_pos, 0.65)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)

		current_x += tag_widths[i] + spacing

	await align_tween.finished
