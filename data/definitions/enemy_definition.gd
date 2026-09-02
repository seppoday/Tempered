class_name EnemyDefinition extends Resource

@export var id: String
@export var enemy_name: String
@export var scene: PackedScene

@export_category("Stats")
@export var max_hp: int = 100
@export var movement_speed: float = 100.0

@export_category("Attack Settings")
@export var damage: float = 0.0
@export var attack_range: float = 50.0
@export var attack_interval: float = 1.0

@export_category("Rewards")
@export var exp_reward: int = 10
@export var loot_table: LootTable
