class_name EnemyDefinition extends Resource

@export var id: String
@export var enemy_name: String
@export var sprite: Texture2D

@export_category("Stats")
@export var max_hp: int = 100

@export_category("Attack")
@export var attack_patterns: Array[EnemyAttackPattern] = []

@export_category("On dead")
@export var loot_table: LootTable
