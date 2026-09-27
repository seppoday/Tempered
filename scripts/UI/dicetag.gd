@tool
extends PanelContainer
class_name DiceTag

signal toggled(card: PanelContainer, is_selected: bool)

@export_group("Podgląd w Edytorze (Debug)")
@export var podglad_hover: bool = false:
	set(val):
		podglad_hover = val
		_update_editor_preview()

@export var podglad_selected: bool = false:
	set(val):
		podglad_selected = val
		_update_editor_preview()

@export var podglad_locked: bool = false:
	set(val):
		podglad_locked = val
		_update_editor_preview()

@onready var icon: TextureRect = %Icon
@onready var skill_name_label: Label = %SkillNameLabel
@onready var value_label: Label = %ValueLabel
@onready var roll_detail_label: Label = %RollDetailLabel
@onready var effect_overlay: ColorRect = %EffectOverlay

var is_selected: bool = false
var is_hovering: bool = false
var is_locked: bool = false

const STYLE_NORMAL = preload("res://assets/styles/roll_panel_normal.tres")

const ELEMENT_COLORS := {
	GameEnums.DamageElement.PHYSICAL: Color(0.8, 0.8, 0.8),
	GameEnums.DamageElement.FIRE: Color(1.0, 0.45, 0.15),
	GameEnums.DamageElement.ICE: Color(0.4, 0.8, 1.0),
	GameEnums.DamageElement.POISON: Color(0.5, 0.9, 0.3),
	GameEnums.DamageElement.NONE: Color(0.8, 0.8, 0.8),
}

var _hover_tween: Tween
var _select_tween: Tween
var _locked_tween: Tween


func _ready() -> void:
	# Podłączamy dynamiczną zmianę rozmiaru dla shadera SDF
	resized.connect(_on_resized)
	_on_resized()

	if Engine.is_editor_hint():
		_update_editor_preview()
		return

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	add_theme_stylebox_override("panel", STYLE_NORMAL)

	var mat = _get_shader_material()
	if mat:
		mat.set_shader_parameter("hover_intensity", 0.0)
		mat.set_shader_parameter("selected_intensity", 0.0)
		mat.set_shader_parameter("locked_intensity", 0.0)


func _get_shader_material() -> ShaderMaterial:
	var overlay = effect_overlay if effect_overlay else get_node_or_null("EffectOverlay")
	if overlay and overlay.material is ShaderMaterial:
		return overlay.material as ShaderMaterial
	return null


# Aktualizuje rozmiar w shaderze dla poprawnego zaokrąglenia rogów
func _on_resized() -> void:
	var mat = _get_shader_material()
	if mat:
		mat.set_shader_parameter("size", size)


func _update_editor_preview() -> void:
	_on_resized()
	var mat = _get_shader_material()
	if mat:
		mat.set_shader_parameter("hover_intensity", 1.0 if podglad_hover else 0.0)
		mat.set_shader_parameter("selected_intensity", 1.0 if podglad_selected else 0.0)
		mat.set_shader_parameter("locked_intensity", 1.0 if podglad_locked else 0.0)


func setup(skill: SkillDefinition, face: int, max_face: int, effect_value: float) -> void:
	if Engine.is_editor_hint(): return
	
	icon.texture = skill.icon
	skill_name_label.text = skill.skill_name
	roll_detail_label.text = "%d" % face

	var is_additive_to_player := skill.effect_type in [GameEnums.SkillEffect.HEAL, GameEnums.SkillEffect.SHIELD]

	match skill.effect_type:
		GameEnums.SkillEffect.HEAL:
			value_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		GameEnums.SkillEffect.SHIELD:
			value_label.add_theme_color_override("font_color", Color(0.454, 0.514, 0.451, 1.0))
		GameEnums.SkillEffect.DAMAGE:
			value_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	var formatted_value := Utilities.format_large_number(effect_value)
	value_label.text = ("+" if is_additive_to_player else "") + formatted_value

	var element_color: Color = ELEMENT_COLORS.get(skill.damage_element, Color.WHITE)
	roll_detail_label.add_theme_color_override("font_color", element_color)
	icon.self_modulate = element_color


func pop_in(delay: float = 0.0) -> Tween:
	await get_tree().process_frame
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	show()
	Utilities.center_pivot(self)
	scale = Vector2.ZERO
	modulate.a = 0.0

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	return tween


func play_strike_animation() -> void:
	var orig_pos = position
	AudioManager.play_sfx_random_pitch(AudioLibrary.get_sfx(AudioKeys.SFX_POP), -4.0, 1.1, 1.3)

	var strike_up = create_tween()
	strike_up.tween_property(self, "position", orig_pos + Vector2(0, -65), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await strike_up.finished

	var fall_down = create_tween()
	fall_down.tween_property(self, "position", orig_pos, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if is_locked: return  # zablokowane karty nie reagują na kliknięcia
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit(self, not is_selected)


func _on_mouse_entered() -> void:
	if is_locked: return  # zablokowane karty nie reagują na hover
	is_hovering = true
	UIAnim.scale_to(self, Vector2(1.2, 1.2))
	_animate_hover(1.0)


func _on_mouse_exited() -> void:
	if is_locked: return
	is_hovering = false
	UIAnim.scale_to(self, Vector2(1, 1))
	_animate_hover(0.0)


func set_selected(value: bool) -> void:
	if is_locked and value: return  # nie można zaznaczyć zablokowanej karty
	is_selected = value
	_animate_selected(1.0 if value else 0.0)


## Blokuje/odblokowuje kartę. Zablokowana karta jest wyszarzona i ignoruje interakcje.
func set_locked(value: bool) -> void:
	is_locked = value
	_animate_locked(1.0 if value else 0.0)
	%RollDetail.show()

	# Reset hover state, jeśli karta zostanie zablokowana w trakcie hovera
	if value and is_hovering:
		is_hovering = false
		UIAnim.scale_to(self, Vector2(1, 1))
		_animate_hover(0.0)

	if value and not is_selected:
		%RollDetail.hide()
		
	# Jeśli locked + selected, wymuszamy odznaczenie
	if value and is_selected:
		is_selected = false
		_animate_selected(0.0)
		%RollDetail.show()


func _animate_hover(target: float) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	var mat = _get_shader_material()
	if not mat: return

	_hover_tween = create_tween()
	_hover_tween.tween_method(func(v: float):
		mat.set_shader_parameter("hover_intensity", v)
	, mat.get_shader_parameter("hover_intensity"), target, 0.15)\
		.set_trans(Tween.TRANS_SINE)


func _animate_selected(target: float) -> void:
	if _select_tween and _select_tween.is_valid():
		_select_tween.kill()

	var mat = _get_shader_material()
	if not mat: return

	_select_tween = create_tween()
	_select_tween.tween_method(func(v: float):
		mat.set_shader_parameter("selected_intensity", v)
	, mat.get_shader_parameter("selected_intensity"), target, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _animate_locked(target: float) -> void:
	if _locked_tween and _locked_tween.is_valid():
		_locked_tween.kill()

	var mat = _get_shader_material()
	if not mat: return

	_locked_tween = create_tween()
	_locked_tween.tween_method(func(v: float):
		mat.set_shader_parameter("locked_intensity", v)
	, mat.get_shader_parameter("locked_intensity"), target, 0.25)\
		.set_trans(Tween.TRANS_SINE)
