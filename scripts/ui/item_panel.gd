extends PanelContainer

@onready var stats_box: VBoxContainer = %StatsBox
@onready var level_label: Label = %Label
@onready var exp_bar: ProgressBar = %ExpProgressBar
@onready var hp_bar: ProgressBar = %HpProgressBar
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

# Wolne punkty
@onready var points_label: Label = get_node_or_null("%PointsLabel")

const FONT_SIZE: int = 16

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Podłączamy sygnały z Autoloada PlayerData
	if not PlayerData.stats_changed.is_connected(_on_stats_changed):
		PlayerData.stats_changed.connect(_on_stats_changed)
		PlayerData.exp_changed.connect(_update_exp_bar)
		PlayerData.hp_changed.connect(_update_hp_bar)

	_setup_button(str_button, "STR")
	_setup_button(int_button, "INT")
	_setup_button(dex_button, "DEX")
	_setup_button(con_button, "CON")

	_update_ui()
	_update_exp_bar()
	var totals := PlayerData.get_total_stats()
	_update_hp_bar(PlayerData.current_hp, totals.get("hp", 0))

func _setup_button(btn: Button, attr_name: String) -> void:
	if not btn: return
	
	for connection in btn.pressed.get_connections():
		btn.pressed.disconnect(connection["callable"])
		
	btn.pressed.connect(func(): PlayerData.add_attribute(attr_name))


# ==========================================
# DYNAMICZNE GENEROWANIE UI (PRAWY PANEL)
# ==========================================
# Uwaga: równanie/odejmowanie itemu z ekwipunku dzieje się teraz wewnątrz
# EquipmentSlot._drop_data()/clear() (wywołuje PlayerData.equip_item/unequip_item
# bezpośrednio), więc panel nie musi tego już przekazywać dalej — wystarczy,
# że słucha PlayerData.stats_changed (podłączone w _ready powyżej).

func _on_stats_changed(changed_stat: String) -> void:
	_update_ui(changed_stat)

func _update_ui(changed_stat: String = "") -> void:
	if not stats_box: return

	var totals := PlayerData.get_total_stats()
	var char_info := PlayerData.character_stats

	for child in stats_box.get_children():
		child.queue_free()

	_add_label("%s (Level %d)" % [char_info["name"], char_info["level"]], Color(0.95, 0.75, 0.2), FONT_SIZE, "level")
	_add_spacer()

	# Mapowanie statystyk z PlayerData (Zalecane ujednolicenie nazw z ItemDefinition)
	if totals.has("dmg"): _add_label("Damage: %.2f" % totals["dmg"], Color.WHITE, FONT_SIZE, "dmg")
	if totals.has("magic_dmg"): _add_label("Magic Damage: %.2f" % totals["magic_dmg"], Color.WHITE, FONT_SIZE, "magic_dmg")
	if totals.has("attack_speed"): _add_label("Attack Speed: %.2f /s" % totals["attack_speed"], Color.WHITE, FONT_SIZE, "attack_speed")
	if totals.has("crit_chance"): _add_label("Crit Chance: %d%%" % int(totals["crit_chance"] * 100), Color.WHITE, FONT_SIZE, "crit_chance")
	if totals.has("crit_damage"): _add_label("Crit Damage: %d%%" % int(totals["crit_damage"] * 100), Color.WHITE, FONT_SIZE, "crit_damage")
	if totals.has("armor"): _add_label("Armor: %d" % totals["armor"], Color.WHITE, FONT_SIZE, "armor")

	_add_spacer()

	# Pozostałe statystyki (np. uniki, lifesteal)
	var has_survival := false
	if totals.get("lifesteal", 0) > 0:
		_add_label("Lifesteal: %d%%" % int(totals["lifesteal"] * 100), Color(0.85, 0.3, 0.4), FONT_SIZE, "lifesteal")
		has_survival = true
	if totals.get("dodge", 0) > 0:
		_add_label("Dodge: %d%%" % int(totals["dodge"] * 100), Color(0.6, 0.6, 0.65), FONT_SIZE, "dodge")
		has_survival = true
	if totals.has("hp"):
		_add_label("Max HP: %d" % totals["hp"], Color(0.4, 0.8, 0.4), FONT_SIZE, "hp")
		has_survival = true
	if has_survival: _add_spacer()

	# Efekt graficzny pop-up
	if changed_stat != "":
		var stats_to_pop: Array[String] = [changed_stat]
		if changed_stat == "STR": stats_to_pop = ["dmg", "crit_damage"]
		elif changed_stat == "DEX": stats_to_pop = ["attack_speed", "crit_chance", "dodge"]
		elif changed_stat == "INT": stats_to_pop = ["crit_damage"]
		elif changed_stat == "CON": stats_to_pop = ["hp"]

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

func _update_hp_bar(current_hp: float, max_hp: float) -> void:
	var totals := PlayerData.get_total_stats()
	if totals.has("hp"):
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
	
	var hp_percentage := 0.0
	var hp_bar_stylebox = hp_bar.get_theme_stylebox("fill", "ProgressBar")
	hp_percentage = hp_bar.value / hp_bar.max_value if hp_bar.max_value > 0 else 0.0

	if hp_percentage > 0.5:
		hp_bar_stylebox.bg_color = Color(0.4, 0.8, 0.4) # Zielony
	elif hp_percentage > 0.2:
		hp_bar_stylebox.bg_color = Color(1.0, 0.85, 0.2) # Żółty
	else:
		hp_bar_stylebox.bg_color = Color(0.85, 0.3, 0.4) # Czerwony

func set_avatar(tex: Texture2D) -> void:
	avatar.texture = tex
