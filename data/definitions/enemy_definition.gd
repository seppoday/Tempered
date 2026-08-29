class_name EnemyDefinition extends Resource

@export var id: String
@export var enemy_name: String
@export var scene: PackedScene
@export var max_hp: int = 100
@export var movement_speed: float = 100.0
@export var exp_reward: int = 10
@export var loot_table: LootTable
