class_name InventoryEntry extends Resource

enum Category {
	CONSUMABLE,
	EQUIPMENT,
	MATERIAL,
	UPGRADE_STONE
}

@export var id: String
@export var name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_category("Inventory")
@export var category: Category = Category.EQUIPMENT
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
@export var stackable: bool = false
@export var max_stack_size: int = 1
