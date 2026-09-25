class_name DiceRoller
extends Node3D

signal dice_spawned(dice: Array[RigidBody3D])
signal dice_settled(results: Array[Dictionary])

@export var die_scenes: Dictionary = {
	6: preload("res://scenes/dice/die_d6.tscn"),
	20: preload("res://scenes/dice/die_d20.tscn"),
}

@export_group("Rzut z ręki")
@export var throw_origin: Node3D  ## Marker3D symulujący dłoń — umieść go z boku/nad stołem, z dala od strefy lądowania.
@export var landing_center: Node3D  ## Opcjonalnie: punkt, w który celujemy rzutem. Puste = Vector3.ZERO.
@export var hand_cluster_spacing: float = 0.15  ## Odstęp między kośćmi w dłoni, żeby się nie nakładały przy starcie rzutu.
@export var throw_strength_min: float = 2.0
@export var throw_strength_max: float = 3.5
@export var arc_height_min: float = 1.5
@export var arc_height_max: float = 2.5
@export var throw_spread: float = 0.6  ## Losowe odchylenie na boki, żeby rzut nie leciał idealnie po linii.

@export_group("Siła obrotu")
@export var torque_min: Vector3 = Vector3(-1.0, -1.0, -1.0)
@export var torque_max: Vector3 = Vector3(1.5, 1.5, 1.5)

@export_group("Środek masy (kontrola lądowania)")
@export var center_of_mass_weight_small: float = 0.12
@export var center_of_mass_weight_large: float = 0.18
@export var large_dice_threshold: int = 10

var dice_group: Array[RigidBody3D] = []
var dice_items: Array[ItemInstance] = []
var pending_results: Array[Dictionary] = []


func _ready() -> void:
	pass  # spawn wołany jawnie z main_3d_scene, PO podłączeniu sygnałów

func spawn_dice() -> void:
	_spawn_dice_for_equipped_items()


func roll() -> void:
	_roll_results_for_equipped_items()
	AudioManager.play_sfx(AudioLibrary.get_sfx(AudioKeys.SFX_ROLL))
	await _throw_all_dice()


func resync_with_equipment() -> void:
	_spawn_dice_for_equipped_items()


func _spawn_dice_for_equipped_items() -> void:
	_clear_previous_dice()

	var equipped_dice_items: Array[ItemInstance] = []
	for slot_type in PlayerData.equipped_items:
		var item: ItemInstance = PlayerData.equipped_items[slot_type]
		if item != null and item.definition is ItemDefinition:
			equipped_dice_items.append(item)

	var rest_positions := calculate_grid_positions(equipped_dice_items.size(), 2, 0.5)

	for i in range(equipped_dice_items.size()):
		var item := equipped_dice_items[i]
		var max_face: int = GameEnums.DICE_PROGRESSION[item.dice_level]

		var die_scene: PackedScene = die_scenes.get(max_face)
		if die_scene == null:
			Log.warning("Brak modelu kości d%d — używam d6 dla %s" % [max_face, item.definition.name])
			die_scene = die_scenes.get(6)
		if die_scene == null:
			continue

		var die := die_scene.instantiate() as RigidBody3D
		add_child(die)
		die.freeze = false
		die.linear_damp = 0.2
		die.angular_damp = 0.2
		die.global_position = rest_positions[i]

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
			Log.warning("Pomijam przedmiot '%s' — roll_skill() zwrócił pusty wynik (sprawdź default_skill)" % item.definition.name)
			pending_results.append({})
			continue

		pending_results.append({
			"item": item,
			"skill": roll_result["skill"],
			"dice_level_on_item": roll_result["dice_level_on_item"],
			"face": roll_result["face"],
		})


func _throw_all_dice() -> void:
	var origin: Vector3 = throw_origin.global_position if throw_origin else Vector3(0.0, 1.5, -1.0)
	var target_center: Vector3 = landing_center.global_position if landing_center else Vector3.ZERO
	var hand_offsets := calculate_grid_positions(dice_group.size(), 2, hand_cluster_spacing)

	for i in range(dice_group.size()):
		var die := dice_group[i]
		var result := pending_results[i]
		if result.is_empty():
			continue

		# Zamrożony teleport do "dłoni" — bezpieczny nawet jeśli kość leżała daleko od tego miejsca.
		die.freeze = true
		die.global_position = origin + hand_offsets[i]
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO
		die.rotation = Vector3(RNG.randf_range(0, TAU), RNG.randf_range(0, TAU), RNG.randf_range(0, TAU))
		die.freeze = false

		var local_up: Vector3 = DiceFaceMapper.get_local_up(result["dice_level_on_item"], result["face"])
		die.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		var weight_strength = center_of_mass_weight_large if result["dice_level_on_item"] >= large_dice_threshold else center_of_mass_weight_small
		die.center_of_mass = -local_up * weight_strength

		# Kierunek: od dłoni w stronę środka stołu, plus łuk w górę i lekki rozrzut na boki.
		var to_target := target_center - die.global_position
		to_target.y = 0.0
		var throw_dir := to_target.normalized() if to_target.length() > 0.01 else Vector3.FORWARD

		var push_force := throw_dir * RNG.randf_range(throw_strength_min, throw_strength_max)
		push_force.y = RNG.randf_range(arc_height_min, arc_height_max)
		push_force += throw_dir.cross(Vector3.UP) * RNG.randf_range(-throw_spread, throw_spread)

		var torque = Vector3(
			RNG.randf_range(torque_min.x, torque_max.x),
			RNG.randf_range(torque_min.y, torque_max.y),
			RNG.randf_range(torque_min.z, torque_max.z)
		)

		die.apply_central_impulse(push_force)
		die.apply_torque_impulse(torque)

	await _wait_for_dice_to_stop_completely()

	var tweens: Array[Tween] = []
	for i in range(dice_group.size()):
		var die := dice_group[i]
		if not is_instance_valid(die) or pending_results[i].is_empty(): continue

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

		var safe_floor_y = 0.001 if pending_results[i]["dice_level_on_item"] <= 6 else 0.002
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
		positions.append(Vector3(x, 0.02, z))
	return positions
