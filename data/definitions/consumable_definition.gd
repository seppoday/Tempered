class_name ConsumableDefinition
extends InventoryEntry

@export_category("Consumable")

@export var heal_hp: float = 0.0
@export var cooldown: float = 0.0

func use() -> void:
	if heal_hp > 0.0:
		# Heal the player
		PlayerData.heal(heal_hp)
