class_name ItemDefinition extends InventoryEntry

@export_category("Equipment")
@export var slot: EquipmentSlot.Type

@export_category("Base Stats")
@export var hp: int = 0
@export var dmg: float = 0
@export var magic_dmg: int = 0
@export var attack_speed: float = 0.0
@export var armor: int = 0
@export var block_chance: float = 0.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0
@export var dodge: float = 0.0
@export var lifesteal: float = 0.0

@export_category("Combat Roll")
@export_range(0, 6, 1) var dice_level = 0
@export var default_skill: SkillDefinition