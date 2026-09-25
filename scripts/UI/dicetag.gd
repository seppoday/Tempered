extends PanelContainer

signal toggled(card: PanelContainer, is_selected: bool)

@onready var icon: TextureRect = %Icon
@onready var skill_name_label: Label = %SkillNameLabel
@onready var value_label: Label = %ValueLabel
@onready var roll_detail_label: Label = %RollDetailLabel


var is_selected: bool = false
var is_hovering: bool = false

const STYLE_NORMAL = preload("res://assets/styles/roll_panel_normal.tres")
const STYLE_HOVER = preload("res://assets/styles/roll_panel_hover.tres")
const STYLE_SELECTED = preload("res://assets/styles/roll_panel_selected.tres")

const ELEMENT_COLORS := {
	GameEnums.DamageElement.PHYSICAL: Color(0.8, 0.8, 0.8),
	GameEnums.DamageElement.FIRE: Color(1.0, 0.45, 0.15),
	GameEnums.DamageElement.ICE: Color(0.4, 0.8, 1.0),
	GameEnums.DamageElement.POISON: Color(0.5, 0.9, 0.3),
	GameEnums.DamageElement.NONE: Color(0.8, 0.8, 0.8),
}


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_style()


## Wypełnia kartę pełnym kontekstem wyniku: skill, surowy rzut i wyliczony efekt.
func setup(skill: SkillDefinition, face: int, max_face: int, effect_value: float) -> void:
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
		
			
	value_label.text = ("+%d" if is_additive_to_player else "%d") % int(round(effect_value))

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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit(self, not is_selected)


func _on_mouse_entered() -> void:
	is_hovering = true
	UIAnim.scale_to(self, Vector2(1.2, 1.2))
	_update_style()


func _on_mouse_exited() -> void:
	is_hovering = false
	UIAnim.scale_to(self, Vector2(1, 1))
	_update_style()


func set_selected(value: bool) -> void:
	is_selected = value
	_update_style()


func _update_style() -> void:
	if is_selected:
		_apply_style(STYLE_SELECTED)
	elif is_hovering:
		_apply_style(STYLE_HOVER)
	else:
		#pass
		_apply_style(STYLE_NORMAL)


func _apply_style(style: StyleBox) -> void:
	add_theme_stylebox_override("panel", style)
