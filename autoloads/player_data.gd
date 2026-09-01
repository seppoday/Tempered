# PlayerData.gd
extends Node

signal stats_changed(changed_stat_key: String)
signal item_equipped(slot_type: EquipmentSlot.Type, item_instance: ItemInstance)
signal exp_changed
signal level_up(new_level: int)
signal gold_changed(new_gold_amount: int)

signal attributes_changed
signal attribute_points_changed(points: int)

# ==========================================
# POSTAĆ I POSTĘP
# ==========================================
var character_definition : CharacterDefinition

var character_stats: Dictionary = {
	"name": "Kowal",
	"level": 1,
	"exp": 0,
	"exp_to_next": 100,
}

var points_per_level: int = 3  # Ile punktów dostajemy co poziom
var attribute_points: int = 0  # Punkty na start

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

# Słownik przechowuje teraz obiekty ItemInstance (lub null), kluczowany przez
# EquipmentSlot.Type — dokładnie ten sam enum, którego używa ItemDefinition.slot.
var equipped_items: Dictionary = {
	EquipmentSlot.Type.WEAPON: null,
	EquipmentSlot.Type.HELMET: null,
	EquipmentSlot.Type.CHEST: null,
	EquipmentSlot.Type.GLOVES: null,
	EquipmentSlot.Type.BOOTS: null,
	EquipmentSlot.Type.AMULET: null,
	EquipmentSlot.Type.RING: null,
	EquipmentSlot.Type.OFF_HAND: null,
}

func _ready() -> void:
	character_definition = CharacterDatabase.get_character_definition("warrior")

	if character_definition == null:
		character_definition = CharacterDefinition.new()

	attributes["STR"] = character_definition.starting_str
	attributes["DEX"] = character_definition.starting_dex
	attributes["INT"] = character_definition.starting_int
	attributes["CON"] = character_definition.starting_con
	

# ==========================================
# OBLICZANIE STATYSTYK
# ==========================================
func get_total_stats() -> Dictionary:
	var totals: Dictionary = {}

	# 1. PRZELICZAMY BAZOWE ATRYBUTY NA STATYSTYKI BOJOWE
	# (Nazwy kluczy są teraz identyczne z polami w ItemDefinition!)
	totals["dmg"]           = character_definition.base_dmg + (attributes["STR"] * 2.0)
	totals["magic_dmg"]     = character_definition.base_magic_dmg + (attributes["INT"] * 2.0)
	totals["crit_damage"]   = character_definition.base_crit_damage + (attributes["STR"] * 0.02) + (attributes["INT"] * 0.01)
	
	totals["attack_speed"]  = character_definition.base_attack_speed + (attributes["DEX"] * 0.01)
	totals["crit_chance"]   = character_definition.base_crit_chance + (attributes["DEX"] * 0.005)
	totals["dodge"]         = character_definition.base_dodge + (attributes["DEX"] * 0.002)
	
	totals["hp"]            = character_definition.base_hp + (attributes["CON"] * 10.0)
	totals["armor"]         = character_definition.base_armor  # Bazowo brak armora
	totals["lifesteal"]     = 0.0  # Bazowo brak lifestealu
	
	# Pozostałe statystyki mechaniczne gry (niezależne od eq na razie)
	totals["block_chance"]  = 0.0 + (attributes["CON"] * 0.005)
	totals["attack_range"]  = 1.0
	totals["target_count"]  = 10

	# 2. DODAJEMY EFEKTY Z EKWIPUNKU (Z nowej klasy ItemDefinition)
	# slot_type to teraz wartość enuma EquipmentSlot.Type, nie string
	for slot_type in equipped_items:
		var item: ItemInstance = equipped_items[slot_type]
		
		# Jeśli slot jest pusty lub nie ma poprawnej definicji, pomijamy
		if item == null or item.definition == null:
			continue
			
		var def: ItemDefinition = item.definition
		
		# Sumujemy statystyki bezpośrednio z pól zasobu (Resource)
		totals["hp"] += def.hp
		totals["dmg"] += def.dmg
		totals["magic_dmg"] += def.magic_dmg
		totals["attack_speed"] += def.attack_speed
		totals["armor"] += def.armor
		totals["crit_chance"] += def.crit_chance
		totals["crit_damage"] += def.crit_damage
		totals["dodge"] += def.dodge
		totals["lifesteal"] += def.lifesteal

		if item.upgrade_level > 0 and def.upgrade_curve != null and item.upgrade_level <= def.upgrade_curve.levels.size():
			var levels := def.upgrade_curve.levels
			if item.upgrade_level <= levels.size():
				var upgrade: ItemUpgradeLevel = levels[item.upgrade_level - 1]
				var base_value: float = def.get(upgrade.stat_name)
				var bonus: float = base_value * upgrade.bonus_percent
				if totals.has(upgrade.stat_name):
					totals[upgrade.stat_name] += bonus
				else:
					totals[upgrade.stat_name] = bonus

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


func get_equipped_item(slot_type: EquipmentSlot.Type) -> ItemInstance:
	# Dostosuj do swojej struktury danych, np. słownika:
	return equipped_items.get(slot_type, null)

# Equipuje item we właściwym slocie na podstawie item_instance.definition.slot —
# UI (EquipmentSlot) nie musi znać/przekazywać typu slotu ręcznie.
# Zwraca poprzednio wyekwipowany ItemInstance (lub null), np. do odłożenia go
# z powrotem do ekwipunku.
func equip_item(item_instance: ItemInstance) -> ItemInstance:
	if item_instance == null or item_instance.definition == null:
		return null
	

	var slot_type: EquipmentSlot.Type = item_instance.definition.slot
	var previous: ItemInstance = equipped_items.get(slot_type)
	equipped_items[slot_type] = item_instance
	stats_changed.emit(EquipmentSlot.Type.keys()[slot_type])
	item_equipped.emit(slot_type, item_instance)  # Emitujemy sygnał po zmianie ekwipunku
	print("Equipped item emitted: ", item_instance.definition.name, " in slot: ", slot_type)
	return previous

# Zdejmuje item z podanego slotu. Zwraca zdjęty ItemInstance (lub null).
func unequip_item(slot_type: EquipmentSlot.Type) -> ItemInstance:
	var previous: ItemInstance = equipped_items.get(slot_type)
	equipped_items[slot_type] = null
	stats_changed.emit(EquipmentSlot.Type.keys()[slot_type])
	item_equipped.emit(slot_type, null)  # Emitujemy sygnał po zmianie ekwipunku


	return previous

# ZMIANA: Dostosowane do nowych nazw statystyk (dmg, crit_damage)
func calculate_attack() -> Dictionary:
	var stats := get_total_stats()
	var weapon: ItemInstance = get_equipped_item(EquipmentSlot.Type.WEAPON)

	var raw_damage: float = 0.0

	if weapon != null and weapon.definition != null:
		if weapon.definition.dmg > 0:
			raw_damage += stats["dmg"]
		if weapon.definition.magic_dmg > 0:
			raw_damage += stats["magic_dmg"]

	var is_crit: bool = randf() < stats.get("crit_chance", 0.0)
	if is_crit:
		raw_damage *= stats.get("crit_damage", 1.5)
		
	var text_color := Color.WHITE
	if is_crit: text_color = Color(1.0, 0.85, 0.1)

	return {
		"damage": int(round(raw_damage)),
		"is_crit": is_crit,
		"color": text_color,
		"stats": stats
	}
