class_name EnemyDefinition extends Resource

@export var id: String
@export var enemy_name: String
@export var sprite: Texture2D

@export_category("Stats")
@export var max_hp: int = 100
@export var dmg: float = 0.0
@export var magic: float = 0.0
@export var def: float = 0.0
@export var vit: float = 0.0
@export var luck: float = 0.0
@export var status: float = 0.0
@export var crit: float = 0.0

@export_category("Attack")
@export var attack_patterns: Array[EnemyAttackPattern] = []
@export var escalation_rate: float = 0.05   # +5% siły ataku za każdą odbytą turę

@export_category("On dead")
@export var loot_table: LootTable


func get_stat(stat: GameEnums.Stat) -> float:
	var key := SkillStatCalculator.get_stat_key_from_enum(stat)
	if key in self:
		return float(get(key))
	return 0.0


func get_total_stats() -> Dictionary:
	var totals: Dictionary = {}
	for stat in GameEnums.Stat.values():
		var key: String = SkillStatCalculator.get_stat_key_from_enum(stat)
		totals[key] = get_stat(stat)
	totals["hp"] = max_hp
	return totals
