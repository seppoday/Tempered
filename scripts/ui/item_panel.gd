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

# Wolne punkty
@onready var points_label: Label = get_node_or_null("%PointsLabel")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Podłączamy sygnały z Autoloada PlayerData
	if not PlayerData.stats_changed.is_connected(_on_stats_changed):
		PlayerData.stats_changed.connect(_on_stats_changed)
		PlayerData.exp_changed.connect(_update_exp_bar)
		PlayerData.attributes_changed.connect(_update_attributes_ui)
		PlayerData.attribute_points_changed.connect(_on_attribute_points_changed)

	_setup_button(str_button, "STR")
	_setup_button(int_button, "INT")
	_setup_button(dex_button, "DEX")
	_setup_button(con_button, "CON")

	_update_ui()
	_update_exp_bar()
	_update_attributes_ui()
	_on_attribute_points_changed(PlayerData.attribute_points)

func _setup_button(btn: Button, attr_name: String) -> void:
	if not btn: return
	
	for connection in btn.pressed.get_connections():
		btn.pressed.disconnect(connection["callable"])
		
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

	_add_label("%s (Level %d)" % [char_info["name"], char_info["level"]], Color(0.95, 0.75, 0.2), 15, "level")
	_add_spacer()

	# Mapowanie statystyk z PlayerData (Zalecane ujednolicenie nazw z ItemDefinition)
	if totals.has("dmg"): _add_label("Damage: %d" % totals["dmg"], Color.WHITE, 12, "dmg")
	if totals.has("magic_dmg"): _add_label("Magic Damage: %d" % totals["magic_dmg"], Color.WHITE, 12, "magic_dmg")
	if totals.has("attack_speed"): _add_label("Attack Speed: %.2f /s" % totals["attack_speed"], Color.WHITE, 12, "attack_speed")
	if totals.has("crit_chance"): _add_label("Crit Chance: %d%%" % int(totals["crit_chance"] * 100), Color.WHITE, 12, "crit_chance")
	if totals.has("crit_damage"): _add_label("Crit Damage: %d%%" % int(totals["crit_damage"] * 100), Color.WHITE, 12, "crit_damage")
	if totals.has("armor"): _add_label("Armor: %d" % totals["armor"], Color.WHITE, 12, "armor")

	_add_spacer()

	# Pozostałe statystyki (np. uniki, lifesteal)
	var has_survival := false
	if totals.get("lifesteal", 0) > 0:
		_add_label("Lifesteal: %d%%" % int(totals["lifesteal"] * 100), Color(0.85, 0.3, 0.4), 11, "lifesteal")
		has_survival = true
	if totals.get("dodge", 0) > 0:
		_add_label("Dodge: %d%%" % int(totals["dodge"] * 100), Color(0.6, 0.6, 0.65), 11, "dodge")
		has_survival = true
	if totals.has("hp"):
		_add_label("Max HP: %d" % totals["hp"], Color(0.4, 0.8, 0.4), 11, "hp")
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

func set_avatar(tex: Texture2D) -> void:
	avatar.texture = tex
