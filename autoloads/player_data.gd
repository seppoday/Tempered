extends Node
# Autoload: PlayerData

signal stats_changed(changed_stat_key: String)
signal item_equipped(slot_type: EquipmentSlot.Type, item_instance: ItemInstance)
signal shield_changed(current_shield: int, max_hp: int)
signal player_dodged

signal attributes_changed

var picks_per_cycle: int = 2

## Kara do liczby wybieranych kości przy NASTĘPNYM rzucie (np. ze skilla "duży dmg, mniej kart").
## Ustawiana przez triggery (REDUCE_NEXT_PICKS), zużywana i zerowana przy starcie kolejnego rzutu.
var pending_picks_penalty: int = 0

var health: Health
var max_shield: float
var pending_block: float = 0.0
var pending_dodge_bonus: float = 0.0

var status_manager: StatusManager = StatusManager.new()


var totals: Dictionary = {
	"dmg": 1,
	"magic": 1,
	"def": 1,
	"vit": 1,
	"luck": 1,
	"status": 1,
	"crit": 1,
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
}

const BASE_DMG: float = 0.0
const BASE_MAGIC: float = 0.0
const BASE_DEF: float = 0.0
const BASE_VIT: float = 5.0
const BASE_LUCK: float = 0.0
const BASE_STATUS: float = 0.0
const BASE_CRIT: float = 0.0



func _ready() -> void:
	equip_starting_loadout()
	
	DebugConsole.register_command("heal", _cmd_heal, "heal [ilość] - leczy gracza (bez argumentu: pełne HP)")
	DebugConsole.register_command("die", _cmd_die, "die - zabija gracza)")

	health = Health.new(get_total_stats()["hp"])
	health.died.connect(_on_player_died)
	max_shield = calculate_max_shield()

func _cmd_heal(args: Array) -> String:
	var amount: int = int(args[0]) if args.size() > 0 else health.max_hp
	health.heal(amount)
	return "[color=green]Wyleczono do %d/%d HP[/color]" % [health.current, health.max_hp]

func _cmd_die(args: Array) -> String:
	health.take_damage(999999)
	return "[color=green]Gracz umarł"

func equip_starting_loadout() -> void:
	var starting_ids: Array[String] = MetaProgressionManager.get_starting_loadout()

	for item_id in starting_ids:
		var item_definition := ItemDatabase.get_by_id(item_id)

		if item_definition == null:
			Log.warning("equip_starting_loadout: nie znaleziono przedmiotu o ID: %s" % item_id)
			continue

		# Domyślnie zakładamy 1 sztukę o poziomie 1
		var item_instance := ItemInstance.new(item_definition, 1, 0)
		equip_item(item_instance)

## Zwraca ile kości gracz może wybrać w NADCHODZĄCYM rzucie i zeruje karę — wołać raz na rzut.
func consume_picks_limit() -> int:
	var limit: int = max(1, picks_per_cycle - pending_picks_penalty)
	pending_picks_penalty = 0
	return limit

func get_total_stats() -> Dictionary:
	var totals: Dictionary = {
		"dmg": BASE_DMG,
		"magic": BASE_MAGIC,
		"def": BASE_DEF,
		"vit": BASE_VIT,
		"luck": BASE_LUCK,
		"status": BASE_STATUS,
		"crit": BASE_CRIT,
	}
	
	for slot_type in equipped_items:
		var item: ItemInstance = equipped_items[slot_type]
		if item == null or item.definition == null:
			continue

		var def: ItemDefinition = item.definition
		for stat in GameEnums.Stat.values():
			var key: String = GameEnums.Stat.keys()[stat].to_lower()
			totals[key] += def.get_stat(stat)

	totals["hp"] = totals["vit"] * 10
	totals["dodge"] = totals["luck"] / (totals["luck"] + 100.0)

	return totals

func get_equipped_item(slot_type: EquipmentSlot.Type) -> ItemInstance:
	return equipped_items.get(slot_type, null)

