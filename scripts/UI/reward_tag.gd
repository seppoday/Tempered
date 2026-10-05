extends PanelContainer

signal reward_selected(card)

@onready var effect_overlay: ColorRect = %EffectOverlay
@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %ItemName


var is_selected := false
var is_hovering := false
var _locked := false
var _hover_tween: Tween
var _select_tween: Tween
var _locked_tween: Tween
var _item: InventoryEntry


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(item: InventoryEntry) -> void:
	if not item:
		return

	_locked = false
	is_selected = false
	_item = item

	if icon_rect:
		icon_rect.texture = item.icon
	if name_label:
		name_label.text = item.name

	tooltip_text = "use_custom"   # bez tego Godot nie wywoła _make_custom_tooltip wcale


func _make_custom_tooltip(_for_text: String) -> Control:
	if not _item:
		return null

	var instance := ItemInstance.new(_item, 1, 0)  # quantity=1, dice_level=0 — podgląd bazowego d4
	var tooltip := preload("uid://d3l2j2u2xebjv").instantiate() as InventoryTooltip
	tooltip.populate(instance, InventorySlot.STAT_DISPLAY)

	tooltip.tree_entered.connect(
		_clear_tooltip_panel_bg.bind(tooltip),
		CONNECT_ONE_SHOT
	)

	return tooltip


func _clear_tooltip_panel_bg(tooltip_content: Control) -> void:
	var parent := tooltip_content.get_parent()
	if parent == null:
		return
	parent.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func reset_state() -> void:
	_locked = false
	is_selected = false
	is_hovering = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func lock() -> void:
	_locked = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if _locked:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_locked = true
		is_selected = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_selected.emit(self)
		accept_event()


func _on_mouse_entered() -> void:
	if _locked:
		return

	is_hovering = true
	UIAnim.scale_to(self, Vector2(1.1, 1.1))
	_animate_hover(1.0)


func _on_mouse_exited() -> void:
	if _locked:
		return

	is_hovering = false
	UIAnim.scale_to(self, Vector2(1, 1))
	_animate_hover(0.0)


func _animate_hover(target: float) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	var mat := _get_shader_material()
	if not mat:
		return

	_hover_tween = create_tween()
	_hover_tween.tween_method(
		func(v: float): mat.set_shader_parameter("hover_intensity", v),
		mat.get_shader_parameter("hover_intensity"),
		target,
		0.15
	).set_trans(Tween.TRANS_SINE)


func _get_shader_material() -> ShaderMaterial:
	var overlay := effect_overlay if effect_overlay else get_node_or_null("EffectOverlay")
	print(overlay)
	if overlay and overlay.material is ShaderMaterial:
		return overlay.material as ShaderMaterial
	return null
