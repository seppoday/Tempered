@tool
extends EditorScript

## Uruchom: File → Run (Ctrl+Shift+X)
## WAŻNE: Uruchom NAJPIERW generate_new_skills.gd (musi istnieć loot.tres itd.)

const SKILLS_PATH := "res://definitions/skills/%s.tres"
const ITEMS_DIR := "res://definitions/items"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ITEMS_DIR)

	_generate_all()
	print("✅ Nowe itemy wygenerowane w ", ITEMS_DIR)


func _generate_all() -> void:
	# ── ZBROJE (CHEST) ──
	_save("iron_plate", _create(
		"iron_plate", "Iron Plate",
		EquipmentSlot.Type.CHEST,
		"fortify",
		{"def": 15.0, "vit": 8.0}
	))

	_save("dragonscale_mail", _create(
		"dragonscale_mail", "Dragonscale Mail",
		EquipmentSlot.Type.CHEST,
		"molten_ward",
		{"def": 8.0, "magic": 6.0, "vit": 4.0},
		[_make_affinity(GameEnums.DamageElement.FIRE, 1.3)]
	))

	# ── BUTY (BOOTS) ──
	_save("hunter_boots_new", _create(
		"hunter_boots_new", "Hunter's Boots",
		EquipmentSlot.Type.BOOTS,
		"swift_strike",
		{"speed": 8.0, "dmg": 3.0}
	))

	_save("boots_of_avarice", _create(
		"boots_of_avarice", "Boots of Avarice",
		EquipmentSlot.Type.BOOTS,
		"loot",
		{"luck": 10.0}
	))

	_save("phoenix_greaves", _create(
		"phoenix_greaves", "Phoenix Greaves",
		EquipmentSlot.Type.BOOTS,
		"rekindle",
		{"vit": 6.0, "magic": 4.0}
	))

	# ── HEŁMY (HELMET) ──
	_save("warhelm", _create(
		"warhelm", "Warhelm",
		EquipmentSlot.Type.HELMET,
		"headbutt",
		{"def": 8.0, "dmg": 5.0}
	))

	_save("mystic_hood", _create(
		"mystic_hood", "Mystic Hood",
		EquipmentSlot.Type.HELMET,
		"arcane_burst",
		{"magic": 10.0, "status": 4.0}
	))

	_save("berserker_horns", _create(
		"berserker_horns", "Berserker's Horns",
		EquipmentSlot.Type.HELMET,
		"rage",
		{"dmg": 6.0, "crit": 8.0}
	))

	# ── RĘKAWICE (GLOVES) ──
	_save("gauntlets_of_precision", _create(
		"gauntlets_of_precision", "Gauntlets of Precision",
		EquipmentSlot.Type.GLOVES,
		"pinpoint",
		{"crit": 12.0, "dmg": 3.0}
	))

	_save("thiefs_gloves", _create(
		"thiefs_gloves", "Thief's Gloves",
		EquipmentSlot.Type.GLOVES,
		"pickpocket",
		{"speed": 5.0, "luck": 8.0}
	))

	# ── PIERŚCIENIE (RING) ──
	_save("ring_of_rupture", _create(
		"ring_of_rupture", "Ring of Rupture",
		EquipmentSlot.Type.RING,
		"bleeding_cut",
		{"dmg": 8.0}
	))

	_save("debuffers_ring", _create(
		"debuffers_ring", "Debuffer's Ring",
		EquipmentSlot.Type.RING,
		"rust",
		{"magic": 6.0, "status": 6.0}
	))


# ── FUNKCJE POMOCNICZE ──

func _create(
	id_key: String,
	item_name: String,
	slot_type: EquipmentSlot.Type,
	skill_id: String,
	stats: Dictionary,
	affinities: Array = []
) -> ItemDefinition:
	var item := ItemDefinition.new()

	if "id" in item: item.id = id_key
	if "name" in item: item.name = item_name
	if "item_name" in item: item.item_name = item_name
	if "stackable" in item: item.stackable = false
	if "max_stack_size" in item: item.max_stack_size = 1

	item.slot = slot_type

	var skill_path := SKILLS_PATH % skill_id
	if ResourceLoader.exists(skill_path):
		item.default_skill = load(skill_path) as SkillDefinition
	else:
		push_warning("Nie znaleziono skilla: %s dla przedmiotu %s" % [skill_path, item_name])

	item.dmg = float(stats.get("dmg", 0.0))
	item.magic = float(stats.get("magic", 0.0))
	item.def = float(stats.get("def", 0.0))
	item.vit = float(stats.get("vit", 0.0))
	item.speed = float(stats.get("speed", 0.0))
	item.luck = float(stats.get("luck", 0.0))
	item.status = float(stats.get("status", 0.0))
	item.crit = float(stats.get("crit", 0.0))

	var typed_affinities: Array[ItemAffinity] = []
	for aff in affinities:
		typed_affinities.append(aff as ItemAffinity)
	item.affinities = typed_affinities

	return item


func _make_affinity(element: GameEnums.DamageElement, multiplier: float) -> ItemAffinity:
	var aff := ItemAffinity.new()
	aff.element = element
	aff.multiplier = multiplier
	return aff


func _save(filename: String, resource: ItemDefinition) -> void:
	var path := "%s/%s.tres" % [ITEMS_DIR, filename]
	var err := ResourceSaver.save(resource, path)
	if err == OK:
		print("  ✔ %s" % path)
	else:
		push_error("  ✘ Błąd zapisu %s: %d" % [path, err])
