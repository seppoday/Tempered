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
@onready var scaling_label: Label = %ScalingLabel
@onready var effect_overlay: ColorRect = %EffectOverlay

@onready var effects_box: VBoxContainer = %EffectsBox

const EFFECT_DIM_ALPHA := 0.4
const EFFECT_COLOR_DRAWBACK := Color(1.0, 0.5, 0.45)

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


func setup(skill: SkillDefinition, face: int, max_face: int, effect_value: float, item: ItemDefinition = null, dice_level: int = 0) -> void:
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

	_build_effect_lines(skill, face, max_face, item, dice_level)


## Jedna linia na trigger: "warunek → efekt". Nietrafione warunki są przyciemnione.
func _build_effect_lines(skill: SkillDefinition, face: int, max_face: int, item: ItemDefinition, dice_level: int) -> void:
	for child in effects_box.get_children():
		child.queue_free()

	var context := CombatManager.build_trigger_context(face, max_face)
	for trigger in skill.triggers:
		if trigger == null:
			continue
		var text := _get_trigger_hint(trigger, item, face, dice_level)
		if text == "":
			continue

		var line: Label = scaling_label.duplicate()   # styl bierzemy z ukrytego ScalingLabel
		line.visible = true
		line.text = text
		if _is_drawback(trigger):
			line.add_theme_color_override("font_color", EFFECT_COLOR_DRAWBACK)
		if not CombatManager._trigger_condition_met(trigger, context, false):
			line.modulate.a = EFFECT_DIM_ALPHA
		effects_box.add_child(line)


func _is_drawback(trigger: SkillTriggerBase) -> bool:
	if trigger.hp_cost > 0.0 or trigger is ReduceNextPicksTrigger:
		return true
	return trigger is ChanceTrigger and trigger.inner_trigger is ReduceNextPicksTrigger


## "warunek → efekt + status + koszt"; bez warunku (ON_HIT) samo "→ efekt".
func _get_trigger_hint(trigger: SkillTriggerBase, item: ItemDefinition, face: int, dice_level: int) -> String:
	var parts: Array[String] = []

	var effect_desc := trigger.get_effect_description()
	if effect_desc != "":
		parts.append(effect_desc)
	if trigger.apply_status != GameEnums.StatusType.NONE:
		parts.append(_get_status_text(trigger, item, face, dice_level))
	if trigger.hp_cost > 0.0:
		parts.append("-%d HP" % int(round(trigger.hp_cost)))
	if parts.is_empty():
		return ""

	var effect_str := " + ".join(parts)
	var condition := _get_condition_text(trigger)
	return "→ %s" % effect_str if condition == "" else "%s → %s" % [condition, effect_str]


func _get_status_text(trigger: SkillTriggerBase, item: ItemDefinition, face: int, dice_level: int) -> String:
	var status_name: String = GameEnums.StatusType.keys()[trigger.apply_status].capitalize()
	var text := "%s ×%d" % [status_name, trigger.status_stacks]
	if item != null:
		# Stack = runda: obrażenia to tick × s + tick × (s-1) + ... + tick × 1.
		var status: StatusEffect = CombatManager._create_status_from_trigger(trigger, item, face, dice_level)
		var total := int(round(status.tick_damage * status.stacks * (status.stacks + 1) / 2.0))
		if total > 0:
			text += " (%d dmg)" % total
	return text


func _get_condition_text(trigger: SkillTriggerBase) -> String:
	match trigger.trigger_type:
		GameEnums.TriggerType.ON_ROLL_AT_LEAST:
			return "Roll≥%d" % trigger.threshold
		GameEnums.TriggerType.ON_ROLL_AT_MOST:
			return "Roll≤%d" % trigger.threshold
		GameEnums.TriggerType.ON_MAX_ROLL:
			return "Max Roll"
		GameEnums.TriggerType.ON_LOW_ROLL:
			return "Low Roll"
		GameEnums.TriggerType.ON_KILL:
			return "On Kill"
		GameEnums.TriggerType.ON_TARGET_STATUS:
			var names: Array[String] = []
			for s in trigger.required_target_statuses:
				names.append(GameEnums.StatusType.keys()[s].capitalize())
			return "vs %s" % "/".join(names) if not names.is_empty() else "Target Status"
		GameEnums.TriggerType.ON_SELF_HP_BELOW:
			return "Below %d%% HP" % int(trigger.threshold * 100)
		GameEnums.TriggerType.ON_TARGET_HP_BELOW:
			return "Target <%d%% HP" % int(trigger.threshold * 100)
		GameEnums.TriggerType.ON_ROLL_PERCENT_AT_LEAST:
			return "Top %d%%" % int(round((1.0 - trigger.threshold) * 100.0))
		GameEnums.TriggerType.ON_ROLL_PERCENT_AT_MOST:
			return "Bottom %d%%" % int(round(trigger.threshold * 100.0))
	return ""


## Krótki "punch" karty przy trafieniu. Trwa ~0.19 s, czyli mniej niż delay_between_effects (0.35 s).
func play_strike_animation() -> void:
	if Engine.is_editor_hint():
		return

	offset_transform_enabled = true
	pivot_offset = size / 2.0

	# Wracamy do skali spoczynkowej (hover ustawia 1.1)
	var rest := Vector2.ONE * (1.1 if is_hovering else 1.0)

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


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if is_locked: return  # zablokowane karty nie reagują na kliknięcia
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit(self, not is_selected)


func _on_mouse_entered() -> void:
	if is_locked: return  # zablokowane karty nie reagują na hover
	is_hovering = true
	UIAnim.scale_to(self, Vector2(1.1, 1.1))
	_animate_hover(0.5)


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
