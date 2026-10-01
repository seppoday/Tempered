class_name DiceHand
extends Node

signal results_ready

@export var dice_tag_scene: PackedScene
@export var camera: Camera3D
@export var dice_tag_canvas_layer: CanvasLayer
@export var dice_roller: DiceRoller
@export var enemy_spawn_point: Node3D
@export var hp_progress_bar: ProgressBar
@export var result_label: Label
@export var dice_tag_cration_wait_time: float = 0.12 # Odrobinkę większe dla lepszego efektu domino

const SPACING_X = 20.0

var active_tags: Array[PanelContainer] = []
var selected_tags: Array[PanelContainer] = []
var resolving_tags: Array[PanelContainer] = []
var pending_results: Array[Dictionary] = []

# ✅ NOWE: indeks do śledzenia który hit aktualnie się animuje
var current_hit_index: int = 0

var is_rolling: bool = false


func _ready() -> void:
	dice_roller.dice_spawned.connect(_on_dice_spawned)
	dice_roller.dice_settled.connect(_on_dice_settled)
	CombatManager.effect_applied.connect(_on_combat_effect_applied)


func start_rolling() -> void:
	is_rolling = true


func has_selection() -> bool:
	return not selected_tags.is_empty()


func confirm_selection() -> Array[Dictionary]:
	# Sortujemy wybrane tagi od lewej do prawej
	selected_tags.sort_custom(func(a, b): return a.position.x < b.position.x)

	# Filtrujemy tylko instancje, które wciąż istnieją
	resolving_tags = selected_tags.filter(func(tag): return is_instance_valid(tag))

	# ✅ NOWE: Reset indeksu hitu
	current_hit_index = 0

	var selected_results: Array[Dictionary] = []
	for tag in resolving_tags:
		var index := active_tags.find(tag)
		if index != -1:
			selected_results.append(pending_results[index])

	await _animate_selection_and_centering()
	return selected_results


func reset_for_new_roll() -> void:
	# ✅ NOWE: Reset indeksu
	current_hit_index = 0
	
	for tag in active_tags:
		if is_instance_valid(tag):
			tag.hide()
			tag.offset_transform_scale = Vector2.ONE
			tag.modulate.a = 1.0
			tag.set_selected(false)
			tag.set_locked(false)
	selected_tags.clear()
	resolving_tags.clear()


# --- OBSŁUGA SYGNAŁÓW I EVENTÓW ---

func _on_dice_spawned(dice: Array[RigidBody3D]) -> void:
	_clear_previous_tags()

	for i in dice.size():
		var tag := dice_tag_scene.instantiate() as Control
		tag.toggled.connect(_on_card_toggled)
		dice_tag_canvas_layer.add_child(tag)
		active_tags.append(tag)
		tag.hide()


func _on_dice_settled(results: Array[Dictionary]) -> void:
	pending_results = results
	await _reveal_results_domino()

	if not CombatManager.is_game_over:
		results_ready.emit()


func _on_card_toggled(card: PanelContainer, wants_selected: bool) -> void:
	if wants_selected:
		if selected_tags.size() >= PlayerData.picks_per_cycle:
			card.set_selected(false)
			return
		selected_tags.append(card)
	else:
		selected_tags.erase(card)

	card.set_selected(wants_selected)
	AudioManager.play_sfx(AudioLibrary.get_ui(AudioKeys.UI_CLICK), -5.0)
	_update_lock_states()


func _on_combat_effect_applied(skill: SkillDefinition, value: int, target: String) -> void:
	# Odczyt MUSI być przed pierwszym await
	var idx := CombatManager.current_result_index
	if idx < 0 or idx >= resolving_tags.size():
		Log.warning("DiceHand: zły indeks tagu (%d / %d)" % [idx, resolving_tags.size()])
		return

	var tag = resolving_tags[idx]

	if is_instance_valid(tag):
		if tag.has_method("play_strike_animation"):
			await tag.play_strike_animation()
		else:
			push_warning("DiceTag nie ma play_strike_animation()")

	AudioManager.play_sfx(AudioLibrary.get_ui(AudioKeys.UI_BUP))

	# ✅ NOWE: Floating text PO animacji
	if target == "enemy":
		FloatingTextManager.spawn_damage(value, enemy_spawn_point.global_transform.origin)
		result_label.text = "%s: -%d wrogowi" % [skill.skill_name, value]
	elif target == "player":
		if skill.effect_type == GameEnums.SkillEffect.HEAL:
			FloatingTextManager.spawn_heal(value, hp_progress_bar.global_position)
			result_label.text = "%s: +%d graczowi" % [skill.skill_name, value]
		elif skill.effect_type == GameEnums.SkillEffect.SHIELD:
			FloatingTextManager.spawn_shield_block(value, hp_progress_bar.global_position)
			result_label.text = "%s: +%d tarczy graczowi" % [skill.skill_name, value]
		else:
			result_label.text = "%s: +%d graczowi" % [skill.skill_name, value]


# --- SYSTEM ANIMACJI I WYŚRODKOWYWANIA (LAYOUT) ---

