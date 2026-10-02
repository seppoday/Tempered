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
@onready var scaling_label: Label = %ScalingLabel  # <--- NOWY
@onready var effect_overlay: ColorRect = %EffectOverlay

var is_selected: bool = false
var is_hovering: bool = false
var is_locked: bool = false

const STYLE_NORMAL = preload("uid://dajifqb0i0l82")

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


func setup(skill: SkillDefinition, face: int, max_face: int, effect_value: float, item: ItemDefinition = null) -> void:
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

	# ── NOWE: krótki opis skalowania ──
	scaling_label.text = _build_scaling_text(skill, item)


## Buduje krótki opis skąd bierze się wartość skilla
func _build_scaling_text(skill: SkillDefinition, item: ItemDefinition) -> String:
	var parts: Array[String] = []

	# 1. Scaling po statach: "DMG×1.0 • STATUS×0.2"
	for scaling in skill.scalings:
		var stat_name: String = GameEnums.Stat.keys()[scaling.stat]
		parts.append("%s×%s" % [stat_name, _fmt(scaling.weight)])

	# 2. Affinity itemu (tylko jeśli != 1.0 i element pasuje)
	if item != null and skill.damage_element != GameEnums.DamageElement.NONE:
		var affinity: float = item.get_affinity_multiplier(skill.damage_element)
		if not is_equal_approx(affinity, 1.0):
			var elem_icon := _get_element_icon(skill.damage_element)
			parts.append("%s×%s" % [elem_icon, _fmt(affinity)])

	# 3. Multi-hit (bonus_hits_per_stat)
	if skill.bonus_hits_per_stat != null:
		var hit_stat: String = GameEnums.Stat.keys()[skill.bonus_hits_per_stat.stat]
		parts.append("+hity: %s" % hit_stat)

	# 4. Trigger (podpowiedź, że coś się odpali)
	for trigger in skill.triggers:
		var hint := _get_trigger_hint(trigger)
		if hint != "":
			parts.append(hint)

	return " • ".join(parts)


## Krótki emoji dla elementu
func _get_element_icon(element: GameEnums.DamageElement) -> String:
	match element:
		GameEnums.DamageElement.FIRE: return "🔥"
		GameEnums.DamageElement.ICE: return "❄"
		GameEnums.DamageElement.POISON: return "🧪"
		GameEnums.DamageElement.PHYSICAL: return "⚔"
		_: return ""

## Krótki "punch" karty przy trafieniu. Trwa ~0.19 s, czyli mniej niż delay_between_effects (0.35 s).
func play_strike_animation() -> void:
	if Engine.is_editor_hint():
		return

	offset_transform_enabled = true
	pivot_offset = size / 2.0

	# Wracamy do skali spoczynkowej (hover ustawia 1.2)
	var rest := Vector2.ONE * (1.2 if is_hovering else 1.0)

	var tween := create_tween()

	# Uderzenie: powiększenie + rozjaśnienie
	tween.tween_property(self, "offset_transform_scale", rest * 1.25, 0.07)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.07)

	# Powrót
	tween.tween_property(self, "offset_transform_scale", rest, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.12)

	await tween.finished

## Krótka podpowiedź dla triggera
func _get_trigger_hint(trigger: SkillTrigger) -> String:
	match trigger.trigger_type:
		GameEnums.TriggerType.ON_HIT:
			var status_name: String = GameEnums.StatusType.keys()[trigger.apply_status].capitalize()
			return "→ %s" % status_name
		GameEnums.TriggerType.ON_HIGH_ROLL:
			var status_name: String = GameEnums.StatusType.keys()[trigger.apply_status].capitalize()
			var pct: int = int(trigger.threshold * 100)
			return "High Roll (%d%%+) → %s×%d" % [pct, status_name, trigger.status_stacks]
		GameEnums.TriggerType.ON_MAX_ROLL:
			return "Max Roll → ×2"
		GameEnums.TriggerType.ON_LOW_HP:
			var pct: int = int(trigger.threshold * 100)
			return "HP<%d%% → mocniej" % pct
		GameEnums.TriggerType.EXECUTE:
			var pct: int = int(trigger.threshold * 100)
			return "Execute <%d%% HP" % pct
	return ""


## Formatuje liczbę: 1.0 → "1", 0.25 → "0.25"
func _fmt(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(value)
	return "%.2f" % value


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if is_locked: return  # zablokowane karty nie reagują na kliknięcia
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit(self, not is_selected)


func _on_mouse_entered() -> void:
	if is_locked: return  # zablokowane karty nie reagują na hover
	is_hovering = true
	UIAnim.scale_to(self, Vector2(1.1, 1.1))
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
