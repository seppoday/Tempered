class_name ItemDefinition extends InventoryEntry

@export_category("Equipment")
@export var slot: EquipmentSlot.Type

@export_category("Combat Roll")
@export var default_skill: SkillDefinition

@export_category("Staty")
@export var dmg: float = 0.0
@export var magic: float = 0.0
@export var def: float = 0.0
@export var vit: float = 0.0
@export var speed: float = 0.0
@export var luck: float = 0.0
@export var status: float = 0.0
@export var crit: float = 0.0

@export_category("Affinity")
@export var affinities: Array[ItemAffinity] = []

func get_stat(stat: GameEnums.Stat) -> float:
	match stat:
		GameEnums.Stat.DMG: return dmg
		GameEnums.Stat.MAGIC: return magic
		GameEnums.Stat.DEF: return def
		GameEnums.Stat.VIT: return vit
		GameEnums.Stat.SPEED: return speed
		GameEnums.Stat.LUCK: return luck
		GameEnums.Stat.STATUS: return status
		GameEnums.Stat.CRIT: return crit
	return 0.0

func get_affinity_multiplier(element: GameEnums.DamageElement) -> float:
	for affinity in affinities:
		if affinity.element == element:
			return affinity.multiplier
	return 1.0
