# equipment_slot.gd
extends "res://slot.gd"

@export var accepted_item_type: String = "weapon"  # ustawiane per-slot w Inspectorze
@export var placeholder_texture: Texture2D  # ustawiane per-slot w Inspectorze
signal equipment_changed(slot_type: String, item: Dictionary)

func _ready() -> void:
	super._ready()
	_update_visual()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("item"):
		return false
	return data["item"].get("equip_slot", "") == accepted_item_type

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	super._drop_data(_at_position, data)
	equipment_changed.emit(accepted_item_type, item_data)

func clear() -> void:
	super.clear()
	equipment_changed.emit(accepted_item_type, {})

func _update_visual() -> void:
	super._update_visual()

	if item_data.is_empty():
		if icon and placeholder_texture:
			icon.texture = placeholder_texture
			icon.visible = true
			icon.modulate = Color(1, 1, 1, 0.35)  # półprzezroczysty placeholder
	
	else:
		if icon:
			icon.modulate = Color(1, 1, 1, 1)  # pełna widoczność dla prawdziwego przedmiotu