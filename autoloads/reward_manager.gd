extends Node

signal rewards_generated(gold_amount: int, loot_entries: Array[LootEntry])
signal reward_claimed

var _pending_loot: Array[LootEntry] = []
var _pending_gold: int = 0
var _reward_claimed := false

func generate_rewards(enemy_definition: EnemyDefinition) -> void:
	var table: LootTable = enemy_definition.loot_table
	
	_reward_claimed = false
	_pending_loot.clear()
	_pending_gold = 0

	# 1. Generowanie złota
	if table and table.gold_max > 0:
		_pending_gold = RNG.randi_range(table.gold_min, table.gold_max)
		if _pending_gold > 0:
			PlayerData.add_gold(_pending_gold)

	# 2. Generowanie przedmiotów (kart)
	if table:
		var available_entries: Array[LootEntry] = table.loot_entries.duplicate()
		var roll_count = min(3, available_entries.size())

		for i in range(roll_count):
			var entry := RNG.weighted_pick(available_entries) as LootEntry
			if not entry:
				break
			_pending_loot.append(entry)
			available_entries.erase(entry)

	# 3. Emitowanie sygnału z gotowymi danymi dla UI
	rewards_generated.emit(_pending_gold, _pending_loot)

func has_rewards() -> bool:
	# Zwraca true tylko, jeśli są karty do wyboru. 
	# Jeśli nie ma kart, gracz nie miałby na co kliknąć na ekranie nagród,
	# więc musimy pominąć ten stan, żeby gra nie utknęła.
	return not _pending_loot.is_empty()

func claim_item(loot_entry: LootEntry) -> void:
	if _reward_claimed:
		return

	_reward_claimed = true

	# Dodanie przedmiotu do ekwipunku
	var inventory = get_tree().get_first_node_in_group("inventory")
	if not inventory:
		Log.print("[ERROR] Nie znaleziono inventory!")
		return

	var instance := ItemInstance.new(loot_entry.entry, 1, 1)
	Log.print("[REWARD] Wybrano przedmiot -> %s" % loot_entry.entry.name)
	inventory.add_item(instance)

	reward_claimed.emit()
	
	_pending_loot.clear()
	