func full_heal() -> void:
	health.heal(health.max_hp)

func equip_item(item_instance: ItemInstance) -> ItemInstance:
	if item_instance == null or item_instance.definition == null:
		return null
	
	var slot_type: EquipmentSlot.Type = item_instance.definition.slot
	var previous: ItemInstance = equipped_items.get(slot_type)
	equipped_items[slot_type] = item_instance
	
	stats_changed.emit(EquipmentSlot.Type.keys()[slot_type])
	item_equipped.emit(slot_type, item_instance)
	add_block(0)
	return previous

func unequip_item(slot_type: EquipmentSlot.Type) -> ItemInstance:
	var previous: ItemInstance = equipped_items.get(slot_type)
	equipped_items[slot_type] = null
	
	stats_changed.emit(EquipmentSlot.Type.keys()[slot_type])
	item_equipped.emit(slot_type, null)
	add_block(0)
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

func take_damage(raw_amount: int) -> void:
	var stats := get_total_stats()

	# 1. Unik (Dodge)
	var dodge_chance: float = stats.get("dodge", 0.0) + pending_dodge_bonus
	pending_dodge_bonus = 0.0
	if RNG.randf() < dodge_chance:
		player_dodged.emit()
		Log.print("Dodged Enemy Attack.")
		return

	# 2. Obliczamy ile tarczy pochłonie obrażenia
	var shield_absorbed: float = min(pending_block, float(raw_amount))
	pending_block -= shield_absorbed
	
	var shield_damage_taken: int = int(shield_absorbed)
	var mitigated: float = float(raw_amount) - shield_absorbed

	shield_changed.emit(int(pending_block), max_shield)

	var hp_damage_taken: int = 0

	# 3. Jeśli coś przebiło tarczę, nakładamy pancerz i ranimy gracza
	if mitigated > 0:
		var reduction: float = calculate_armor_reduction(stats.get("def", 0.0))
		hp_damage_taken = int(round(mitigated * (1.0 - reduction)))
		
		if hp_damage_taken <= 0:
			hp_damage_taken = 1
		
		health.take_damage(hp_damage_taken)
	
	# 4. Sygnał do UI
	EventBus.player_damaged.emit(hp_damage_taken, shield_damage_taken)

func calculate_armor_reduction(armor: float) -> float:
	return armor / (armor + 100.0)

func add_block(amount: float) -> void:
	max_shield = calculate_max_shield()
	pending_block = min(pending_block + amount, max_shield)
	shield_changed.emit(int(pending_block), max_shield)

func calculate_max_shield() -> float:
	var stats := get_total_stats()
	return 20.0 + (stats.get("def", 0.0) * 2.0) 

func clear_block() -> void:
	pending_block = 0.0
	shield_changed.emit(0, max_shield)

func add_dodge_bonus(amount: float) -> void:
	pending_dodge_bonus += amount

func _on_player_died() -> void:
	pass

func reset_for_new_run() -> void:
	# 1. Reset tarczy
	pending_block = 0.0
	status_manager.clear_all()
	pending_dodge_bonus = 0.0

	# 2. Czyszczenie ekwipunku
	for slot_type in equipped_items.keys():
		equipped_items[slot_type] = null
		stats_changed.emit(EquipmentSlot.Type.keys()[slot_type])
		item_equipped.emit(slot_type, null)

	# 3. Rozdanie ekwipunku startowego z Meta Progression
	equip_starting_loadout()

	# 4. Przeliczenie tarczy
	max_shield = calculate_max_shield()
	shield_changed.emit(int(pending_block), max_shield)

	# 5. Reset HP
	var starting_hp: int = get_total_stats()["hp"]
	health.max_hp = starting_hp
	health.current = starting_hp
	if health.has_method("heal"):
		health.heal(0)

	Log.print("PlayerData: Zresetowano run. HP zresetowane do: %d/%d" % [health.current, health.max_hp])
