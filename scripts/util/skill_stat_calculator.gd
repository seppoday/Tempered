class_name SkillStatCalculator
extends RefCounted


static func get_stat_key_from_enum(stat_enum: GameEnums.Stat) -> String:
	var enum_name: String = GameEnums.Stat.keys()[stat_enum].to_lower()
	match enum_name:
		"vitality":
			return "vit"
		"defense":
			return "def"
		"damage":
			return "dmg"
		_:
			return enum_name


static func is_item_equipped(item_instance: ItemInstance) -> bool:
	if item_instance == null:
		return false
	if "is_equipped" in item_instance and bool(item_instance.is_equipped):
		return true
	if "equipped" in item_instance and bool(item_instance.equipped):
		return true
	if item_instance.has_method("is_equipped") and item_instance.is_equipped():
		return true
	if PlayerData.has_method("is_item_equipped") and PlayerData.is_item_equipped(item_instance):
		return true
	for field in ["equipment", "equipped_items", "equipment_slots", "slots", "gear"]:
		if field in PlayerData:
			var container = PlayerData.get(field)
			if container is Array and item_instance in container:
				return true
			elif container is Dictionary:
				for val in container.values():
					if val == item_instance:
						return true
					if val != null and typeof(val) == TYPE_OBJECT:
						if "item" in val and val.item == item_instance:
							return true
						if "item_instance" in val and val.item_instance == item_instance:
							return true
	return false


static func get_equipped_item_in_slot(slot) -> ItemInstance:
	if slot == null:
		return null
	if PlayerData.has_method("get_equipped_item"):
		return PlayerData.get_equipped_item(slot)
	for field_name in ["equipment", "equipped_items", "equipment_slots", "slots", "gear"]:
		if field_name in PlayerData:
			var container = PlayerData.get(field_name)
			if container is Dictionary and container.has(slot):
				var val = container[slot]
				if val is ItemInstance:
					return val
				elif val != null and typeof(val) == TYPE_OBJECT:
					if "item" in val and val.item is ItemInstance:
						return val.item
					if "item_instance" in val and val.item_instance is ItemInstance:
						return val.item_instance
	return null


## Pobiera statystykę z itemu z uwzględnieniem jego dice_level.
static func get_item_stat(item, stat_enum: GameEnums.Stat) -> float:
	if item == null:
		return 0.0
	var def = item.definition if ("definition" in item and item.definition) else item
	if def == null:
		return 0.0
	var level := 0
	if item is ItemInstance and "dice_level" in item:
		level = item.dice_level
	if def.has_method("get_stat"):
		return def.get_stat(stat_enum, level)
	var stat_key := get_stat_key_from_enum(stat_enum)
	if stat_key in def:
		return float(def.get(stat_key))
	return 0.0


static func get_player_stat_from_dict(stats: Dictionary, stat_enum: GameEnums.Stat) -> float:
	var full_key = GameEnums.Stat.keys()[stat_enum].to_lower()
	if stats.has(full_key):
		return float(stats[full_key])
	var short_key := get_stat_key_from_enum(stat_enum)
	if stats.has(short_key):
		return float(stats[short_key])
	return 0.0


## Zachowane na wypadek UI porównującego itemy — obecnie combat/tooltip używa get_item_stat.
static func get_total_stat_value(stat_enum: GameEnums.Stat, preview_item: ItemInstance) -> float:
	var player_stats: Dictionary = {}
	if PlayerData.has_method("get_total_stats"):
		player_stats = PlayerData.get_total_stats()
	elif "totals" in PlayerData and PlayerData.totals is Dictionary:
		player_stats = PlayerData.totals
	var current_total_stats := get_player_stat_from_dict(player_stats, stat_enum)
	if is_item_equipped(preview_item):
		return current_total_stats
	var replaced_item_stat := 0.0
	if preview_item and preview_item.definition and "slot" in preview_item.definition:
		var target_slot = preview_item.definition.slot
		var currently_equipped_item = get_equipped_item_in_slot(target_slot)
		if currently_equipped_item and currently_equipped_item != preview_item:
			replaced_item_stat = get_item_stat(currently_equipped_item, stat_enum)
	var new_item_stat := get_item_stat(preview_item, stat_enum)
	return current_total_stats - replaced_item_stat + new_item_stat


## Formuła zgodna z CombatManager._create_status_from_trigger (staty TYLKO z itemu).
static func calculate_trigger_status_preview(trigger: SkillTriggerBase, dice_size: int, preview_item: ItemInstance) -> Dictionary:
	var min_roll := 1.0
	var max_roll := float(dice_size) if dice_size > 0 else 1.0
	var status_stat := get_item_stat(preview_item, GameEnums.Stat.STATUS)
	var magic_stat := get_item_stat(preview_item, GameEnums.Stat.MAGIC)
	var dmg_stat := get_item_stat(preview_item, GameEnums.Stat.DMG)
	var tick_min := 0.0
	var tick_max := 0.0
	var initial_min := 0.0
	var initial_max := 0.0
	var duration := 3
	match trigger.apply_status:
		GameEnums.StatusType.BURN:
			tick_min = status_stat * 0.4 * min_roll
			tick_max = status_stat * 0.4 * max_roll
			duration = 3 + int(floor(status_stat / 20.0))
		GameEnums.StatusType.POISON:
			initial_min = magic_stat * 0.3 * min_roll
			initial_max = magic_stat * 0.3 * max_roll
			tick_min = status_stat * 0.6 * min_roll
			tick_max = status_stat * 0.6 * max_roll
			duration = 4
		GameEnums.StatusType.BLEED:
			tick_min = dmg_stat * 0.25
			tick_max = dmg_stat * 0.25
			duration = 3
	return {
		"tick_min": tick_min, "tick_max": tick_max,
		"initial_min": initial_min, "initial_max": initial_max,
		"duration": duration
	}


## dice_roll * primary.weight * inner_sum(item @ dice_level) * affinity * hits
static func calculate_projected_range(skill_def: SkillDefinition, dice_size: int, preview_item: ItemInstance) -> Vector2:
	if skill_def.scalings.is_empty():
		return Vector2.ZERO
	var min_roll := 1.0
	var max_roll := float(dice_size) if dice_size > 0 else 1.0
	var primary := skill_def.scalings[0]
	var inner_sum: float = get_item_stat(preview_item, primary.stat)
	for i in range(1, skill_def.scalings.size()):
		var secondary := skill_def.scalings[i]
		inner_sum += get_item_stat(preview_item, secondary.stat) * secondary.weight
	var affinity_mult := 1.0
	if preview_item and preview_item.definition:
		if preview_item.definition.has_method("get_affinity_multiplier"):
			affinity_mult = preview_item.definition.get_affinity_multiplier(skill_def.damage_element)
		elif "affinities" in preview_item.definition:
			for aff in preview_item.definition.affinities:
				if aff.element == skill_def.damage_element:
					affinity_mult = aff.multiplier
					break
	var total_hits := 1
	if skill_def.bonus_hits_per_stat:
		var bonus_stat_val := get_item_stat(preview_item, skill_def.bonus_hits_per_stat.stat)
		var bonus_hits := int(floor(bonus_stat_val * skill_def.bonus_hits_per_stat.weight))
		total_hits += bonus_hits
	var min_outcome := min_roll * primary.weight * inner_sum * affinity_mult * total_hits
	var max_outcome := max_roll * primary.weight * inner_sum * affinity_mult * total_hits
	return Vector2(min_outcome, max_outcome)


static func format_dice_value(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(round(value))
	return "%.1f" % value
