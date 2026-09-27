class_name DiceHand
extends Node

signal results_ready

@export var dice_tag_scene: PackedScene
@export var camera: Camera3D
@export var canvas_layer: CanvasLayer
@export var dice_roller: DiceRoller
@export var enemy_spawn_point: Node3D
@export var hp_progress_bar: ProgressBar
@export var result_label: Label
@export var dice_tag_cration_wait_time: float = 0.12 # Odrobinę większe dla lepszego efektu domino

var active_tags: Array[Control] = []
var selected_tags: Array[PanelContainer] = []
var resolving_tags: Array[Control] = []
var pending_results: Array[Dictionary] = []

var is_rolling: bool = false


func _ready() -> void:
	dice_roller.dice_spawned.connect(_on_dice_spawned)
	dice_roller.dice_settled.connect(_on_dice_settled)
	CombatManager.effect_applied.connect(_on_combat_effect_applied)


# Usunęliśmy _process i śledzenie pozycji kości w 3D, bo tagi lądują od razu na środku.

func start_rolling() -> void:
	is_rolling = true


func has_selection() -> bool:
	return not selected_tags.is_empty()


func confirm_selection() -> Array[Dictionary]:
	selected_tags.sort_custom(func(a, b): return a.position.x < b.position.x)

	resolving_tags.clear()
	for tag in selected_tags:
		if is_instance_valid(tag):
			resolving_tags.append(tag)

	var selected_results: Array[Dictionary] = []
	for tag in resolving_tags:
		var index := active_tags.find(tag)
		if index != -1:
			selected_results.append(pending_results[index])

	await _animate_selection_and_centering()
	return selected_results


func reset_for_new_roll() -> void:
	for tag in active_tags:
		if is_instance_valid(tag):
			tag.hide()
			tag.offset_transform_scale = Vector2.ONE
			tag.modulate.a = 1.0
			tag.set_selected(false)
			tag.set_locked(false)
	selected_tags.clear()
	resolving_tags.clear()


func _on_dice_spawned(dice: Array[RigidBody3D]) -> void:
	_clear_previous_tags()

	for i in range(dice.size()):
		var tag := dice_tag_scene.instantiate() as Control
		tag.toggled.connect(_on_card_toggled)
		canvas_layer.add_child(tag)
		active_tags.append(tag)
		tag.hide()


func _on_dice_settled(results: Array[Dictionary]) -> void:
	pending_results = results
	await _reveal_results_domino() # Nowa, uproszczona metoda domino

	if not CombatManager.is_game_over:
		results_ready.emit()


func _on_card_toggled(card: PanelContainer, wants_selected: bool) -> void:
	if wants_selected:
		if selected_tags.size() >= PlayerData.picks_per_cycle:
			card.set_selected(false)
			return
		selected_tags.append(card)
		card.set_selected(true)
		AudioManager.play_sfx(AudioLibrary.get_ui(AudioKeys.UI_CLICK), -5.0)
	else:
		selected_tags.erase(card)
		card.set_selected(false)
		AudioManager.play_sfx(AudioLibrary.get_ui(AudioKeys.UI_CLICK), -5.0)

	_update_lock_states()

func _update_lock_states() -> void:
	var limit_reached := selected_tags.size() >= PlayerData.picks_per_cycle
	
	for tag in active_tags:
		if is_instance_valid(tag):
			# Karta ma być zablokowana TYLKO wtedy, gdy osiągnięto limit 
			# ORAZ ta konkretna karta nie jest obecnie wybrana.
			var is_tag_selected = tag in selected_tags
			var should_lock = limit_reached and not is_tag_selected
			
			tag.set_locked(should_lock)

func _clear_previous_tags() -> void:
	for tag in active_tags:
		Utilities.safe_free(tag)
	active_tags.clear()
	selected_tags.clear()
	resolving_tags.clear()

