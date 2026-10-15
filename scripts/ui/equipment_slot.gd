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
	SHIELD,
	LEGS,
}

@export var slot_type: Type = Type.WEAPON
@export var placeholder_texture: Texture2D

func _ready() -> void:
	super._ready()
	PlayerData.item_equipped.connect(_on_item_equipped)

	var current_item: ItemInstance = PlayerData.get_equipped_item(slot_type)
	if current_item:
		super.set_item(current_item)
	else:
		super.clear()

func _on_item_equipped(equipped_slot_type: Type, item_instance: ItemInstance) -> void:
	if equipped_slot_type != slot_type:
		return

	if item_instance == null:
		super.clear()
	else:
		super.set_item(item_instance)


func clear() -> void:
	super.clear()
	PlayerData.unequip_item(slot_type)

func _update_visual() -> void:
	super._update_visual()

	if is_empty():
		if icon and placeholder_texture:
			icon.texture = placeholder_texture
			icon.visible = true
			icon.modulate = Color(1, 1, 1, 0.15)
		return

	if icon:
		icon.modulate = Color(1, 1, 1, 1)