func _reveal_results_domino() -> void:
	if active_tags.is_empty(): return

	# Najpierw ustawiamy teksty, żeby tagi dostały finalny rozmiar
	for i in active_tags.size():
		var tag = active_tags[i]
		if is_instance_valid(tag):
			_setup_tag_from_result(tag, pending_results[i])

	# Jedna klatka na przeliczenie layoutu (poprawny size => pivot i wyśrodkowanie)
	await get_tree().process_frame

	var target_positions = _calculate_centered_positions(active_tags, SPACING_X)
	var last_tween: Tween = null

	for i in active_tags.size():
		var tag = active_tags[i]
		if not is_instance_valid(tag): continue

		tag.position = target_positions[i]
		last_tween = UIAnim.pop_in(tag)
		_play_pop_sound_pitch(i)

		if i < active_tags.size() - 1:
			await get_tree().create_timer(dice_tag_cration_wait_time).timeout

	if last_tween and last_tween.is_valid():
		await last_tween.finished

	is_rolling = false


func _animate_selection_and_centering() -> void:
	var unselected_tags = active_tags.filter(
		func(tag): return is_instance_valid(tag) and not tag in selected_tags
	)

	AudioManager.play_sfx(AudioLibrary.get_sfx(AudioKeys.SFX_SWOOSH))

	var last_fade: Tween = null
	for tag in unselected_tags:
		last_fade = UIAnim.fade_out_shrink(tag)

	var main_tween: Tween = null
	if not selected_tags.is_empty():
		main_tween = create_tween().set_parallel(true)
		var target_positions = _calculate_centered_positions(selected_tags, SPACING_X)

		for i in selected_tags.size():
			var tag = selected_tags[i]
			if not is_instance_valid(tag): continue

			main_tween.tween_property(tag, "position", target_positions[i], 0.6)\
				.set_trans(Tween.TRANS_CUBIC)\
				.set_ease(Tween.EASE_OUT)\
				.set_delay(0.15)

			tag._animate_selected(0.0)

	# Ruch (0.15 + 0.6 s) trwa dłużej niż fade (0.45 s), więc czekamy na niego,
	# a gdy nic nie wybrano, na ostatni fade.
	if main_tween and main_tween.is_valid():
		await main_tween.finished
	elif last_fade and last_fade.is_valid():
		await last_fade.finished

	for tag in unselected_tags:
		if is_instance_valid(tag):
			tag.hide()


# --- METODY POMOCNICZE (HELPERS) ---

func _calculate_centered_positions(tags: Array, spacing: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var viewport_size = camera.get_viewport().get_visible_rect().size
	
	# 1. Oblicz całkowitą szerokość
	var total_width = 0.0
	var tag_widths: Array[float] = []

	for tag in tags:
		if is_instance_valid(tag):
			var w = tag.size.x if tag.size.x > 0 else 120.0
			tag_widths.append(w)
			total_width += w
		else:
			tag_widths.append(0.0)

	total_width += spacing * (tags.size() - 1)

	# 2. Wyznacz pozycję startową X i docelową Y
	var current_x = (viewport_size.x - total_width) * 0.5
	var target_y = viewport_size.y * 0.5

	# 3. Zwróć wektory pozycji
	for i in tags.size():
		if is_instance_valid(tags[i]):
			var tag_height = tags[i].size.y if tags[i].size.y > 0 else 50.0
			positions.append(Vector2(current_x, target_y - (tag_height * 0.5)))
			current_x += tag_widths[i] + spacing
		else:
			positions.append(Vector2.ZERO)

	return positions


func _setup_tag_from_result(tag: Control, result: Dictionary) -> void:
	var skill: SkillDefinition = result["skill"]
	var item: ItemInstance = result["item"]
	var face: int = result["face"]
	var max_face: int = GameEnums.DICE_PROGRESSION[item.dice_level]

	var context := CombatManager.build_trigger_context(face, max_face)
	var base := CombatManager.get_effective_base(skill, context)
	var effect_value := CombatManager.calculate_effect_value(skill, item.definition, face, base)

	tag.setup(skill, face, max_face, effect_value, item.definition)


func _animate_fade_out(tween: Tween, tag: Control) -> void:
	tag.offset_transform_enabled = true
	tag.pivot_offset = tag.size / 2.0
	
	tween.tween_property(tag, "offset_transform_scale", Vector2.ZERO, 0.45)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
		
	tween.tween_property(tag, "modulate:a", 0.0, 0.45)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)


func _update_lock_states() -> void:
	var limit_reached := selected_tags.size() >= PlayerData.picks_per_cycle
	for tag in active_tags:
		if is_instance_valid(tag):
			var should_lock = limit_reached and not tag in selected_tags
			tag.set_locked(should_lock)


func _clear_previous_tags() -> void:
	for tag in active_tags:
		Utilities.safe_free(tag)
	active_tags.clear()
	selected_tags.clear()
	resolving_tags.clear()
	# ✅ NOWE: Reset indeksu przy czyszczeniu
	current_hit_index = 0


func _play_pop_sound_pitch(index: int) -> void:
	var pitch = 0.85 + (index * 0.08)
	AudioManager.play_sfx_random_pitch(AudioLibrary.get_sfx(AudioKeys.SFX_POP), -6.0, pitch, pitch)
