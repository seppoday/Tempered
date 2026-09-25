# PlayerData.gd
extends Node

signal stats_changed(changed_stat_key: String)
signal item_equipped(slot_type: EquipmentSlot.Type, item_instance: ItemInstance)
signal exp_changed
signal level_up(new_level: int)
signal gold_changed(new_gold_amount: int)

signal attributes_changed # Na razie nie używane nigdzie

# ==========================================
# POSTAĆ I POSTĘP
# ==========================================
var character_definition : CharacterDefinition
var health: Health

var picks_per_cycle: int = 3

var character_stats: Dictionary = {
	"level": 1,
	"exp": 0,
	"exp_to_next": 100,
}

var gold: int = 0

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
	EquipmentSlot.Type.AMULET: null,
	EquipmentSlot.Type.HELMET: null,
	EquipmentSlot.Type.RING: null,
	EquipmentSlot.Type.WEAPON: null,
	EquipmentSlot.Type.CHEST: null,
	EquipmentSlot.Type.SHIELD: null,
	EquipmentSlot.Type.GLOVES: null,
	EquipmentSlot.Type.LEGS: null,
	EquipmentSlot.Type.BOOTS: null,
	#EquipmentSlot.Type.BACKPACK: null,
}


# DEBUG
const DEBUG_START_GEAR: Array[Dictionary] = [
	# [id, count, level (0-6)]
	{"id": "iron_sword",    "count": 1, "level": 1},
	{"id": "iron_shield",    "count": 1, "level": 1},
	{"id": "silver_amulet",  "count": 1, "level": 1},
	#{"id": "knight_armor",   "count": 1, "level": 1},
	#{"id": "leather_gloves", "count": 1, "level": 6},
	#{"id": "hunter_boots",   "count": 1, "level": 6},
	#{"id": "leather_cap",    "count": 1, "level": 6},
	#{"id": "iron_ring",      "count": 1, "level": 6},
]

func give_debug_gear() -> void:
	for item in DEBUG_START_GEAR:
		var item_definition := ItemDatabase.get_by_id(item.id)

		if item_definition == null:
			Log.warning("give_debug_gear: nie znaleziono przedmiotu o ID: %s" % item.id)
			continue

		var count: int = item.get("count", 1)
		var level: int = item.get("level", 1)

		equip_item(ItemInstance.new(item_definition, count, level))

func _ready() -> void:
	give_debug_gear()
	
	DebugConsole.register_command("heal", _cmd_heal, "heal [ilość] - leczy gracza (bez argumentu: pełne HP)")
	
	character_definition = CharacterDatabase.get_by_id("warrior") # chwilowe, tylko debug
	
	if character_definition == null:
		Log.warning("Nie znaleziono character definition w pliku Player_Data")
		return
		
	attributes["STR"] = character_definition.starting_str
	attributes["DEX"] = character_definition.starting_dex
	attributes["INT"] = character_definition.starting_int
	attributes["CON"] = character_definition.starting_con

	health = Health.new(get_total_stats()["hp"])
	health.died.connect(_on_player_died)

func _cmd_heal(args: Array) -> String:
	var amount: int = int(args[0]) if args.size() > 0 else health.max_hp
	health.heal(amount)
	return "[color=green]Wyleczono do %d/%d HP[/color]" % [health.current, health.max_hp]

# ==========================================
# OBLICZANIE STATYSTYK
# ==========================================
func get_total_stats() -> Dictionary:
	var totals: Dictionary = {
		"dmg": character_definition.base_dmg + (attributes["STR"] * 1.0),
		"magic": character_definition.base_magic + (attributes["INT"] * 1.0),
		"def": character_definition.base_def,
		"vit": character_definition.base_vit + (attributes["CON"] * 5.0),
		"speed": character_definition.base_speed + (attributes["DEX"] * 1.0),
		"luck": character_definition.base_luck,
		"status": character_definition.base_status,
		"crit": character_definition.base_crit,
	}

	for slot_type in equipped_items:
		var item: ItemInstance = equipped_items[slot_type]
		if item == null or item.definition == null:
			continue

		var def: ItemDefinition = item.definition
		for stat in GameEnums.Stat.values():
			var key: String = GameEnums.Stat.keys()[stat].to_lower()
			totals[key] += def.get_stat(stat)

	totals["hp"] = totals["vit"]
	totals["dodge"] = totals["speed"] / (totals["speed"] + 100.0)

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

	var is_crit: bool = RNG.randf() < stats.get("crit_chance", 0.0)
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

# player_data.gd — nowa funkcja, PlayerData jako pośrednik przed Health
func take_damage(raw_amount: int) -> void:
	var stats := get_total_stats()

	var dodge_chance: float = stats.get("dodge", 0.0) + pending_dodge_bonus
	pending_dodge_bonus = 0.0
	if RNG.randf() < dodge_chance:
		Log.print("Dodged Enemy Attack.")
		return

	var mitigated: float = max(0.0, raw_amount - pending_block)
	pending_block = 0.0

	var reduction: float = calculate_armor_reduction(stats.get("def", 0.0))
	var final_amount: int = int(round(mitigated * (1.0 - reduction)))
	
	EventBus.player_damaged.emit(final_amount)
	health.take_damage(final_amount)

# Formuła redukcji armor - malejąca skuteczność (jak w większości gier)
func calculate_armor_reduction(armor: float) -> float:
	# Formuła: armor / (armor + 100)
	# Przykłady:
	# 10 armor  = 9.1% redukcji
	# 50 armor  = 33% redukcji
	# 100 armor = 50% redukcji
	# 200 armor = 66.7% redukcji
	return armor / (armor + 100.0)

func add_block(amount: float) -> void:
	pending_block += amount

func add_dodge_bonus(amount: float) -> void:
	pending_dodge_bonus += amount

func _on_player_died() -> void:
	pass
