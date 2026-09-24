class_name DiceRoller
extends Node3D

signal dice_spawned(dice: Array[RigidBody3D], results: Array[Dictionary])
signal dice_settled(results: Array[Dictionary])

@export var die_scenes: Dictionary = {
	6: preload("res://scenes/dice/die_d6.tscn"),
	20: preload("res://scenes/dice/die_d20.tscn"),
}

const DICE_ROLL = preload("uid://r47f1p7ggf02")

var dice_group: Array[RigidBody3D] = []
var pending_results: Array[Dictionary] = []


## Wywoływane z zewnątrz, żeby rozpocząć cały cykl: spawn + rzut.
func roll() -> void:
	AudioManager.play_sfx(AudioLibrary.get_sfx(AudioKeys.SFX_ROLL))
	_spawn_dice_for_equipped_items()
	await _throw_all_dice()


func _spawn_dice_for_equipped_items() -> void:
	_clear_previous_dice()
	pending_results.clear()

	for slot_type in PlayerData.equipped_items:
		var item: ItemInstance = PlayerData.equipped_items[slot_type]
		if item == null or not item.definition is ItemDefinition: continue

		var max_face: int = GameEnums.DICE_PROGRESSION[item.dice_level]
		var roll_result := item.roll_skill()
		if roll_result.is_empty():
			Log.warning("Pomijam przedmiot '%s' — roll_skill() zwrócił pusty wynik (sprawdź default_skill)" % item.definition.name)
			continue

		var die_scene: PackedScene = die_scenes.get(max_face)
		if die_scene == null:
			Log.warning("Brak modelu kości d%d — używam d6 dla %s" % [max_face, item.definition.name])
			die_scene = die_scenes.get(6)

		if die_scene == null: continue

		var die := die_scene.instantiate() as RigidBody3D
		add_child(die)
		Log.print(die.global_position)
		die.freeze = true
		die.linear_damp = 0.2
		die.angular_damp = 0.2
		dice_group.append(die)

		pending_results.append({
			"item": item,
			"skill": roll_result["skill"],
			"dice_level_on_item": roll_result["dice_level_on_item"],
			"face": roll_result["face"],
		})

	dice_spawned.emit(dice_group, pending_results)


func _clear_previous_dice() -> void:
	for die in dice_group:
		Utilities.safe_free(die)
		#if is_instance_valid(die): die.queue_free()
	dice_group.clear()


func _throw_all_dice() -> void:
	var spawn_positions := calculate_grid_positions(dice_group.size(), 3, 0.2)

	for i in range(dice_group.size()):
		var die := dice_group[i]
		var result := pending_results[i]

		die.freeze = false

		var random_offset = Vector3(RNG.randf_range(-0.1, 0.1), RNG.randf_range(0.0, 0.02), RNG.randf_range(-0.1, 0.1))
		die.global_position = spawn_positions[i] + random_offset

		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO

		var local_up: Vector3 = DiceFaceMapper.get_local_up(result["dice_level_on_item"], result["face"])

		die.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		var weight_strength = 0.18 if result["dice_level_on_item"] >= 10 else 0.12
		die.center_of_mass = -local_up * weight_strength

		die.rotation = Vector3(RNG.randf_range(0, TAU), RNG.randf_range(0, TAU), RNG.randf_range(0, TAU))

		var push_force = Vector3(RNG.randf_range(-1.5, 3), RNG.randf_range(-1.5, 1), RNG.randf_range(-1.5, 3))
		var torque = Vector3(RNG.randf_range(-1.0, 1.5), RNG.randf_range(-1.0, 1.5), RNG.randf_range(-1.0, 1.5))

		die.apply_central_impulse(push_force)
		die.apply_torque_impulse(torque)

	await _wait_for_dice_to_stop_completely()

	var tweens: Array[Tween] = []
	for i in range(dice_group.size()):
		var die := dice_group[i]
		if not is_instance_valid(die): continue

		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO
		die.freeze = true

		var landed_face = DiceFaceMapper.get_landed_face(die, pending_results[i]["dice_level_on_item"])
		pending_results[i]["face"] = landed_face

		var local_up: Vector3 = DiceFaceMapper.get_local_up(pending_results[i]["dice_level_on_item"], landed_face)

		var current_world_up = (die.global_basis * local_up).normalized()
		var correction_q = Quaternion(current_world_up, Vector3.UP)

		var start_q = die.global_basis.get_rotation_quaternion().normalized()
		var end_q = (correction_q * start_q).normalized()

		var safe_floor_y = 0.01 if pending_results[i]["dice_level_on_item"] <= 6 else 0.02
		var target_pos = Vector3(die.global_position.x, safe_floor_y, die.global_position.z)

		var tween = create_tween().set_parallel(true)

		tween.tween_method(func(t: float):
			if is_instance_valid(die):
				die.global_basis = Basis(start_q.slerp(end_q, t))
		, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		tween.tween_property(die, "global_position", target_pos, 0.35)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		tweens.append(tween)

	if not tweens.is_empty():
		await tweens[-1].finished

	dice_settled.emit(pending_results)


func _wait_for_dice_to_stop_completely() -> void:
	var timeout = 0.0
	while timeout < 4.5:
		await get_tree().create_timer(0.05).timeout
		timeout += 0.05

		var all_stopped = true
		for die in dice_group:
			if not is_instance_valid(die): continue

			if timeout > 0.8:
				die.linear_damp = lerp(die.linear_damp, 4.0, 0.1)
				die.angular_damp = lerp(die.angular_damp, 5.5, 0.1)

			var is_moving = die.linear_velocity.length() > 0.03 or die.angular_velocity.length() > 0.03
			if is_moving and not die.sleeping:
				all_stopped = false

		if all_stopped and timeout > 0.8:
			break


func calculate_grid_positions(total_count: int, columns: int, spacing: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var rows = ceil(float(total_count) / columns)
	var offset_x = (columns - 1) * spacing * 0.5
	var offset_z = (rows - 1) * spacing * 0.5

	for i in range(total_count):
		var col = i % columns
		var row = i / columns
		var x = (col * spacing) - offset_x
		var z = (row * spacing) - offset_z
		positions.append(Vector3(x, 0.1, z))
	return positions
