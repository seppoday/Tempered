extends Node

signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D, death_position: Vector2)
signal item_pickup_requested(item_data: ItemInstance, drop_node: Node)
