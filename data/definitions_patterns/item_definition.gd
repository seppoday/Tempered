class_name ItemDefinition
extends InventoryEntry

@export_category("Equipment")
@export var slot: EquipmentSlot.Type

@export_category("Combat Roll")
@export var default_skill: SkillDefinition

@export_category("Staty (poziom 0 = d6)")
@export var dmg: float = 0.0
@export var magic: float = 0.0
@export var def: float = 0.0
@export var vit: float = 0.0
@export var luck: float = 0.0
@export var status: float = 0.0
@export var crit: float = 0.0

@export_category("Wzrost przy upgrade kości (na każdy +1 dice_level)")
@export var dmg_per_level: float = 0.0
@export var magic_per_level: float = 0.0
@export var def_per_level: float = 0.0
@export var vit_per_level: float = 0.0
@export var luck_per_level: float = 0.0
@export var status_per_level: float = 0.0
@export var crit_per_level: float = 0.0

@export var price: int = 0

@export_category("Special")
@export_range(0.0, 1.0, 0.01) var lifesteal_percent: float = 0.0

@export_category("Affinity")
@export var affinities: Array[ItemAffinity] = []


## Zwraca wartość statystyki z uwzględnieniem poziomu kości.
func get_stat(stat: GameEnums.Stat, dice_level: int = 0) -> float:
	var base := 0.0
	var per_level := 0.0
	match stat:
		GameEnums.Stat.DMG:
			base = dmg
			per_level = dmg_per_level
		GameEnums.Stat.MAGIC:
			base = magic
			per_level = magic_per_level
		GameEnums.Stat.DEF:
			base = def
			per_level = def_per_level
		GameEnums.Stat.VIT:
			base = vit
			per_level = vit_per_level
		GameEnums.Stat.LUCK:
			base = luck
			per_level = luck_per_level
		GameEnums.Stat.STATUS:
			base = status
			per_level = status_per_level
		GameEnums.Stat.CRIT:
			base = crit
			per_level = crit_per_level
	return base + per_level * max(0, dice_level)


func get_affinity_multiplier(element: GameEnums.DamageElement) -> float:
	for affinity in affinities:
		if affinity.element == element:
			return affinity.multiplier
	return 1.0


## Lista statów, które rosną przy upgrade.
## Format: Array[Dictionary] z kluczami: "stat", "name", "current", "next", "gain"
func get_upgrade_stat_deltas(current_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var next_level := current_level + 1
	var pairs := [
		[GameEnums.Stat.DMG, "Damage"],
		[GameEnums.Stat.MAGIC, "Magic Damage"],
		[GameEnums.Stat.DEF, "Defense"],
		[GameEnums.Stat.VIT, "Vitality"],
		[GameEnums.Stat.LUCK, "Luck"],
		[GameEnums.Stat.STATUS, "Status"],
		[GameEnums.Stat.CRIT, "Crit"],
	]
	for pair in pairs:
		var stat_enum: GameEnums.Stat = pair[0]
		var display_name: String = pair[1]
		var current_val := get_stat(stat_enum, current_level)
		var next_val := get_stat(stat_enum, next_level)
		var gain := next_val - current_val
		if is_equal_approx(gain, 0.0):
			continue
		result.append({
			"stat": stat_enum,
			"name": display_name,
			"current": current_val,
			"next": next_val,
			"gain": gain,
		})
	return result
