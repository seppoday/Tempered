extends Node3D

@export var dice_tag_scene: PackedScene
@export var roll_button: Button
@export var confirm_button: Button
@export var result_label: Label
@export var dice_roller: DiceRoller
@export var enemy_scene: PackedScene

@onready var camera = $Camera3D
@onready var canvas_layer = %MainSceneUICanvasLayer
@onready var equipment_canvas_layer: CanvasLayer = %EquipmentCanvasLayer
@onready var enemy_spawn_point: Node3D = %EnemySpawnPoint
@export var floating_text: PackedScene

@onready var lid: MeshInstance3D = %Lid
@onready var box: Node3D = %Box

@onready var hp_progress_bar: ProgressBar = %HpProgressBar

var active_tags: Array[Control] = []
var selected_tags: Array[PanelContainer] = []
var pending_results: Array[Dictionary] = []
var resolving_tags: Array[Control] = []
var is_rolling := false
var update_tags := false
var lid_opening_time := .5

var dice_tag_cration_wait_time: float = 0.08


func _ready() -> void:
	AudioManager.play_music(AudioLibrary.get_music(AudioKeys.MUSIC_TEST), -10.0)
	roll_button.pressed.connect(_on_roll_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	dice_roller.dice_spawned.connect(_on_dice_spawned)
	dice_roller.dice_settled.connect(_on_dice_settled)
	result_label.text = "Naciśnij RZUĆ"
	confirm_button.disabled = true
	CombatManager.effect_applied.connect(_on_combat_effect_applied)
	CombatManager.player_died.connect(_on_player_died)
	EventBus.player_damaged.connect(_on_player_damaged)
	
	dice_roller.spawn_dice()
	shake_box()
	

func shake_box(duration: float = 1.5, max_intensity: float = 0.15, lift_height: float = 1.0, fov_zoom: float = 4.0) -> void:
	var original_pos: Vector3 = box.position
	var original_rot: Vector3 = box.rotation
	
	# Pobieramy kamerę (zakładamy, że %Camera3D istnieje w scenie)
	var camera: Camera3D = %Camera3D
	var original_fov: float = camera.fov
	
	# Tworzymy równoległy tween
	var shake_tween := create_tween().set_parallel(true)
	
	# Podział czasu na fazy
	var lift_duration: float = duration * 0.5   # 20% czasu na uniesienie
	var fall_duration: float = duration * 0.05   # 15% czasu na gwałtowny spadek
	var shake_duration: float = duration - lift_duration - fall_duration # reszta na trzęsienie
	var fall_start_time: float = lift_duration + shake_duration
	
	# --- FAZA 1: UNIESIENIE (Start) ---
	shake_tween.tween_property(box, "position:y", original_pos.y + lift_height, lift_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shake_tween.tween_property(box, "rotation", original_rot + Vector3(0.05, 0.02, -0.05), lift_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# [KAMERA] Powolne przybliżanie (zmniejszanie FOV) przez cały czas uniesienia i trzęsienia
	var total_zoom_duration: float = lift_duration + shake_duration
	shake_tween.tween_property(camera, "fov", original_fov - fov_zoom, total_zoom_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# --- FAZA 2: TRZĘSIENIE (W powietrzu) ---
	var shake_count: int = 12
	var step_duration: float = shake_duration / shake_count
	
	for i in range(shake_count):
		var progress: float = float(i) / float(shake_count)
		var current_intensity: float = lerp(0.3, 1.0, progress) * max_intensity
		
		var random_offset := Vector3(
			randf_range(-current_intensity, current_intensity),
			0,
			randf_range(-current_intensity, current_intensity)
		)
		var random_rot := Vector3(
			randf_range(-current_intensity * 2.0, current_intensity * 2.0),
			randf_range(-current_intensity * 1.5, current_intensity * 1.5),
			randf_range(-current_intensity * 2.0, current_intensity * 2.0)
		)
		
		var t: float = lift_duration + (i * step_duration)
		var target_pos := Vector3(original_pos.x + random_offset.x, original_pos.y + lift_height, original_pos.z + random_offset.z)
		
		shake_tween.tween_property(box, "position", target_pos, step_duration)\
			.set_delay(t).set_trans(Tween.TRANS_SINE)
		shake_tween.tween_property(box, "rotation", original_rot + random_rot, step_duration)\
			.set_delay(t).set_trans(Tween.TRANS_SINE)
			
	# --- FAZA 3: OPUSZCZENIE / UPADEK (Koniec) ---
	# Gwałtowny powrót boxa na stół
	shake_tween.tween_property(box, "position", original_pos, fall_duration)\
		.set_delay(fall_start_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	shake_tween.tween_property(box, "rotation", original_rot, fall_duration)\
		.set_delay(fall_start_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
	# [KAMERA] Błyskawiczny powrót FOV do normy w momencie uderzenia (daje "kopnięcie" kamery)
	shake_tween.tween_property(camera, "fov", original_fov, fall_duration)\
		.set_delay(fall_start_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# --- EFEKT UDERZENIA (Micro-bounce) ---
	var bounce_time: float = 0.05
	var bounce_height: float = lift_height * 0.25
	
	# Lekki odskok boxa w górę
	shake_tween.tween_property(box, "position:y", original_pos.y + bounce_height, bounce_time)\
		.set_delay(fall_start_time + fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Ostateczny powrót boxa na stół
	shake_tween.tween_property(box, "position:y", original_pos.y, bounce_time)\
		.set_delay(fall_start_time + fall_duration + bounce_time).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Czekamy na zakończenie wszystkich animacji (w tym ostatniego bounce)
	await shake_tween.finished
	open_lid()

func open_lid() -> void:
	var tween = get_tree().create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(lid, "global_rotation_degrees", Vector3(0.0, 0.0, 145.0), lid_opening_time)


func _on_player_died() -> void:
	roll_button.disabled = true
	confirm_button.disabled = true
	result_label.text = "PRZEGRANA"
	equipment_canvas_layer.show()

func _on_player_damaged(final_amount) -> void:
	var pos = hp_progress_bar.global_position + Vector2(0, -20)
	FloatingTextManager.spawn_screen("%d" % final_amount, pos, FloatingTextManager.COLOR_DAMAGE)

func _on_combat_effect_applied(skill: SkillDefinition, value: int, target: String) -> void:
	# Pobieramy pierwszą kartę z kolejki do animacji uderzenia (gwarantowane lewo-prawo)
	var tag: Control = null
	if not resolving_tags.is_empty():
		tag = resolving_tags.pop_front()

	# Jeśli karta istnieje, czekamy na szczyt jej uderzenia
	if is_instance_valid(tag):
		await _play_strike_animation(tag)

	# --- MOMENT UDERZENIA (Impact Frame) ---
	if target == "enemy":
		FloatingTextManager.spawn_world("-%d" % value, %EnemySpawnPoint.global_transform.origin, Color.RED)
		AudioManager.play_sfx(AudioLibrary.get_ui(AudioKeys.UI_BUP))
		result_label.text = "%s: -%d wrogowi" % [skill.skill_name, value]
	else:
		FloatingTextManager.spawn_screen("-%d" % value, %HpProgressBar.global_position, Color.GREEN)
		AudioManager.play_sfx(AudioLibrary.get_ui(AudioKeys.UI_BUP))
		result_label.text = "%s: +%d graczowi" % [skill.skill_name, value]


func _process(delta: float) -> void:
	if update_tags:
		_update_all_tag_positions(delta)


func _update_all_tag_positions(delta: float) -> void:
	var count = min(dice_roller.dice_group.size(), active_tags.size())
	if count == 0: return

	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 2.0
	var tag_rects: Array[Rect2] = []

	for i in range(count):
		var die = dice_roller.dice_group[i]
		var tag = active_tags[i]

		if not is_instance_valid(die) or not is_instance_valid(tag):
			tag_rects.append(Rect2())
			continue

		var world_pos = die.global_position + Vector3(0, 0.2, 0)
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
			tag.position = tag.position.lerp(target_pos, delta * 1.8)


func _on_roll_button_pressed() -> void:
	UIAnim.pop(roll_button)
	if is_rolling or CombatManager.is_game_over: return
	is_rolling = true
	update_tags = false
	roll_button.disabled = true
	confirm_button.disabled = true
	result_label.text = "Toczenie kości..."
	dice_roller.roll()


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
	update_tags = true
	await _reveal_results()

	if not CombatManager.is_game_over:
		confirm_button.disabled = false


func _on_confirm_button_pressed() -> void:
	if selected_tags.is_empty() or CombatManager.is_game_over:
		return

	confirm_button.disabled = true

	# 1. KLUCZOWE: Sortujemy wybrane tagi od lewej do prawej według ich pozycji na ekranie.
	# Zapobiega to mieszaniu kolejności podczas centrowania.
	selected_tags.sort_custom(func(a, b): return a.position.x < b.position.x)

	# 2. Tworzymy listę kolejki animacji ataku (teraz gwarantuje kolejność od lewej do prawej)
	resolving_tags.clear()
	for tag in selected_tags:
		if is_instance_valid(tag):
			resolving_tags.append(tag)

	# 3. Na podstawie tej samej (posortowanej) kolejności budujemy wyniki dla CombatManagera
	var selected_results: Array[Dictionary] = []
	for tag in resolving_tags:
		var index := active_tags.find(tag)
		if index != -1:
			selected_results.append(pending_results[index])

	# 4. Chowamy niechciane karty i centrujemy wybrane (teraz ułożą się ładnie od lewej do prawej)
	await _animate_selection_and_centering()

	# 5. Wywołujemy atak - sygnały effect_applied będą synchronizować animacje
	await CombatManager.resolve_player_attack(selected_results)

	if CombatManager.is_game_over:
		_reset_tags_for_new_roll()
		return

	if CombatManager.current_enemy != null:
		CombatManager.enemy_take_turn()

	_reset_tags_for_new_roll()

	if not CombatManager.is_game_over:
		roll_button.disabled = false
		result_label.text = "Naciśnij RZUĆ"


func _reset_tags_for_new_roll() -> void:
	for tag in active_tags:
		if is_instance_valid(tag):
			tag.hide()
			tag.offset_transform_scale = Vector2.ONE
			tag.modulate.a = 1.0
			tag.set_selected(false)
	selected_tags.clear()
	resolving_tags.clear()


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


func _clear_previous_tags() -> void:
	for tag in active_tags:
		Utilities.safe_free(tag)
	active_tags.clear()
	selected_tags.clear()
	resolving_tags.clear()


func _reveal_results() -> void:
	var pop_tweens: Array[Tween] = []

	for i in range(dice_roller.dice_group.size()):
		var tag := active_tags[i]
		var result: Dictionary = pending_results[i]

		var skill: SkillDefinition = result["skill"]
		var item: ItemInstance = result["item"]
		var face: int = result["face"]
		var max_face: int = GameEnums.DICE_PROGRESSION[item.dice_level]
		var effect_value := CombatManager.calculate_effect_value(skill, item.definition, face)

		tag.setup(skill, face, max_face, effect_value)
		_update_all_tag_positions(0.016)

		var tween: Tween = await tag.pop_in(0.0)
		pop_tweens.append(tween)

		AudioManager.play_sfx_random_pitch(AudioLibrary.get_sfx(AudioKeys.SFX_POP), -6.0, 0.75, 1.25)
		await get_tree().create_timer(dice_tag_cration_wait_time).timeout

	for tween in pop_tweens:
		if tween != null and tween.is_valid():
			await tween.finished

	update_tags = false
	await _align_tags_to_center_line()

	if not CombatManager.is_game_over:
		result_label.text = "Wybierz karty"
	is_rolling = false


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

		align_tween.tween_property(tag, "position", target_pos, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		current_x += tag_widths[i] + spacing

	await align_tween.finished


func _animate_selection_and_centering() -> void:
	var unselected_tags: Array[Control] = []
	
	for tag in active_tags:
		if is_instance_valid(tag) and not tag in selected_tags:
			unselected_tags.append(tag)

	var main_tween = create_tween().set_parallel(true)

	# 1. Animujemy znikanie niewybranych tagów
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

	# 2. Równolegle wyrównujemy pozostałe wybrane tagi na środku (teraz są już posortowane!)
	var selected_count = selected_tags.size()
	if selected_count > 0:
		var viewport_size = get_viewport().get_visible_rect().size
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

			current_x += tag_widths[i] + spacing

	await main_tween.finished

	for tag in unselected_tags:
		if is_instance_valid(tag):
			tag.hide()


func _play_strike_animation(tag: Control) -> void:
	var orig_pos = tag.position
	
	AudioManager.play_sfx_random_pitch(AudioLibrary.get_sfx(AudioKeys.SFX_POP), -4.0, 1.1, 1.3)
	
	var strike_up = create_tween()
	strike_up.tween_property(tag, "position", orig_pos + Vector2(0, -65), 0.08)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
		
	await strike_up.finished
	
	var fall_down = create_tween()
	fall_down.tween_property(tag, "position", orig_pos, 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
