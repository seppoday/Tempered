extends Node

signal stats_changed(changed_stat_key: String)
signal exp_changed
signal level_up(new_level: int)
signal gold_changed(new_gold_amount: int)

signal attributes_changed
signal attribute_points_changed(points: int)

# ==========================================
# POSTAĆ I POSTĘP
# ==========================================
var character_stats: Dictionary = {
	"name": "Kowal",
	"level": 1,
	"exp": 0,
	"exp_to_next": 100,
}

var points_per_level: int = 3  # Ile punktów dostajemy co poziom
var attribute_points: int = 5  # Punkty na start (zmieniłem na 5 dla testów)

var gold: int = 0

# ==========================================
# BAZOWE ATRYBUTY
# ==========================================
var attributes: Dictionary = {
	"STR": 10,
	"DEX": 10,
	"INT": 10,
	"CON": 10,
}

var equipped_items: Dictionary = {}

# ==========================================
# OBLICZANIE STATYSTYK
# ==========================================
func get_total_stats() -> Dictionary:
	var totals: Dictionary = {}

	# 1. PRZELICZAMY ATRYBUTY NA STATYSTYKI BOJOWE
	totals["base_damage"]     = 5.0 + (attributes["STR"] * 2.0)
	totals["crit_multiplier"] = 1.5 + (attributes["STR"] * 0.02) + (attributes["INT"] * 0.01)
	
	totals["attack_speed"]    = 9.5 + (attributes["DEX"] * 0.01)
	totals["crit_chance"]     = 0.05 + (attributes["DEX"] * 0.005)
	totals["dodge_chance"]    = 0.0 + (attributes["DEX"] * 0.002)
	
	totals["max_hp"]          = 100.0 + (attributes["CON"] * 10.0)
	totals["block_chance"]    = 0.0 + (attributes["CON"] * 0.005)
	
	totals["fire_damage"]     = 0.0 + (attributes["INT"] * 0.5)
	
	totals["attack_range"] = 1.0
	totals["target_count"] = 10

	# 2. DODAJEMY EFEKTY Z EKWIPUNKU
	for slot_type in equipped_items:
		var item: Dictionary = equipped_items[slot_type]
		if item.is_empty():
			continue
		for key in item.keys():
			if typeof(item[key]) in [TYPE_INT, TYPE_FLOAT]:
				totals[key] = totals.get(key, 0.0) + item[key]

	return totals

# ==========================================
# ROZDAWANIE PUNKTÓW ATRYBUTÓW
# ==========================================
func can_add_attribute() -> bool:
	return attribute_points > 0

func add_attribute(attr_name: String) -> bool:
	if attribute_points <= 0 or not attributes.has(attr_name):
		return false

	attributes[attr_name] += 1
	attribute_points -= 1

	attributes_changed.emit()
	attribute_points_changed.emit(attribute_points)
	stats_changed.emit(attr_name) # Wywołuje odświeżenie w UI
	return true

# ==========================================
# EKONOMIA I LEVELOWANIE
# ==========================================
func add_exp(amount: int) -> void:
	character_stats["exp"] += amount
	var leveled: bool = false
	
	while character_stats["exp"] >= character_stats["exp_to_next"]:
		character_stats["exp"] -= character_stats["exp_to_next"]
		character_stats["level"] += 1
		character_stats["exp_to_next"] = int(character_stats["exp_to_next"] * 1.15)
		
		attribute_points += points_per_level
		leveled = true

	exp_changed.emit()
	if leveled:
		level_up.emit(character_stats["level"])
		attribute_points_changed.emit(attribute_points)
		stats_changed.emit("level")

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func set_equipped_item(slot_type: String, item_data: Dictionary) -> void:
	equipped_items[slot_type] = item_data
	stats_changed.emit(slot_type)

func calculate_attack() -> Dictionary:
	var stats := get_total_stats()
	var raw_damage: float = stats.get("base_damage", 1.0)
	var is_crit: bool = randf() < stats.get("crit_chance", 0.0)
	if is_crit:
		raw_damage *= stats.get("crit_multiplier", 1.5)
		
	var text_color := Color.WHITE
	if is_crit: text_color = Color(1.0, 0.85, 0.1)
	elif stats.get("fire_damage", 0) > 0: text_color = Color(1.0, 0.4, 0.2)

	return {
		"damage": int(round(raw_damage)),
		"is_crit": is_crit,
		"color": text_color,
		"stats": stats
	}