# PlayerData.gd
extends Node

# Sygnały informujące resztę gry o zmianach
signal stats_changed(changed_stat_key: String)
signal exp_changed
signal level_up(new_level: int)
signal gold_changed(new_gold_amount: int)

var gold: int = 0

# DANE POSTACI
var character_stats: Dictionary = {
	"name": "Kowal",
	"level": 1,
	"exp": 0,
	"exp_to_next": 100,
}

# BAZOWE STATYSTYKI
var base_stats: Dictionary = {
	"base_damage": 5,
	"attack_speed": 1.0,
	"crit_chance": 0.05,
	"crit_multiplier": 1.5,
	"attack_range": 1.0,
	"target_count": 1,
}

# EKWIPUNEK: slot_name -> item_data Dictionary
var equipped_items: Dictionary = {}


# ==========================================
# OBICZANIE AGREGOWANYCH STATYSTYK
# ==========================================

func get_total_stats() -> Dictionary:
	var totals: Dictionary = base_stats.duplicate(true)
	for slot_type in equipped_items:
		var item: Dictionary = equipped_items[slot_type]
		if item.is_empty():
			continue
		for key in item.keys():
			if typeof(item[key]) in [TYPE_INT, TYPE_FLOAT]:
				totals[key] = totals.get(key, 0) + item[key]
	return totals

func set_equipped_item(slot_type: String, item_data: Dictionary) -> void:
	equipped_items[slot_type] = item_data
	stats_changed.emit(slot_type)


# ==========================================
# LOGIKA WALKI (ATAK / KALKULACJE)
# ==========================================

# Funkcja pomocnicza, która wylicza kompletny atak (dmg, crit, kolor tekstu)
func calculate_attack() -> Dictionary:
	var stats := get_total_stats()
	var raw_damage: float = stats.get("base_damage", 1)
	
	# Losowanie krytyka
	var is_crit: bool = randf() < stats.get("crit_chance", 0.0)
	if is_crit:
		raw_damage *= stats.get("crit_multiplier", 1.5)
		
	var final_damage := int(round(raw_damage))
	
	# Dobór koloru tekstu dla Floating Text
	var text_color := Color.WHITE
	if is_crit:
		text_color = Color(1.0, 0.8, 0.1) # Złoty dla krytyka
	elif stats.get("fire_damage", 0) > 0:
		text_color = Color(1.0, 0.4, 0.2) # Pomarańczowy dla ognia

	return {
		"damage": final_damage,
		"is_crit": is_crit,
		"color": text_color,
		"stats": stats # Przekazujemy pełne staty do nakładania efektów DoT/Stun
	}


# ==========================================
# EXP / LEVELING
# ==========================================

func add_exp(amount: int) -> void:
	character_stats["exp"] += amount
	var leveled: bool = false
	
	while character_stats["exp"] >= character_stats["exp_to_next"]:
		character_stats["exp"] -= character_stats["exp_to_next"]
		character_stats["level"] += 1
		character_stats["exp_to_next"] = int(character_stats["exp_to_next"] * 1.15)
		leveled = true

	exp_changed.emit()
	if leveled:
		level_up.emit(character_stats["level"])
		stats_changed.emit("level")


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func remove_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false