# Skrypt: dice_tag.gd
extends PanelContainer

signal toggled(card: PanelContainer, is_selected: bool)

@onready var value_label = $ValueLabel
@onready var item_label: Label = $ItemLabel
@onready var icon = $Icon

var is_selected: bool = false
var is_hovering: bool = false  # Śledzimy, czy myszka jest nad kartą

const STYLE_NORMAL = preload("res://assets/styles/roll_panel_normal.tres")
const STYLE_HOVER = preload("res://assets/styles/roll_panel_hover.tres")
const STYLE_SELECTED = preload("res://assets/styles/roll_panel_selected.tres")

func _ready() -> void:
	# Automatycznie łączymy sygnały myszy, aby mieć pewność, że działają
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_style()

func set_value(dice_max_sides: int, item_name: String):
	value_label.text = str(dice_max_sides)
	item_label.text = item_name
	
func set_icon(texture: Texture2D):
	icon.texture = texture

# Animacja ładnego "pojawiania się" panelu
func pop_in(delay: float = 0.0):
	# Dajemy chwilę na przeliczenie rozmiarów UI przez engine
	await get_tree().process_frame
	
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		
	show()
	
	# Ustawiamy punkt obrotu na środek panelu (żeby powiększał się ze środka)
	pivot_offset = size / 2.0
	scale = Vector2.ZERO
	modulate.a = 0.0

	# Animacja jednoczesnego przezroczystości i skalowania (z odbiciem - TRANS_BACK)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)
		
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	
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

# Centralna funkcja zarządzająca wyglądem
func _update_style() -> void:
	if is_selected:
		_apply_style(STYLE_SELECTED)
	elif is_hovering:
		_apply_style(STYLE_HOVER)
	else:
		_apply_style(STYLE_NORMAL)

# Funkcja aplikująca styl do PanelContainer
func _apply_style(style: StyleBox) -> void:
	add_theme_stylebox_override("panel", style)
