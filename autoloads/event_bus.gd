extends Node

signal enemy_spawned(enemy: Node2D) # Na razie nie używane nigdzie
signal enemy_died(enemy: Node2D)
signal player_damaged(amount: int, shield_amount: int)