func _reveal_results_domino() -> void:
	var count = active_tags.size()
	if count == 0: return

	var viewport_size = camera.get_viewport().get_visible_rect().size
	var spacing = 20.0

	# 1. Najpierw obliczamy szerokość całego rzędu, aby go idealnie wycentrować
	var total_width = 0.0
	var tag_widths: Array[float] = []

	for tag in active_tags:
		if is_instance_valid(tag):
			var w = tag.size.x if tag.size.x > 0 else 120.0 # fallback
			tag_widths.append(w)
			total_width += w
		else:
			tag_widths.append(0.0)

	total_width += spacing * (count - 1)

	var start_x = (viewport_size.x - total_width) * 0.5
	var target_y = viewport_size.y * 0.5
	var current_x = start_x

	var last_tween: Tween = null

	# 2. Spawnujemy i ujawniamy tagi jeden po drugim (efekt domino)
	for i in range(count):
		var tag = active_tags[i]
		if not is_instance_valid(tag): continue

		var result: Dictionary = pending_results[i]
		var skill: SkillDefinition = result["skill"]
		var item: ItemInstance = result["item"]
		var face: int = result["face"]
		var max_face: int = GameEnums.DICE_PROGRESSION[item.dice_level]
		var effect_value := CombatManager.calculate_effect_value(skill, item.definition, face)

		# Ustawiamy dane
		tag.setup(skill, face, max_face, effect_value)

		# Ustawiamy pozycję na docelowym miejscu w rzędzie
		var tag_height = tag.size.y if tag.size.y > 0 else 50.0
		tag.position = Vector2(current_x, target_y - (tag_height * 0.5))

		# Odpalamy animację pojawiania się (pop_in) i zapisujemy referencję do tweena
		last_tween = await tag.pop_in(0.0)

		# Dźwięk popnięcia o losowym, rosnącym tonie
		var pitch = 0.85 + (i * 0.08)
		AudioManager.play_sfx_random_pitch(AudioLibrary.get_sfx(AudioKeys.SFX_POP), -6.0, pitch, pitch)

		# Przesuwamy wskaźnik X dla następnego elementu
		current_x += tag_widths[i] + spacing

		# Czekamy chwilę przed pokazaniem kolejnego tagu (nie czekamy przy ostatnim)
		if i < count - 1:
			await get_tree().create_timer(dice_tag_cration_wait_time).timeout

	# 3. BEZPIECZNE CZEKANIE: Czekamy tylko na ostatni tween (bo on kończy się jako ostatni)
	if last_tween != null and last_tween.is_valid():
		await last_tween.finished

	is_rolling = false


func _animate_selection_and_centering() -> void:
	var unselected_tags: Array[Control] = []

	for tag in active_tags:
		if is_instance_valid(tag) and not tag in selected_tags:
			unselected_tags.append(tag)

	var main_tween = create_tween().set_parallel(true)

	for tag in unselected_tags:
		tag.offset_transform_enabled = true
		tag.pivot_offset = tag.size / 2.0
		main_tween.tween_property(tag, "offset_transform_scale", Vector2.ZERO, 0.45)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_IN)
		main_tween.tween_property(tag, "modulate:a", 0.0, 0.45)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)

	AudioManager.play_sfx(AudioLibrary.get_sfx(AudioKeys.SFX_SWOOSH))

	var selected_count = selected_tags.size()
	if selected_count > 0:
		var viewport_size = camera.get_viewport().get_visible_rect().size
		var spacing = 20.0
		var total_width = 0.0
		var tag_widths: Array[float] = []

		for tag in selected_tags:
			if is_instance_valid(tag):
				var w = tag.size.x if tag.size.x > 0 else 120.0
				tag_widths.append(w)
				total_width += w
			else:
				tag_widths.append(0.0)

		total_width += spacing * (selected_count - 1)

		var start_x = (viewport_size.x - total_width) * 0.5
		var target_y = viewport_size.y * 0.5
		var current_x = start_x

		for i in range(selected_count):
			var tag = selected_tags[i]
			if not is_instance_valid(tag): continue

			var tag_height = tag.size.y if tag.size.y > 0 else 50.0
			var target_pos = Vector2(current_x, target_y - (tag_height * 0.5))

			main_tween.tween_property(tag, "position", target_pos, 0.6)\
				.set_trans(Tween.TRANS_CUBIC)\
				.set_ease(Tween.EASE_OUT)\
				.set_delay(0.15)
			
			tag._animate_selected(0.0)
			
			current_x += tag_widths[i] + spacing

	await main_tween.finished

	for tag in unselected_tags:
		if is_instance_valid(tag):
			tag.hide()


func _on_combat_effect_applied(skill: SkillDefinition, value: int, target: String) -> void:
	var tag: Control = null
	if not resolving_tags.is_empty():
		tag = resolving_tags.pop_front()

	if is_instance_valid(tag) and tag.has_method("play_strike_animation"):
		await tag.play_strike_animation()

	if target == "enemy":
		FloatingTextManager.spawn_damage(value, enemy_spawn_point.global_transform.origin)
		AudioManager.play_sfx(AudioLibrary.get_ui(AudioKeys.UI_BUP))
		result_label.text = "%s: -%d wrogowi" % [skill.skill_name, value]
	else:
		FloatingTextManager.spawn_heal(value, hp_progress_bar.global_position)
		AudioManager.play_sfx(AudioLibrary.get_ui(AudioKeys.UI_BUP))
		result_label.text = "%s: +%d graczowi" % [skill.skill_name, value]
