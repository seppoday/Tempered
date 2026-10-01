class_name DiceRoller
extends Node3D

signal dice_spawned(dice: Array[RigidBody3D])
signal dice_settled(results: Array[Dictionary])

@export var die_scenes: Dictionary = {
	6: preload("uid://bkmu5apsdlwbt"),
	20: preload("uid://dg4qey0lvwj0y"),
}

@export_group("Fizyka Stuknięcia (Table Bump)")
@export var bump_force_min: float = 3.5
@export var bump_force_max: float = 5.0
@export var drift_force: float = 1.2        # Siła przesunięcia na boki
@export var torque_strength: float = 3.5    # Siła rotacji przy podskoku

@export_group("Środek masy (kontrola lądowania)")
@export var center_of_mass_weight: float = 0.15 

var dice_group: Array[RigidBody3D] = []
var dice_items: Array[ItemInstance] = []
var pending_results: Array[Dictionary] = []


func _ready() -> void:
	pass


func spawn_dice() -> void:
	_spawn_dice_for_equipped_items()


func roll() -> void:
	_roll_results_for_equipped_items()
	AudioManager.play_sfx(AudioLibrary.get_sfx(AudioKeys.SFX_ROLL))
	await _bump_table()


func resync_with_equipment() -> void:
	_spawn_dice_for_equipped_items()


func _spawn_dice_for_equipped_items() -> void:
	_clear_previous_dice()

	var equipped_dice_items: Array[ItemInstance] = []
	for slot_type in PlayerData.equipped_items:
		var item: ItemInstance = PlayerData.equipped_items[slot_type]
		if item != null and item.definition is ItemDefinition:
			equipped_dice_items.append(item)

	var rest_positions := calculate_grid_positions(equipped_dice_items.size(), 2, 0.4)

	for i in range(equipped_dice_items.size()):
		var item := equipped_dice_items[i]
		var max_face: int = GameEnums.DICE_PROGRESSION[item.dice_level]

		var die_scene: PackedScene = die_scenes.get(max_face)
		if die_scene == null:
			die_scene = die_scenes.get(6)
		if die_scene == null: continue

		var die := die_scene.instantiate() as RigidBody3D
		add_child(die)
		
		die.setup(GameEnums.get_rarity_color(item.definition.rarity))
		die.freeze = false
		die.linear_damp = 0.8
		die.angular_damp = 0.8
		die.global_position = rest_positions[i]
		die.rotation = Vector3.ZERO

		dice_group.append(die)
		dice_items.append(item)

	dice_spawned.emit(dice_group)


func _clear_previous_dice() -> void:
	for die in dice_group:
		Utilities.safe_free(die)
	dice_group.clear()
	dice_items.clear()


func _roll_results_for_equipped_items() -> void:
	pending_results.clear()
	for i in range(dice_group.size()):
		var item := dice_items[i]
		var roll_result := item.roll_skill()
		if roll_result.is_empty():
			pending_results.append({})
			continue

		pending_results.append({
			"item": item,
			"skill": roll_result["skill"],
			"dice_level_on_item": roll_result["dice_level_on_item"],
			"face": roll_result["face"],
		})


# Nowa, zsynchronizowana metoda "stuknięcia"
func _bump_table() -> void:
	# Odpalamy fizykę dla każdej kości równolegle (bez await w pętli)
	for i in range(dice_group.size()):
		_bump_single_die(i)

	# Czekamy aż wszystkie (które wystartowały niemal jednocześnie) opadną
	await _wait_for_dice_to_stop()
	await _snap_to_perfect_face()

	dice_settled.emit(pending_results)


# Ta funkcja wykonuje się asynchronicznie dla każdej kości
func _bump_single_die(index: int) -> void:
	var die := dice_group[index]
	var result := pending_results[index]
	if result.is_empty() or not is_instance_valid(die): return

	# Mikro-opóźnienie (0.01 - 0.04s) – kości startują praktycznie razem,
	# ale nie w dokładnie tej samej klatce obrazu, co daje naturalny efekt.
	if dice_group.size() > 1:
		await get_tree().create_timer(RNG.randf_range(0.01, 0.04)).timeout

	if not is_instance_valid(die): return

	die.freeze = false
	die.linear_damp = 0.5
	die.angular_damp = 0.5

	# Środek ciężkości
	var local_up: Vector3 = DiceFaceMapper.get_local_up(result["dice_level_on_item"], result["face"])
	die.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	die.center_of_mass = -local_up * center_of_mass_weight

	# Obliczenie sił
	var up_force = Vector3.UP * RNG.randf_range(bump_force_min, bump_force_max)
	var drift = Vector3(RNG.randf_range(-1.0, 1.0), 0.0, RNG.randf_range(-1.0, 1.0)).normalized() * drift_force
	var total_impulse = up_force + drift

	var torque = Vector3(RNG.randf_range(-1, 1), RNG.randf_range(-1, 1), RNG.randf_range(-1, 1)).normalized() * torque_strength

	# Fizyczny skok
	die.apply_central_impulse(total_impulse)
	die.apply_torque_impulse(torque)


func _wait_for_dice_to_stop() -> void:
	var timeout = 0.0
	while timeout < 3.0:
		await get_tree().create_timer(0.05).timeout
		timeout += 0.05

		if timeout > 0.6:
			for die in dice_group:
				if is_instance_valid(die):
					die.linear_damp = lerp(die.linear_damp, 5.0, 0.15)
					die.angular_damp = lerp(die.angular_damp, 6.0, 0.15)

		var all_stopped = true
		for die in dice_group:
			if not is_instance_valid(die): continue
			if die.linear_velocity.length() > 0.05 or die.angular_velocity.length() > 0.05:
				all_stopped = false
				break

		if all_stopped and timeout > 0.6:
			break


func _snap_to_perfect_face() -> void:
	var tweens: Array[Tween] = []
	
	for i in range(dice_group.size()):
		var die := dice_group[i]
		if not is_instance_valid(die) or pending_results[i].is_empty(): continue

		die.freeze = true

		var landed_face = DiceFaceMapper.get_landed_face(die, pending_results[i]["dice_level_on_item"])
		pending_results[i]["face"] = landed_face

		var local_up: Vector3 = DiceFaceMapper.get_local_up(pending_results[i]["dice_level_on_item"], landed_face)
		var current_world_up = (die.global_basis * local_up).normalized()
		var correction_q = Quaternion(current_world_up, Vector3.UP)

		var start_q = die.global_basis.get_rotation_quaternion().normalized()
		var end_q = (correction_q * start_q).normalized()

		var tween = create_tween().set_parallel(true)
		tween.tween_method(func(t: float):
			if is_instance_valid(die):
				die.global_basis = Basis(start_q.slerp(end_q, t))
		, 0.0, 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		var target_y = 0.002 if pending_results[i]["dice_level_on_item"] <= 6 else 0.005
		tween.tween_property(die, "global_position:y", target_y, 0.2).set_trans(Tween.TRANS_CUBIC)

		tweens.append(tween)

	if not tweens.is_empty():
		await tweens[-1].finished


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
		positions.append(Vector3(x, 0.02, z))
	return positions
