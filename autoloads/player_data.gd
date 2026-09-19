# PlayerData.gd
extends Node

signal stats_changed(changed_stat_key: String)
signal item_equipped(slot_type: EquipmentSlot.Type, item_instance: ItemInstance)
signal exp_changed
signal level_up(new_level: int)
signal gold_changed(new_gold_amount: int)

signal attributes_changed

signal hp_changed(current_hp: float, max_hp: float)
signal damage_taken(damage_amount: float, was_dodged: bool)

# ==========================================
# POSTAĆ I POSTĘP
# ==========================================
var character_definition : CharacterDefinition

var picks_per_cycle: int = 3

var character_stats: Dictionary = {
	"level": 1,
	"exp": 0,
	"exp_to_next": 100,
}

var gold: int = 0

var current_hp: float = 0.0
var pending_block: float = 0.0
var pending_dodge_bonus: float = 0.0

# ==========================================
# BAZOWE ATRYBUTY
# ==========================================
var attributes: Dictionary = {
	"STR": 10,
	"DEX": 10,
	"INT": 10,
	"CON": 10,
}

var equipped_items: Dictionary = {
	EquipmentSlot.Type.WEAPON: null,
	EquipmentSlot.Type.HELMET: null,
	EquipmentSlot.Type.CHEST: null,
	EquipmentSlot.Type.GLOVES: null,
	EquipmentSlot.Type.BOOTS: null,
	EquipmentSlot.Type.AMULET: null,
	EquipmentSlot.Type.RING: null,
	EquipmentSlot.Type.ADDITIONAL: null,
}


# DEBUG
const DEBUG_START_GEAR: Array[Dictionary] = [
	# [id, count, level (0-6)]
	{"id": "rusty_sword",    "count": 1, "level": 1},
	{"id": "iron_shield",    "count": 1, "level": 1},
	{"id": "silver_amulet",  "count": 1, "level": 6},
	{"id": "knight_armor",   "count": 1, "level": 6},
	{"id": "leather_gloves", "count": 1, "level": 6},
	{"id": "hunter_boots",   "count": 1, "level": 6},
	{"id": "leather_cap",    "count": 1, "level": 6},
]

func give_debug_gear() -> void:
	for item in DEBUG_START_GEAR:
		var item_definition := ItemDatabase.get_by_id(item.id)

		if item_definition == null:
			push_warning("give_debug_gear: nie znaleziono przedmiotu o ID: %s" % item.id)
			continue

		var count: int = item.get("count", 1)
		var level: int = item.get("level", 1)

		equip_item(ItemInstance.new(item_definition, count, level))

func _ready() -> void:
	give_debug_gear()

	character_definition = CharacterDatabase.get_by_id("warrior") # chwilowe, tylko debug

	if character_definition == null:
		push_warning("Nie znaleziono character definition w pliku Player_Data")
		return

	attributes["STR"] = character_definition.starting_str
	attributes["DEX"] = character_definition.starting_dex
	attributes["INT"] = character_definition.starting_int
	attributes["CON"] = character_definition.starting_con

	current_hp = get_total_stats()["hp"]

# ==========================================
# OBLICZANIE STATYSTYK
# ==========================================
func get_total_stats() -> Dictionary:
	var totals: Dictionary = {}

	# 1. PRZELICZAMY BAZOWE ATRYBUTY NA STATYSTYKI BOJOWE
	# (Nazwy kluczy są teraz identyczne z polami w ItemDefinition!)
	totals["dmg"]           = character_definition.base_dmg + (attributes["STR"] * 1.0)
	totals["magic_dmg"]     = character_definition.base_magic_dmg + (attributes["INT"] * 1.0)
	totals["crit_damage"]   = character_definition.base_crit_damage + (attributes["STR"] * 0.02) + (attributes["INT"] * 0.01)
	
	totals["attack_speed"]  = character_definition.base_attack_speed + (attributes["DEX"] * 0.01)
	totals["crit_chance"]   = character_definition.base_crit_chance + (attributes["DEX"] * 0.005)
	totals["dodge"]         = character_definition.base_dodge + (attributes["DEX"] * 0.002)
	
	totals["hp"]            = character_definition.base_hp + (attributes["CON"] * 5.0)
	totals["armor"]         = character_definition.base_armor  # Bazowo brak armora
	totals["lifesteal"]     = 0.0  # Bazowo brak lifestealu
	
	# Pozostałe statystyki mechaniczne gry
	totals["block_chance"]  = 0.0 + (attributes["CON"] * 0.005)
	totals["attack_range"]  = 1.0
	totals["target_count"]  = 10

	# 2. DODAJEMY EFEKTY Z EKWIPUNKU
	for slot_type in equipped_items:
		var item: ItemInstance = equipped_items[slot_type]
		
		if item == null or item.definition == null:
			continue
			
		var def: ItemDefinition = item.definition
		
		totals["hp"] += def.hp
		totals["dmg"] += def.dmg
		totals["magic_dmg"] += def.magic_dmg
		totals["attack_speed"] += def.attack_speed
		totals["armor"] += def.armor
		totals["crit_chance"] += def.crit_chance
		totals["crit_damage"] += def.crit_damage
		totals["dodge"] += def.dodge
		totals["lifesteal"] += def.lifesteal

	return totals

