class_name InventorySlot
extends Panel

var item_data: ItemInstance = null

@onready var icon: TextureRect = %Icon
@onready var count_label: Label = %CountLabel
@onready var name_label: Label = %Name

signal slot_changed(slot: Panel)

const STAT_DISPLAY := {
	"dmg":    ["Attack Damage", Color(0.95, 0.95, 0.95), preload("uid://pdoitlfackp")],
	"magic":  ["Magic Damage", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"def":    ["Defense", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"vit":    ["Vitality", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"luck":   ["Luck", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"status": ["Status", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
	"crit":   ["Critical", Color(0.95, 0.95, 0.95), preload("uid://cyu1e16lmrvk7")],
}

const BASE_BG := Color(0.12, 0.12, 0.14, 1.0)
const BASE_BORDER := Color(0.32, 0.32, 0.36, 1.0)

const FONT_TITLE := 28
const FONT_BODY := 20
const TOOLTIP_WIDTH := 700

func _ready() -> void:
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	var is_double_click_lmb = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click
	if not is_double_click_lmb:
		return

	if is_empty() or item_data.definition.category != InventoryEntry.Category.CONSUMABLE:
		return

	item_data.use()
	item_data.quantity -= 1

	if item_data.quantity <= 0:
		clear()
	else:
		_update_visual()

	slot_changed.emit(self)

func _make_custom_tooltip(_for_text: String) -> Control:
	if is_empty() or not item_data.definition:
		return null

	var tooltip := preload("uid://d3l2j2u2xebjv").instantiate() as InventoryTooltip
	tooltip.populate(item_data, STAT_DISPLAY)

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


func _make_separator() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(0.35, 0.32, 0.22, 0.6)
	return line


func _colorize_numbers(text: String) -> String:
	var regex := RegEx.new()
	regex.compile(r"(\d+\.?\d*%?)")
	return regex.sub(text, "[color=#ff8c39]$1[/color]", true)

func _get_rarity_color() -> Color:
	if is_empty() or not item_data.definition:
		return Color.WHITE
	return GameEnums.get_rarity_color(item_data.definition.rarity)

func set_item(new_instance: ItemInstance) -> void:
	item_data = new_instance
	_update_visual()

func clear() -> void:
	item_data = null
	_update_visual()

func is_empty() -> bool:
	return item_data == null

func _update_visual() -> void:
	modulate = Color.WHITE

	if is_empty() or not item_data.definition:
		tooltip_text = ""
		icon.texture = null
		icon.visible = false
		count_label.text = ""
		name_label.text = ""
		_apply_slot_style(BASE_BG, BASE_BORDER)
	else:
		tooltip_text = "use_custom"
		var def = item_data.definition
		icon.texture = def.icon
		icon.visible = icon.texture != null
		count_label.text = str(item_data.quantity) if item_data.quantity >= 1 else ""
		name_label.text = str(item_data.definition.name) if item_data.definition.name else ""

		var rarity_color := _get_rarity_color()
		_apply_slot_style(BASE_BG.lerp(rarity_color, 0.08), BASE_BORDER.lerp(rarity_color, 0.55))

func _apply_slot_style(bg: Color, border: Color) -> void:
	var new_style := StyleBoxFlat.new()
	new_style.bg_color = bg
	new_style.border_color = border
	new_style.set_border_width_all(2)
	new_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", new_style)

func _get_stat_key_from_enum(stat_enum: GameEnums.Stat) -> String:
	var enum_name: String = GameEnums.Stat.keys()[stat_enum].to_lower()
	
	match enum_name:
		"vitality": return "vit"
		"defense": return "def"
		"damage": return "dmg"
		_: return enum_name
