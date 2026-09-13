extends PanelContainer

signal toggled(card: PanelContainer, is_selected: bool)

@onready var item_label: Label = %ItemLabel
@onready var skill_label: Label = %SkillLabel
@onready var multiplier_label: Label = %MultiplierLabel

var result_data: Dictionary
var is_selected: bool = false
var is_hovering: bool = false  # Śledzimy, czy myszka jest nad kartą

# Poprawiłem prawdopodobną pomyłkę w nazwach plików (normal -> normal, hover -> hover)
const STYLE_NORMAL = preload("res://assets/styles/roll_panel_normal.tres")
const STYLE_HOVER = preload("res://assets/styles/roll_panel_hover.tres")
const STYLE_SELECTED = preload("res://assets/styles/roll_panel_selected.tres")

func _ready() -> void:
	# Automatycznie łączymy sygnały myszy, aby mieć pewność, że działają
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_style()


func setup(data: Dictionary) -> void:
	result_data = data
	item_label.text = result_data["item"].definition.name
	skill_label.text = result_data["skill"].skill_name
	multiplier_label.text = str(result_data["multiplier"])
	
	
	# TODO: wypełnij Labelki na podstawie result_data["item"]/["skill"]/["multiplier"]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit(self, not is_selected)

func _on_mouse_entered() -> void:
	is_hovering = true
	_update_style()

func _on_mouse_exited() -> void:
	is_hovering = false
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
