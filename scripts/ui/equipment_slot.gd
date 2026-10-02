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

@onready var skill_icon: TextureRect = $SkillIcon

func _ready() -> void:
	super._ready()
	PlayerData.item_equipped.connect(_on_item_equipped)
	mouse_entered.connect(_on_mouse_entered_preview)
	mouse_exited.connect(_on_mouse_exited_preview)

	var current_item: ItemInstance = PlayerData.get_equipped_item(slot_type)
	if current_item:
		super.set_item(current_item)
	else:
		super.clear()


func _on_mouse_entered_preview() -> void:
	if not get_viewport().gui_is_dragging():
		return

	var data: Variant = get_viewport().gui_get_drag_data()
	if not (data is Dictionary and data.has("item_instance")):
		return

	var dragged_instance: ItemInstance = data["item_instance"]
	var def := dragged_instance.definition

	if not def is ItemDefinition:
		return
	if def.category != InventoryEntry.Category.EQUIPMENT or def.slot != slot_type:
		return

	var preview := PlayerData.get_total_stats_with_swap(slot_type, dragged_instance)
	PlayerData.stat_preview_started.emit(preview)


func _on_mouse_exited_preview() -> void:
	PlayerData.stat_preview_ended.emit()

func _on_item_equipped(equipped_slot_type: Type, item_instance: ItemInstance) -> void:
	if equipped_slot_type != slot_type:
		return
	
	else:
		if item_instance == null:
			super.clear()
		else:
			super.set_item(item_instance)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not super._can_drop_data(_at_position, data):
		return false

	var dragged_instance: ItemInstance = data["item_instance"]
	var def := dragged_instance.definition
	if def == null:
		return false

	if def is SkillItemDefinition:
		return not is_empty() and item_data.definition is ItemDefinition

	if def is MaterialDefinition:
		return def.category == InventoryEntry.Category.UPGRADE_STONE

	if def is ItemDefinition:
		return def.category == InventoryEntry.Category.EQUIPMENT and def.slot == slot_type

	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dragged_instance: ItemInstance = data["item_instance"]
	super._drop_data(_at_position, data)

	if dragged_instance.definition is SkillItemDefinition:
		return

	PlayerData.equip_item(item_data)


func clear() -> void:
	super.clear()
	PlayerData.unequip_item(slot_type)

func _update_visual() -> void:
	super._update_visual()

	if is_empty():
		if icon and placeholder_texture:
			icon.texture = placeholder_texture
			icon.visible = true
			icon.modulate = Color(1, 1, 1, 0.35)
		skill_icon.texture = null
		skill_icon.visible = false
		return

	if icon:
		icon.modulate = Color(1, 1, 1, 1)

	var active_skill: SkillDefinition = item_data.equipped_skill if item_data.equipped_skill else item_data.definition.default_skill
	if active_skill and active_skill.icon:
		skill_icon.texture = active_skill.icon
		skill_icon.visible = true
	else:
		skill_icon.texture = null
		skill_icon.visible = false
