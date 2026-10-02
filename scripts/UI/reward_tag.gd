extends PanelContainer

@onready var effect_overlay: ColorRect = %EffectOverlay

var is_selected: bool = false
var is_hovering: bool = false

var _hover_tween: Tween
var _select_tween: Tween
var _locked_tween: Tween

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameManager.set_state(GameManager.State.WEAPON_SELECT, self) 
		# Raczej lepiej tutaj coś emitowac i przeniesc logike
		# zmiany do głównego skryptu, który dodatkowo obsłuży co wybraliśmy i uzupełni inventory itp.

func _on_mouse_entered() -> void:
	is_hovering = true
	UIAnim.scale_to(self, Vector2(1.2, 1.2))
	_animate_hover(1.0)


func _on_mouse_exited() -> void:
	is_hovering = false
	UIAnim.scale_to(self, Vector2(1, 1))
	_animate_hover(0.0)


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


func _get_shader_material() -> ShaderMaterial:
	var overlay = effect_overlay if effect_overlay else get_node_or_null("EffectOverlay")
	if overlay and overlay.material is ShaderMaterial:
		return overlay.material as ShaderMaterial
	return null
