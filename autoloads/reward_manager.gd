extends Node

signal rewards_generated(gold_amount: int, reward_options: Array[RewardOption])
signal reward_claimed

var _pending_options: Array[RewardOption] = []
var _pending_gold: int = 0
var _reward_claimed := false

func generate_rewards(enemy_definition: EnemyDefinition) -> void:
	var table: LootTable = enemy_definition.loot_table

	_reward_claimed = false
	_pending_options.clear()
	_pending_gold = 0

	if table and table.gold_max > 0:
		_pending_gold = RNG.randi_range(table.gold_min, table.gold_max)
		if _pending_gold > 0:
			MetaProgressionManager.add_gold(_pending_gold)

	if table:
		_pending_options = _roll_reward_options(table, 3)

	rewards_generated.emit(_pending_gold, _pending_options)

func _roll_reward_options(table: LootTable, count: int) -> Array[RewardOption]:
	var options: Array[RewardOption] = []
	var available_entries: Array[LootEntry] = table.loot_entries.duplicate()
	var upgrade_candidates := _get_upgradeable_slots()

	for i in range(count):
		var item_weight := _total_weight(available_entries)
		var roll_upgrade := table.upgrade_weight > 0 and not upgrade_candidates.is_empty() \
			and RNG.randi_range(1, table.upgrade_weight + item_weight) <= table.upgrade_weight

		if roll_upgrade:
			var slot: EquipmentSlot.Type = upgrade_candidates.pick_random()
			upgrade_candidates.erase(slot)
			var option := RewardOption.new()
			option.type = RewardOption.Type.UPGRADE
			option.upgrade_slot = slot
			option.upgrade_display_item = PlayerData.get_equipped_item(slot).definition
			options.append(option)
			continue

		if available_entries.is_empty():
			break

		var entry := RNG.weighted_pick(available_entries) as LootEntry
		if not entry or not entry.entry is ItemDefinition:
			break
		available_entries.erase(entry)

		var option := RewardOption.new()
		option.type = RewardOption.Type.ITEM
		option.item_definition = entry.entry as ItemDefinition
		options.append(option)

	return options

func _total_weight(entries: Array[LootEntry]) -> int:
	var total := 0
	for e in entries:
		total += e.weight
	return total

func _get_upgradeable_slots() -> Array:
	var result: Array = []
	for slot_type in PlayerData.equipped_items:
		var item: ItemInstance = PlayerData.equipped_items[slot_type]
		if item != null and item.dice_level < GameEnums.DICE_PROGRESSION.size() - 1:
			result.append(slot_type)
	return result

func has_rewards() -> bool:
	return not _pending_options.is_empty()

func claim_option(option: RewardOption) -> void:
	if _reward_claimed:
		return
	_reward_claimed = true

	match option.type:
		RewardOption.Type.ITEM:
			var instance := ItemInstance.new(option.item_definition, 1, 0)
			PlayerData.equip_item(instance)
			Log.print("[REWARD] Założono item -> %s" % option.item_definition.name)
		RewardOption.Type.UPGRADE:
			var item: ItemInstance = PlayerData.get_equipped_item(option.upgrade_slot)
			if item != null and item.dice_level < GameEnums.DICE_PROGRESSION.size() - 1:
				item.dice_level += 1
				Log.print("[REWARD] Upgrade w slocie %s -> poziom %d" % [option.upgrade_slot, item.dice_level])

	reward_claimed.emit()
	_pending_options.clear()
