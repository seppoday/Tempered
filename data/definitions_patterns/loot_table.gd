class_name LootTable extends Resource

@export var id: String
@export var loot_entries: Array[LootEntry] = []
@export var gold_min: int = 0
@export var gold_max: int = 0

func roll_entry() -> LootEntry:
	return RNG.weighted_pick(loot_entries) as LootEntry
