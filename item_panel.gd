extends PanelContainer

@onready var stats_box: VBoxContainer = %StatsBox
@onready var level_label: Label = %Label
@onready var exp_bar: ProgressBar = %ProgressBar
@onready var avatar: TextureRect = %TextureRect

@onready var equipment_slots: Dictionary = {
	"weapon": %WeaponSlot, "shield": %ShieldSlot, "helmet": %HelmetSlot,
	"armor": %ArmorSlot, "boots": %BootsSlot, "amulet": %AmuletSlot, "ring": %RingSlot,
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Podłączamy sloty do wywoływania zmian w PlayerData
	for slot_type in equipment_slots:
		equipment_slots[slot_type].equipment_changed.connect(_on_equipment_changed)
	
	# Podłączamy sygnały z Autoloada
	PlayerData.stats_changed.connect(_on_stats_changed)
	PlayerData.exp_changed.connect(_update_exp_bar)
	
	_update_ui()
	_update_exp_bar()

func _on_equipment_changed(slot_type: String, item: Dictionary) -> void:
	# Przekazujemy zmianę do Autoloada
	PlayerData.set_equipped_item(slot_type, item)

func _on_stats_changed(changed_stat: String) -> void:
	_update_ui(changed_stat)

# ==========================================
# DYNAMICZNE GENEROWANIE UI (STATS_BOX)
# ==========================================

func _update_ui(changed_stat: String = "") -> void:
	if not stats_box: return

	var totals := PlayerData.get_total_stats()
	var char_info := PlayerData.character_stats

	# Czyszczenie
	for child in stats_box.get_children():
		child.queue_free()

	# NAGŁÓWEK
	_add_label("%s (Level %d)" % [char_info["name"], char_info["level"]], Color(0.95, 0.75, 0.2), 15, "level")
	_add_spacer()

	# BASE STATS
	if totals.has("base_damage"): _add_label("Damage: %d" % totals["base_damage"], Color.WHITE, 12, "base_damage")
	if totals.has("attack_speed"): _add_label("Attack Speed: %.2f /s" % totals["attack_speed"], Color.WHITE, 12, "attack_speed")
	if totals.has("crit_chance"): _add_label("Crit Chance: %d%%" % int(totals["crit_chance"] * 100), Color.WHITE, 12, "crit_chance")
	if totals.has("crit_multiplier"): _add_label("Crit Multiplier: %.1fx" % totals["crit_multiplier"], Color.WHITE, 12, "crit_multiplier")

	_add_spacer()

	# TARGETING
	var targeting_color := Color(0.5, 0.75, 1.0)
	if totals.has("attack_range"): _add_label("Attack Range: %.1fm" % totals["attack_range"], targeting_color, 11, "attack_range")
	if totals.has("target_count"): _add_label("Targets Hit: %d" % totals["target_count"], targeting_color, 11, "target_count")

	_add_spacer()

	# BEHAVIORS / DoT / CC
	var has_behavior := false
	if totals.get("fire_damage", 0) > 0:
		_add_label("Fire Damage: +%d" % totals["fire_damage"], Color(1.0, 0.4, 0.2), 11, "fire_damage")
		has_behavior = true
	if totals.get("poison_damage", 0) > 0:
		_add_label("Poison: %d dmg / %.1fs" % [totals["poison_damage"], totals.get("poison_duration", 0.0)], Color(0.4, 0.85, 0.3), 11, "poison_damage")
		has_behavior = true
	if totals.get("slow_chance", 0) > 0:
		_add_label("Slow: %d%% chance, -%d%%" % [int(totals["slow_chance"] * 100), int(totals.get("slow_amount", 0.0) * 100)], Color(0.4, 0.7, 0.95), 11, "slow_chance")
		has_behavior = true
	if totals.get("stun_chance", 0) > 0:
		_add_label("Stun Chance: %d%%" % int(totals["stun_chance"] * 100), Color(0.95, 0.85, 0.3), 11, "stun_chance")
		has_behavior = true
	if totals.get("fear_chance", 0) > 0:
		_add_label("Fear Chance: %d%%" % int(totals["fear_chance"] * 100), Color(0.7, 0.4, 0.85), 11, "fear_chance")
		has_behavior = true
	if has_behavior: _add_spacer()

	# SURVIVABILITY
	var has_survival := false
	if totals.get("lifesteal", 0) > 0:
		_add_label("Lifesteal: %d%%" % int(totals["lifesteal"] * 100), Color(0.85, 0.3, 0.4), 11, "lifesteal")
		has_survival = true
	if totals.get("thorns", 0) > 0:
		_add_label("Thorns: %d" % totals["thorns"], Color(0.6, 0.6, 0.65), 11, "thorns")
		has_survival = true
	if totals.get("block_chance", 0) > 0:
		_add_label("Block Chance: %d%%" % int(totals["block_chance"] * 100), Color(0.6, 0.6, 0.65), 11, "block_chance")
		has_survival = true
	if totals.get("armor_pierce", 0) > 0:
		_add_label("Armor Pierce: %d" % totals["armor_pierce"], Color(0.8, 0.5, 1.0), 11, "armor_pierce")
		has_survival = true
	if totals.get("dodge_chance", 0) > 0:
		_add_label("Dodge Chance: %d%%" % int(totals["dodge_chance"] * 100), Color(0.6, 0.6, 0.65), 11, "dodge_chance")
		has_survival = true
	if has_survival: _add_spacer()

	# COMBAT BEHAVIOR
	if totals.get("execute_threshold", 0) > 0:
		_add_label("Execute: <%d%% HP" % int(totals["execute_threshold"] * 100), Color(0.9, 0.25, 0.25), 11, "execute_threshold")
		_add_spacer()

	# ECONOMY
	if totals.get("luck", 0) > 0:
		_add_label("Item Drop Luck: +%d%%" % totals["luck"], Color(0.3, 0.9, 0.4), 11, "luck")

	if changed_stat != "":
		call_deferred("_pop_stat_label", changed_stat)

func _add_label(text_val: String, color: Color, font_size: int = 11, stat_key: String = "") -> Label:
	var lbl = Label.new()
	lbl.text = text_val
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	if stat_key != "": lbl.set_meta("stat_key", stat_key)
	stats_box.add_child(lbl)
	return lbl

func _add_spacer() -> void:
	var space = Control.new()
	space.custom_minimum_size = Vector2(0, 4)
	stats_box.add_child(space)

func _pop_stat_label(stat_key: String) -> void:
	for child in stats_box.get_children():
		if child is Label and child.has_meta("stat_key") and child.get_meta("stat_key") == stat_key:
			_pop_label(child)
			return

func _pop_label(label: Label) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.4, 1.4), 0.12)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(label, "scale", Vector2.ONE, 0.35)

func _update_exp_bar() -> void:
	var info := PlayerData.character_stats
	exp_bar.max_value = info["exp_to_next"]
	exp_bar.value = info["exp"]
	level_label.text = "%s (Level %d)" % [info["name"], info["level"]]

func set_avatar(tex: Texture2D) -> void:
	avatar.texture = tex