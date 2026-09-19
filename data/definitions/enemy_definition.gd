class_name EnemyDefinition extends Resource

@export var id: String
@export var enemy_name: String
@export var sprite: Texture2D

@export var attack_patterns: Array[EnemyAttackPattern] = []
@export var max_hp: int = 100

@export_category("Rewards")
@export var exp_reward: int = 10
@export var loot_table: LootTable
