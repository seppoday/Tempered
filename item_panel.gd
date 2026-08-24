extends PanelContainer

@onready var stats_box: VBoxContainer = %StatsBox
@onready var level_label: Label = %Label
@onready var exp_bar: ProgressBar = %ProgressBar
@onready var avatar: TextureRect = %TextureRect

# === REFERENCJE DO LEWEGO PANELU ATRYBUTÓW ===
@onready var str_button: Button = %STRButton
@onready var int_button: Button = %INTButton
@onready var dex_button: Button = %DEXButton
@onready var con_button: Button = %CONButton

@onready var str_label: Label = %STRLabel
@onready var int_label: Label = %INTLabel
@onready var dex_label: Label = %DEXLabel
@onready var con_label: Label = %CONLabel

# Jeśli masz Label na wolne punkty (opcjonalnie)
@onready var points_label: Label = get_node_or_null("%PointsLabel")

@onready var equipment_slots: Dictionary = {
	"weapon": %WeaponSlot, "shield": %ShieldSlot, "helmet": %HelmetSlot,
	"armor": %ArmorSlot, "boots": %BootsSlot, "amulet": %AmuletSlot, "ring": %RingSlot,
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	for slot_type in equipment_slots:
		if not equipment_slots[slot_type].equipment_changed.is_connected(_on_equipment_changed):
			equipment_slots[slot_type].equipment_changed.connect(_on_equipment_changed)
	
	# Podłączamy sygnały z Autoloada
	if not PlayerData.stats_changed.is_connected(_on_stats_changed):
		PlayerData.stats_changed.connect(_on_stats_changed)
		PlayerData.exp_changed.connect(_update_exp_bar)
		PlayerData.attributes_changed.connect(_update_attributes_ui)
		PlayerData.attribute_points_changed.connect(_on_attribute_points_changed)

	# BEZPIECZNE PODŁĄCZANIE PRZYCISKÓW (Gwarantuje dokładnie 1 połączenie na przycisk)
	_setup_button(str_button, "STR")
	_setup_button(int_button, "INT")
	_setup_button(dex_button, "DEX")
	_setup_button(con_button, "CON")

	_update_ui()
	_update_exp_bar()
	_update_attributes_ui()
	_on_attribute_points_changed(PlayerData.attribute_points)

# Funkcja czyszcząca stare połączenia przed dodaniem nowego
func _setup_button(btn: Button, attr_name: String) -> void:
	if not btn: return
	
	# 1. Odpinamy WSZYSTKIE stare połączenia z tego przycisku
	for connection in btn.pressed.get_connections():
		btn.pressed.disconnect(connection["callable"])
		
	# 2. Podpinamy dokładnie JEDNO czyste połączenie
	btn.pressed.connect(func(): PlayerData.add_attribute(attr_name))

# ==========================================
# OBSŁUGA ATRYBUTÓW (LEWY PANEL)
# ==========================================
func _update_attributes_ui() -> void:
	if str_label: str_label.text = str(PlayerData.attributes["STR"])
	if int_label: int_label.text = str(PlayerData.attributes["INT"])
	if dex_label: dex_label.text = str(PlayerData.attributes["DEX"])
	if con_label: con_label.text = str(PlayerData.attributes["CON"])

func _on_attribute_points_changed(points: int) -> void:
	var has_points := points > 0
	if str_button: str_button.disabled = not has_points
	if int_button: int_button.disabled = not has_points
	if dex_button: dex_button.disabled = not has_points
	if con_button: con_button.disabled = not has_points

	if points_label:
		points_label.text = "Wolne punkty: %d" % points

# ==========================================
# DYNAMICZNE GENEROWANIE UI (PRAWY PANEL)
# ==========================================
func _on_equipment_changed(slot_type: String, item: Dictionary) -> void:
	PlayerData.set_equipped_item(slot_type, item)

func _on_stats_changed(changed_stat: String) -> void:
	_update_ui(changed_stat)

func _update_ui(changed_stat: String = "") -> void:
	if not stats_box: return

	var totals := PlayerData.get_total_stats()
	var char_info := PlayerData.character_stats

	for child in stats_box.get_children():
		child.queue_free()

	_add_label("%s (Level %d)" % [char_info["name"], char_info["level"]], Color(0.95, 0.75, 0.2), 15, "level")
	_add_spacer()

	if totals.has("base_damage"): _add_label("Damage: %d" % totals["base_damage"], Color.WHITE, 12, "base_damage")
	if totals.has("attack_speed"): _add_label("Attack Speed: %.2f /s" % totals["attack_speed"], Color.WHITE, 12, "attack_speed")
	if totals.has("crit_chance"): _add_label("Crit Chance: %d%%" % int(totals["crit_chance"] * 100), Color.WHITE, 12, "crit_chance")
	if totals.has("crit_multiplier"): _add_label("Crit Multiplier: %.1fx" % totals["crit_multiplier"], Color.WHITE, 12, "crit_multiplier")

	_add_spacer()

	var targeting_color := Color(0.5, 0.75, 1.0)
	if totals.has("attack_range"): _add_label("Attack Range: %.1fm" % totals["attack_range"], targeting_color, 11, "attack_range")
	if totals.has("target_count"): _add_label("Targets Hit: %d" % totals["target_count"], targeting_color, 11, "target_count")

	_add_spacer()

	var has_behavior := false
	if totals.get("fire_damage", 0) > 0:
		_add_label("Fire Damage: +%d" % totals["fire_damage"], Color(1.0, 0.4, 0.2), 11, "fire_damage")
		has_behavior = true
	if totals.get("stun_chance", 0) > 0:
		_add_label("Stun Chance: %d%%" % int(totals["stun_chance"] * 100), Color(0.95, 0.85, 0.3), 11, "stun_chance")
		has_behavior = true
	if has_behavior: _add_spacer()

	var has_survival := false
	if totals.get("lifesteal", 0) > 0:
		_add_label("Lifesteal: %d%%" % int(totals["lifesteal"] * 100), Color(0.85, 0.3, 0.4), 11, "lifesteal")
		has_survival = true
	if totals.get("block_chance", 0) > 0:
		_add_label("Block Chance: %d%%" % int(totals["block_chance"] * 100), Color(0.6, 0.6, 0.65), 11, "block_chance")
		has_survival = true
	if totals.get("dodge_chance", 0) > 0:
		_add_label("Dodge Chance: %d%%" % int(totals["dodge_chance"] * 100), Color(0.6, 0.6, 0.65), 11, "dodge_chance")
		has_survival = true
	if totals.has("max_hp"):
		_add_label("Max HP: %d" % totals["max_hp"], Color(0.4, 0.8, 0.4), 11, "max_hp")
		has_survival = true
	if has_survival: _add_spacer()

	if totals.get("execute_threshold", 0) > 0:
		_add_label("Execute: <%d%% HP" % int(totals["execute_threshold"] * 100), Color(0.9, 0.25, 0.25), 11, "execute_threshold")
		_add_spacer()

	if totals.get("luck", 0) > 0:
		_add_label("Item Drop Luck: +%d%%" % totals["luck"], Color(0.3, 0.9, 0.4), 11, "luck")

	if changed_stat != "":
		var stats_to_pop: Array[String] = [changed_stat]
		if changed_stat == "STR": stats_to_pop = ["base_damage", "crit_multiplier"]
		elif changed_stat == "DEX": stats_to_pop = ["attack_speed", "crit_chance", "dodge_chance"]
		elif changed_stat == "INT": stats_to_pop = ["fire_damage", "crit_multiplier"]
		elif changed_stat == "CON": stats_to_pop = ["max_hp", "block_chance"]

		for stat in stats_to_pop:
			call_deferred("_pop_stat_label", stat)

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

func _pop_label(label: Label) -> void:
	label.pivot_offset = label.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(label, "scale", Vector2.ONE, 0.15)

func _update_exp_bar() -> void:
	var info := PlayerData.character_stats
	exp_bar.max_value = info["exp_to_next"]
	exp_bar.value = info["exp"]
	level_label.text = "%s (Level %d)" % [info["name"], info["level"]]

func set_avatar(tex: Texture2D) -> void:
	avatar.texture = tex