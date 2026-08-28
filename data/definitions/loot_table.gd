class_name LootTable extends Resource

@export var id: String
@export var loot_entries: Array[LootEntry] = []
@export var gold_min: int = 0
@export var gold_max: int = 0

func roll_entry() -> LootEntry:
	if loot_entries.is_empty():
		return null
	
	var total_weight := 0
	for entry in loot_entries:
		total_weight += entry.weight
	
	var roll := RNG.randi_range(0, total_weight - 1)

	var cumulative_weight := 0
	for entry in loot_entries:
		cumulative_weight += entry.weight
		if roll < cumulative_weight:
			return entry

	return null  # Should never reach here if loot_entries is not empty