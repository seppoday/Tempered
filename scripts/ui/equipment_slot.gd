# equipment_slot.gd
class_name EquipmentSlot
extends InventorySlot

enum Type {
	WEAPON,
	HELMET,
	CHEST,
	GLOVES,
	BOOTS,
	AMULET,
	RING,
	OFF_HAND
}

## Which equipment slot this UI slot represents. Set per-instance in the Inspector
## (e.g. the "weapon" panel slot has slot_type = Type.WEAPON).
@export var slot_type: Type = Type.WEAPON

## Optional greyed-out icon shown when the slot is empty (e.g. a sword silhouette
## on the weapon slot), ported over from the old string-based equipment_slot.gd.
@export var placeholder_texture: Texture2D

func _ready() -> void:
	super._ready()
	PlayerData.item_equipped.connect(_on_item_equipped)
	
	# --- POBIERZ AKTUALNY STAN PRZY STARCIE ---
	var current_item: ItemInstance = PlayerData.get_equipped_item(slot_type)
	if current_item:
		super.set_item(current_item)
	else:
		super.clear() # lub po prostu _update_visual()

func _on_item_equipped(equipped_slot_type: Type, item_instance: ItemInstance) -> void:
	print("EquipmentSlot received item_equipped signal for slot ", equipped_slot_type, " with item: ", item_instance)
	if equipped_slot_type != slot_type:
		print("Slot ", slot_type, " received item_equipped signal for slot ", equipped_slot_type, ". Ignoring.")
		return
	
	else:
		if item_instance == null:
			super.clear()
			print("Slot ", slot_type, " cleared.")
		else:
			super.set_item(item_instance)
			print("Slot ", slot_type, " equipped with: ", item_instance.definition.name)

# ==========================================
# DRAG & DROP (restricted to matching equipment)
# ==========================================

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not super._can_drop_data(_at_position, data):
		return false

	var dragged_instance: ItemInstance = data["item_instance"]
	var def := dragged_instance.definition
	if def == null:
		return false

	# Only equipment can go in an equipment slot, and only in its matching slot type.
	return def.category == ItemDefinition.Category.EQUIPMENT and def.slot == slot_type

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	super._drop_data(_at_position, data)
	PlayerData.equip_item(item_data)

# ==========================================
# PUBLIC API
# ==========================================

func clear() -> void:
	super.clear()
	PlayerData.unequip_item(slot_type)

# ==========================================
# VISUAL (placeholder icon when empty)
# ==========================================

func _update_visual() -> void:
	super._update_visual()

	if is_empty():
		if icon and placeholder_texture:
			icon.texture = placeholder_texture
			icon.visible = true
			icon.modulate = Color(1, 1, 1, 0.35)  # półprzezroczysty placeholder
	else:
		if icon:
			icon.modulate = Color(1, 1, 1, 1)  # pełna widoczność przedmiotu
