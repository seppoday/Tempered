class_name ItemDefinition extends Resource

enum Category {
	CONSUMABLE,
	EQUIPMENT,
	MATERIAL
}

@export var id: String
@export var item_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_category("Inventory")
@export var stackable: bool = false
@export var max_stack_size: int = 1
@export var category: Category = Category.EQUIPMENT
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON

@export_category("Equipment")
@export var slot: EquipmentSlot.Type


@export_category("Base Stats")
@export var hp: int = 0
@export var dmg: int = 0
@export var attack_speed: float = 0.0
@export var armor: int = 0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0
@export var dodge: float = 0.0
@export var lifesteal: float = 0.0