# ==========================================
# EKONOMIA I LEVELOWANIE
# ==========================================
func add_exp(amount: int) -> void:
	character_stats["exp"] += amount
	var leveled: bool = false
	
	while character_stats["exp"] >= character_stats["exp_to_next"]:
		character_stats["exp"] -= character_stats["exp_to_next"]
		character_stats["level"] += 1
		character_stats["exp_to_next"] = int(character_stats["exp_to_next"] * 1.45)
		
		leveled = true

	exp_changed.emit()
	if leveled:
		level_up.emit(character_stats["level"])
		stats_changed.emit("level")

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func get_equipped_item(slot_type: EquipmentSlot.Type) -> ItemInstance:
	return equipped_items.get(slot_type, null)


func equip_item(item_instance: ItemInstance) -> ItemInstance:
	if item_instance == null or item_instance.definition == null:
		return null
	
	var slot_type: EquipmentSlot.Type = item_instance.definition.slot
	var previous: ItemInstance = equipped_items.get(slot_type)
	equipped_items[slot_type] = item_instance
	
	stats_changed.emit(EquipmentSlot.Type.keys()[slot_type])
	item_equipped.emit(slot_type, item_instance)
	return previous


func unequip_item(slot_type: EquipmentSlot.Type) -> ItemInstance:
	var previous: ItemInstance = equipped_items.get(slot_type)
	equipped_items[slot_type] = null
	
	stats_changed.emit(EquipmentSlot.Type.keys()[slot_type])
	item_equipped.emit(slot_type, null)
	return previous


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
	if is_crit: 
		text_color = Color(1.0, 0.85, 0.1)

	return {
		"damage": int(round(raw_damage)),
		"is_crit": is_crit,
		"color": text_color,
		"stats": stats
	}


func take_damage(amount: float) -> void:
	var stats := get_total_stats()
	var effective_dodge: float = stats.get("dodge", 0.0) + pending_dodge_bonus
	pending_dodge_bonus = 0.0

	if RNG.randf() < effective_dodge:
		damage_taken.emit(0.0, true)
		return

	var mitigated: float = max(0.0, amount - pending_block)
	pending_block = 0.0

	var armor: float = stats.get("armor", 0.0)
	var armor_reduction: float = calculate_armor_reduction(armor)
	var final_damage: float = mitigated * (1.0 - armor_reduction)

	current_hp = max(0.0, current_hp - final_damage)
	damage_taken.emit(final_damage, false)
	hp_changed.emit(current_hp, stats["hp"])


# Formuła redukcji armor - malejąca skuteczność (jak w większości gier)
func calculate_armor_reduction(armor: float) -> float:
	# Formuła: armor / (armor + 100)
	# Przykłady:
	# 10 armor  = 9.1% redukcji
	# 50 armor  = 33% redukcji
	# 100 armor = 50% redukcji
	# 200 armor = 66.7% redukcji
	return armor / (armor + 100.0)

func heal(amount: float) -> void:
	var stats := get_total_stats()
	current_hp = min(stats["hp"], current_hp + amount)
	hp_changed.emit(current_hp, stats["hp"])

func add_block(amount: float) -> void:
	pending_block += amount

func add_dodge_bonus(amount: float) -> void:
	pending_dodge_bonus += amount
