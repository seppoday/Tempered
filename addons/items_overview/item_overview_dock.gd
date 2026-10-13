@tool
extends Control

var skills_tree: Tree
var items_tree: Tree
var tabs: TabContainer

const ICON_MAX_WIDTH := 20

# --- SKILLS column indices ---
const SCOL_CHECK := 0
const SCOL_WARN := 1
const SCOL_ID := 2
const SCOL_NAME := 3
const SCOL_EFFECT := 4
const SCOL_TARGET := 5
const SCOL_ELEMENT := 6
const SCOL_SYNERGY := 7
const SCOL_DURATION := 8
const SCOL_SCALINGS := 9
const SCOL_BONUS := 10
const SCOL_DESC := 11

# --- ITEMS column indices ---
const ICOL_CHECK := 0
const ICOL_WARN := 1
const ICOL_ID := 2
const ICOL_NAME := 3
const ICOL_SLOT := 4
const ICOL_RARITY := 5
const ICOL_SKILL := 6
const ICOL_DMG := 7
const ICOL_MAGIC := 8
const ICOL_DEF := 9
const ICOL_VIT := 10
const ICOL_LUCK := 11
const ICOL_STATUS := 12
const ICOL_CRIT := 13
const ICOL_PRICE := 14
const ICOL_AFFINITIES := 15

var skills_rows: Array[Dictionary] = []
var items_rows: Array[Dictionary] = []

var skills_titles := PackedStringArray()
var items_titles := PackedStringArray()

var skills_sort_col: int = -1
var skills_sort_asc: bool = true
var items_sort_col: int = -1
var items_sort_asc: bool = true

var _current_filter: String = ""

# --- filtry per kolumna ---
var _skill_filter_effect: int = -1
var _skill_filter_element: int = -1
var _item_filter_rarity: int = -1
var _item_filter_slot: int = -1

# --- dashboard ---
var skills_stats_label: Label
var items_stats_label: Label

# --- multi-select ---
var _selected_skill_paths: Array[String] = []
var _selected_item_paths: Array[String] = []

var effect_filter_btn: OptionButton
var element_filter_btn: OptionButton
var rarity_filter_btn: OptionButton
var slot_filter_btn: OptionButton


func _init() -> void:
	name = "Item & Skill Overview"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# ====== TOOLBAR ======
	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)

	var refresh_button := Button.new()
	refresh_button.text = "⟳ Odśwież"
	refresh_button.pressed.connect(_scan_and_populate)
	toolbar.add_child(refresh_button)

	var export_button := Button.new()
	export_button.text = "📄 CSV"
	export_button.pressed.connect(_export_csv)
	toolbar.add_child(export_button)

	var bulk_sep := VSeparator.new()
	toolbar.add_child(bulk_sep)

	var bulk_delete_btn := Button.new()
	bulk_delete_btn.text = "🗑 Usuń zaznaczone"
	bulk_delete_btn.pressed.connect(_bulk_delete)
	toolbar.add_child(bulk_delete_btn)

	var bulk_rarity_btn := Button.new()
	bulk_rarity_btn.text = "✦ Zmień rarity"
	bulk_rarity_btn.pressed.connect(_bulk_change_rarity)
	toolbar.add_child(bulk_rarity_btn)

	var sep := VSeparator.new()
	toolbar.add_child(sep)

	var filter_label := Label.new()
	filter_label.text = "Szukaj:"
	toolbar.add_child(filter_label)

	var filter_box := LineEdit.new()
	filter_box.placeholder_text = "ID lub nazwa..."
	filter_box.custom_minimum_size = Vector2(180, 0)
	filter_box.text_changed.connect(_on_filter_changed)
	toolbar.add_child(filter_box)

	# ====== FILTER ROW ======
	var filter_row := HBoxContainer.new()
	vbox.add_child(filter_row)

	var fr_label := Label.new()
	fr_label.text = "Filtry:"
	filter_row.add_child(fr_label)

	effect_filter_btn = _make_enum_filter("Effect", GameEnums.SkillEffect.keys())
	effect_filter_btn.item_selected.connect(func(idx): _skill_filter_effect = idx - 1; _reapply_all_filters())
	filter_row.add_child(effect_filter_btn)

	element_filter_btn = _make_enum_filter("Element", GameEnums.DamageElement.keys())
	element_filter_btn.item_selected.connect(func(idx): _skill_filter_element = idx - 1; _reapply_all_filters())
	filter_row.add_child(element_filter_btn)

	rarity_filter_btn = _make_enum_filter("Rarity", GameEnums.Rarity.keys())
	rarity_filter_btn.item_selected.connect(func(idx): _item_filter_rarity = idx - 1; _reapply_all_filters())
	filter_row.add_child(rarity_filter_btn)

	slot_filter_btn = _make_enum_filter("Slot", EquipmentSlot.Type.keys())
	slot_filter_btn.item_selected.connect(func(idx): _item_filter_slot = idx - 1; _reapply_all_filters())
	filter_row.add_child(slot_filter_btn)

	var clear_filters_btn := Button.new()
	clear_filters_btn.text = "✕ Reset filtrów"
	clear_filters_btn.pressed.connect(_reset_all_filters)
	filter_row.add_child(clear_filters_btn)

	# ====== DASHBOARD ======
	var dashboard := HBoxContainer.new()
	dashboard.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(dashboard)

	skills_stats_label = Label.new()
	skills_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_stats_label.modulate = Color(1, 1, 1, 0.7)
	dashboard.add_child(skills_stats_label)

	items_stats_label = Label.new()
	items_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_stats_label.modulate = Color(1, 1, 1, 0.7)
	dashboard.add_child(items_stats_label)

	# ====== TABS ======
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(_on_tab_changed)
	vbox.add_child(tabs)

	skills_titles = PackedStringArray([
		"☑", "⚠", "ID", "Name", "Effect", "Target", "Element",
		"Synergy", "Duration", "Scalings", "Bonus Hits", "Description",
	])
	skills_tree = _build_tree(skills_titles)
	skills_tree.item_activated.connect(_on_skill_activated)
	skills_tree.column_title_clicked.connect(_on_skills_title_clicked)
	skills_tree.item_selected.connect(func(): _on_tree_selection(skills_tree, true))
	skills_tree.set_column_expand(SCOL_CHECK, false)
	skills_tree.set_column_custom_minimum_width(SCOL_CHECK, 32)
	skills_tree.set_column_expand(SCOL_WARN, false)
	skills_tree.set_column_custom_minimum_width(SCOL_WARN, 28)
	skills_tree.select_mode = Tree.SELECT_MULTI
	skills_tree.name = "Skills"
	tabs.add_child(skills_tree)

	items_titles = PackedStringArray([
		"☑", "⚠", "ID", "Name", "Slot", "Rarity", "Default Skill",
		"DMG", "MAGIC", "DEF", "VIT", "LUCK", "STATUS", "CRIT", "Price", "Affinities",
	])
	items_tree = _build_tree(items_titles)
	items_tree.item_activated.connect(_on_item_activated)
	items_tree.column_title_clicked.connect(_on_items_title_clicked)
	items_tree.item_selected.connect(func(): _on_tree_selection(items_tree, false))
	items_tree.set_column_expand(ICOL_CHECK, false)
	items_tree.set_column_custom_minimum_width(ICOL_CHECK, 32)
	items_tree.set_column_expand(ICOL_WARN, false)
	items_tree.set_column_custom_minimum_width(ICOL_WARN, 28)
	items_tree.select_mode = Tree.SELECT_MULTI
	items_tree.name = "Items"
	tabs.add_child(items_tree)


func _make_enum_filter(label_text: String, keys: Array) -> OptionButton:
	var btn := OptionButton.new()
	btn.add_item("— %s —" % label_text)
	for k in keys:
		btn.add_item(str(k))
	btn.custom_minimum_size = Vector2(120, 0)
	return btn


func _build_tree(column_titles: PackedStringArray) -> Tree:
	var tree := Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.columns = column_titles.size()
	tree.column_titles_visible = true
	for i in column_titles.size():
		tree.set_column_title(i, column_titles[i])
	return tree


func _ready() -> void:
	_scan_and_populate()


func _on_tab_changed(_tab: int) -> void:
	pass


func _scan_and_populate() -> void:
	var paths := _find_tres_files("res://")
	paths.sort()
	var used_skill_paths := _collect_used_skill_paths(paths)
	_populate_skills(paths, used_skill_paths)
	_populate_items(paths)
	_update_dashboard()
	_reapply_all_filters()


func _collect_used_skill_paths(paths: Array[String]) -> Dictionary:
	var used: Dictionary = {}
	for path in paths:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if not res is ItemDefinition:
			continue
		var def := res as ItemDefinition
		if def.default_skill != null and def.default_skill.resource_path != "":
			used[def.default_skill.resource_path] = true
	return used


# ---------------------------------------------------------------------------
# DASHBOARD
# ---------------------------------------------------------------------------

func _update_dashboard() -> void:
	var total_skills := skills_rows.size()
	var warned_skills := 0
	var effects_count := {}
	for row in skills_rows:
		if not row["warnings"].is_empty():
			warned_skills += 1
		var eff: String = str(row["cols"][SCOL_EFFECT])
		effects_count[eff] = effects_count.get(eff, 0) + 1

	var skill_parts: Array[String] = ["Skills: %d" % total_skills]
	if warned_skills > 0:
		skill_parts.append("⚠ %d" % warned_skills)
	for eff_name in effects_count:
		skill_parts.append("%s: %d" % [eff_name, effects_count[eff_name]])
	skills_stats_label.text = "  |  ".join(skill_parts)

	var total_items := items_rows.size()
	var warned_items := 0
	var rarity_count := {}
	for row in items_rows:
		if not row["warnings"].is_empty():
			warned_items += 1
		var rar: String = str(row["cols"][ICOL_RARITY])
		rarity_count[rar] = rarity_count.get(rar, 0) + 1

	var item_parts: Array[String] = ["Items: %d" % total_items]
	if warned_items > 0:
		item_parts.append("⚠ %d" % warned_items)
	for rar_name in rarity_count:
		item_parts.append("%s: %d" % [rar_name, rarity_count[rar_name]])
	items_stats_label.text = "  |  ".join(item_parts)


# ---------------------------------------------------------------------------
# SKILLS
# ---------------------------------------------------------------------------

func _populate_skills(paths: Array[String], used_skill_paths: Dictionary) -> void:
	skills_rows.clear()

	for path in paths:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if not res is SkillDefinition:
			continue
		var skill := res as SkillDefinition

		var warnings := _validate_skill(skill, path, used_skill_paths)
		var desc_oneline := skill.description.replace("\n", " ") if skill.description != "" else "—"
		var bonus_hits := skill.bonus_hits_per_stat

		var synergy_text := "%.1f" % skill.element_synergy_bonus if skill.element_synergy_bonus != 0.0 else "—"
		var duration_text := str(skill.duration_rounds) if skill.duration_rounds > 0 else "—"

		var row := {
			"path": path,
			"warnings": warnings,
			"bg": _get_effect_color(skill.effect_type),
			"icon": skill.icon,
			"desc_tooltip": skill.description if skill.description != "" else "(brak opisu)",
			"effect_idx": skill.effect_type if skill.effect_type != null else -1,
			"element_idx": skill.damage_element if skill.damage_element != null else -1,
			"cols": [
				"",  # checkbox
				"⚠" if not warnings.is_empty() else "",
				skill.id if skill.id != "" else "(brak id)",
				skill.skill_name if skill.skill_name != "" else "(brak nazwy)",
				_enum_name(GameEnums.SkillEffect.keys(), skill.effect_type),
				_enum_name(GameEnums.SkillTarget.keys(), skill.target_type),
				_enum_name(GameEnums.DamageElement.keys(), skill.damage_element),
				synergy_text,
				duration_text,
				_format_scalings(skill.scalings),
				_format_bonus_hits(bonus_hits),
				desc_oneline,
			],
			"sort": [
				0,
				1 if not warnings.is_empty() else 0,
				skill.id,
				skill.skill_name,
				_enum_sort(skill.effect_type),
				_enum_sort(skill.target_type),
				_enum_sort(skill.damage_element),
				skill.element_synergy_bonus,
				skill.duration_rounds,
				skill.scalings.size(),
				bonus_hits.weight if bonus_hits != null else -1.0,
				skill.description,
			],
		}
		skills_rows.append(row)

	if skills_sort_col >= 0:
		_sort_rows(skills_rows, skills_sort_col, skills_sort_asc)
	_render_skills()


func _render_skills() -> void:
	skills_tree.clear()
	var root := skills_tree.create_item()

	for row in skills_rows:
		var item := skills_tree.create_item(root)
		var cols: Array = row["cols"]
		for c in range(1, cols.size()):
			item.set_text(c, str(cols[c]))

		item.set_cell_mode(SCOL_CHECK, TreeItem.CELL_MODE_CHECK)
		item.set_editable(SCOL_CHECK, true)
		item.set_checked(SCOL_CHECK, row["path"] in _selected_skill_paths)

		var warnings: Array = row["warnings"]
		if not warnings.is_empty():
			item.set_tooltip_text(SCOL_WARN, "\n".join(warnings))
			item.set_custom_color(SCOL_WARN, Color(1.0, 0.4, 0.3))

		var icon_tex: Texture2D = row.get("icon")
		if icon_tex != null:
			item.set_icon(SCOL_ID, icon_tex)
			item.set_icon_max_width(SCOL_ID, ICON_MAX_WIDTH)

		item.set_tooltip_text(SCOL_DESC, row["desc_tooltip"])
		item.set_metadata(SCOL_WARN, row["path"])

		_apply_effect_tag(item, SCOL_EFFECT, row["effect_idx"])
		_apply_element_tag(item, SCOL_ELEMENT, row["element_idx"])

		var bg_color: Color = row["bg"]
		for col in range(2, skills_tree.columns):
			item.set_custom_bg_color(col, bg_color)

	_update_title_indicators(skills_tree, skills_titles, skills_sort_col, skills_sort_asc)


# ---------------------------------------------------------------------------
# ITEMS
# ---------------------------------------------------------------------------

func _populate_items(paths: Array[String]) -> void:
	items_rows.clear()

	for path in paths:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if not res is ItemDefinition:
			continue
		var def := res as ItemDefinition

		var warnings := _validate_item(def)

		var bg_color := GameEnums.get_rarity_color(def.rarity)
		bg_color.a = 0.15

		var default_skill_name := def.default_skill.skill_name if def.default_skill != null else "—"
		var default_skill_path := def.default_skill.resource_path if def.default_skill != null else ""
		var default_skill_icon: Texture2D = def.default_skill.icon if def.default_skill != null else null

		var row := {
			"path": path,
			"warnings": warnings,
			"bg": bg_color,
			"icon": def.icon,
			"default_skill_path": default_skill_path,
			"default_skill_icon": default_skill_icon,
			"rarity_idx": def.rarity if def.rarity != null else -1,
			"slot_idx": def.slot if def.slot != null else -1,
			"cols": [
				"",
				"⚠" if not warnings.is_empty() else "",
				def.id if def.id != "" else "(brak id)",
				def.name if def.name != "" else "(brak nazwy)",
				_enum_name(EquipmentSlot.Type.keys(), def.slot),
				_enum_name(GameEnums.Rarity.keys(), def.rarity),
				default_skill_name,
				"%.1f" % def.dmg,
				"%.1f" % def.magic,
				"%.1f" % def.def,
				"%.1f" % def.vit,
				"%.1f" % def.luck,
				"%.1f" % def.status,
				"%.1f" % def.crit,
				str(def.price),
				_format_affinities(def.affinities),
			],
			"sort": [
				0,
				1 if not warnings.is_empty() else 0,
				def.id,
				def.name,
				_enum_sort(def.slot),
				_enum_sort(def.rarity),
				default_skill_name,
				def.dmg,
				def.magic,
				def.def,
				def.vit,
				def.luck,
				def.status,
				def.crit,
				def.price,
				def.affinities.size(),
			],
		}
		items_rows.append(row)

	if items_sort_col >= 0:
		_sort_rows(items_rows, items_sort_col, items_sort_asc)
	_render_items()


func _render_items() -> void:
	items_tree.clear()
	var root := items_tree.create_item()

	for row in items_rows:
		var item := items_tree.create_item(root)
		var cols: Array = row["cols"]
		for c in range(1, cols.size()):
			item.set_text(c, str(cols[c]))

		item.set_cell_mode(ICOL_CHECK, TreeItem.CELL_MODE_CHECK)
		item.set_editable(ICOL_CHECK, true)
		item.set_checked(ICOL_CHECK, row["path"] in _selected_item_paths)

		var warnings: Array = row["warnings"]
		if not warnings.is_empty():
			item.set_tooltip_text(ICOL_WARN, "\n".join(warnings))
			item.set_custom_color(ICOL_WARN, Color(1.0, 0.4, 0.3))

		var icon_tex: Texture2D = row.get("icon")
		if icon_tex != null:
			item.set_icon(ICOL_ID, icon_tex)
			item.set_icon_max_width(ICOL_ID, ICON_MAX_WIDTH)

		var skill_icon: Texture2D = row.get("default_skill_icon")
		if skill_icon != null:
			item.set_icon(ICOL_SKILL, skill_icon)
			item.set_icon_max_width(ICOL_SKILL, ICON_MAX_WIDTH)

		item.set_metadata(ICOL_WARN, row["path"])
		if row["default_skill_path"] != "":
			item.set_metadata(ICOL_SKILL, row["default_skill_path"])

		_apply_rarity_tag(item, ICOL_RARITY, row["rarity_idx"])

		var bg_color: Color = row["bg"]
		for col in range(2, items_tree.columns):
			item.set_custom_bg_color(col, bg_color)

	_update_title_indicators(items_tree, items_titles, items_sort_col, items_sort_asc)


# ---------------------------------------------------------------------------
# KOLOROWE TAGI
# ---------------------------------------------------------------------------

func _apply_effect_tag(item: TreeItem, col: int, effect_type) -> void:
	if effect_type == null or typeof(effect_type) != TYPE_INT or effect_type < 0:
		return
	var color := _get_effect_color(effect_type)
	color.a = 0.6
	item.set_custom_color(col, color.lightened(0.5))

func _apply_element_tag(item: TreeItem, col: int, element) -> void:
	if element == null or typeof(element) != TYPE_INT or element < 0:
		return
	var colors := {
		GameEnums.DamageElement.NONE: Color(0.6, 0.6, 0.6),
		GameEnums.DamageElement.PHYSICAL: Color(0.85, 0.75, 0.6),
		GameEnums.DamageElement.FIRE: Color(0.9, 0.3, 0.2),
		GameEnums.DamageElement.ICE: Color(0.3, 0.6, 0.9),
		GameEnums.DamageElement.POISON: Color(0.5, 0.8, 0.3),
	}
	if element in colors:
		item.set_custom_color(col, colors[element])

func _apply_rarity_tag(item: TreeItem, col: int, rarity) -> void:
	if rarity == null or typeof(rarity) != TYPE_INT or rarity < 0:
		return
	var color := GameEnums.get_rarity_color(rarity)
	item.set_custom_color(col, color)


# ---------------------------------------------------------------------------
# MULTI-SELECT + AKCJE MASOWE
# ---------------------------------------------------------------------------

func _on_tree_selection(tree: Tree, is_skills: bool) -> void:
	var selected_paths: Array[String] = []
	var root := tree.get_root()
	if root == null:
		return
	var child := root.get_first_child()
	var check_col := SCOL_CHECK if is_skills else ICOL_CHECK
	var meta_col := SCOL_WARN if is_skills else ICOL_WARN
	while child != null:
		if child.is_checked(check_col):
			var p = child.get_metadata(meta_col)
			if p != null:
				selected_paths.append(p)
		child = child.get_next()

	if is_skills:
		_selected_skill_paths = selected_paths
	else:
		_selected_item_paths = selected_paths


func _get_checked_paths(tree: Tree, check_col: int, meta_col: int) -> Array[String]:
	var paths: Array[String] = []
	var root := tree.get_root()
	if root == null:
		return paths
	var child := root.get_first_child()
	while child != null:
		if child.is_checked(check_col):
			var p = child.get_metadata(meta_col)
			if p != null:
				paths.append(str(p))
		child = child.get_next()
	return paths


func _bulk_delete() -> void:
	var paths: Array[String] = []
	if tabs.current_tab == 0:
		paths = _get_checked_paths(skills_tree, SCOL_CHECK, SCOL_WARN)
	else:
		paths = _get_checked_paths(items_tree, ICOL_CHECK, ICOL_WARN)

	if paths.is_empty():
		print("Item & Skill Overview: nic nie zaznaczono")
		return

	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Usunąć %d zasobów?\n\n%s" % [paths.size(), "\n".join(paths)]
	dialog.confirmed.connect(func():
		for p in paths:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
				if FileAccess.file_exists(p + ".import"):
					DirAccess.remove_absolute(p + ".import")
		_selected_skill_paths.clear()
		_selected_item_paths.clear()
		print("Item & Skill Overview: usunięto %d plików" % paths.size())
		_scan_and_populate()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _bulk_change_rarity() -> void:
	if tabs.current_tab != 1:
		print("Item & Skill Overview: zmiana rarity działa tylko na zakładce Items")
		return

	var paths := _get_checked_paths(items_tree, ICOL_CHECK, ICOL_WARN)
	if paths.is_empty():
		print("Item & Skill Overview: nic nie zaznaczono")
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Zmień Rarity"

	var vb := VBoxContainer.new()
	dialog.add_child(vb)

	var label := Label.new()
	label.text = "Nowy rarity dla %d itemów:" % paths.size()
	vb.add_child(label)

	var option := OptionButton.new()
	for k in GameEnums.Rarity.keys():
		option.add_item(str(k))
	vb.add_child(option)

	dialog.confirmed.connect(func():
		var new_rarity: int = option.selected
		for p in paths:
			var res: Resource = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REPLACE)
			if res is ItemDefinition:
				var item_def := res as ItemDefinition
				item_def.rarity = new_rarity
				ResourceSaver.save(item_def, p)
		print("Item & Skill Overview: zmieniono rarity na %s dla %d itemów" % [
			GameEnums.Rarity.keys()[new_rarity], paths.size()
		])
		_scan_and_populate()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


# ---------------------------------------------------------------------------
# SORTOWANIE
# ---------------------------------------------------------------------------

func _on_skills_title_clicked(column: int, mouse_button_index: int) -> void:
	if column == SCOL_CHECK:
		_toggle_all_checkboxes(skills_tree, SCOL_CHECK, SCOL_WARN, true)
		return
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		skills_sort_col = -1
		skills_sort_asc = true
		skills_rows.sort_custom(func(a, b): return String(a["path"]) < String(b["path"]))
		_render_skills()
		_reapply_all_filters()
		return
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return

	if skills_sort_col == column:
		skills_sort_asc = not skills_sort_asc
	else:
		skills_sort_col = column
		skills_sort_asc = true

	_sort_rows(skills_rows, skills_sort_col, skills_sort_asc)
	_render_skills()
	_reapply_all_filters()


func _on_items_title_clicked(column: int, mouse_button_index: int) -> void:
	if column == ICOL_CHECK:
		_toggle_all_checkboxes(items_tree, ICOL_CHECK, ICOL_WARN, false)
		return
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		items_sort_col = -1
		items_sort_asc = true
		items_rows.sort_custom(func(a, b): return String(a["path"]) < String(b["path"]))
		_render_items()
		_reapply_all_filters()
		return
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return

	if items_sort_col == column:
		items_sort_asc = not items_sort_asc
	else:
		items_sort_col = column
		items_sort_asc = true

	_sort_rows(items_rows, items_sort_col, items_sort_asc)
	_render_items()
	_reapply_all_filters()


func _toggle_all_checkboxes(tree: Tree, check_col: int, _meta_col: int, is_skills: bool) -> void:
	var root := tree.get_root()
	if root == null:
		return
	var all_checked := true
	var child := root.get_first_child()
	while child != null:
		if not child.is_checked(check_col):
			all_checked = false
			break
		child = child.get_next()

	var new_state := not all_checked
	child = root.get_first_child()
	while child != null:
		child.set_checked(check_col, new_state)
		child = child.get_next()

	_on_tree_selection(tree, is_skills)


func _sort_rows(rows: Array[Dictionary], col: int, asc: bool) -> void:
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var cmp := _compare_values(a["sort"][col], b["sort"][col])
		if cmp == 0:
			return String(a["path"]) < String(b["path"])
		return cmp < 0 if asc else cmp > 0
	)


func _compare_values(a, b) -> int:
	if a == null and b == null:
		return 0
	if a == null:
		return -1
	if b == null:
		return 1

	if typeof(a) == TYPE_STRING and typeof(b) == TYPE_STRING:
		var sa: String = a
		var sb: String = b
		return sa.naturalnocasecmp_to(sb)

	if a < b:
		return -1
	if a > b:
		return 1
	return 0


func _enum_sort(value) -> int:
	if value == null or typeof(value) != TYPE_INT:
		return -1
	return value


func _update_title_indicators(tree: Tree, titles: PackedStringArray, sort_col: int, asc: bool) -> void:
	for i in titles.size():
		var t := titles[i]
		if i == sort_col:
			t += "  " + ("▲" if asc else "▼")
		tree.set_column_title(i, t)


# ---------------------------------------------------------------------------
# WALIDACJA / FORMATOWANIE
# ---------------------------------------------------------------------------

func _enum_name(keys: Array, value) -> String:
	if value == null:
		return "⚠NULL"
	if typeof(value) != TYPE_INT:
		return "⚠NULL"
	if value < 0 or value >= keys.size():
		return "⚠POZA ZAKRESEM"
	return keys[value]


func _validate_skill(skill: SkillDefinition, path: String, used_skill_paths: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	if skill.id == "":
		warnings.append("Brak ID")
	if skill.skill_name == "":
		warnings.append("Brak nazwy")
	if skill.description == "":
		warnings.append("Brak opisu")
	if skill.icon == null:
		warnings.append("Brak ikony")
	if skill.scalings.is_empty():
		warnings.append("Brak scalingów")
	if skill.effect_type == null:
		warnings.append("effect_type jest NULL — uszkodzony zasób, otwórz w Inspectorze i ustaw ręcznie")
	if skill.target_type == null:
		warnings.append("target_type jest NULL — uszkodzony zasób")
	if skill.damage_element == null:
		warnings.append("damage_element jest NULL — uszkodzony zasób")
	if not used_skill_paths.has(path):
		warnings.append("Nieużywany — żaden item nie ma go jako default_skill")

	return warnings


func _validate_item(def: ItemDefinition) -> Array[String]:
	var warnings: Array[String] = []
	if def.id == "":
		warnings.append("Brak ID")
	if def.name == "":
		warnings.append("Brak nazwy")
	if def.default_skill == null:
		warnings.append("Brak default_skill")
	if def.icon == null:
		warnings.append("Brak ikony")
	return warnings


func _get_effect_color(effect_type) -> Color:
	if effect_type == null:
		return Color(0.5, 0.1, 0.1, 0.5)
	match effect_type:
		GameEnums.SkillEffect.DAMAGE: return Color(0.417, 0.193, 0.071, 0.35)
		GameEnums.SkillEffect.HEAL: return Color(0.15, 0.4, 0.2, 0.35)
		GameEnums.SkillEffect.SHIELD: return Color(0.15, 0.25, 0.45, 0.35)
		GameEnums.SkillEffect.GOLD: return Color(0.5, 0.45, 0.1, 0.35)
		GameEnums.SkillEffect.CLEANSE: return Color(0.35, 0.15, 0.45, 0.35)
		_: return Color(0, 0, 0, 0)


# ---------------------------------------------------------------------------
# INTERAKCJA
# ---------------------------------------------------------------------------

func _on_skill_activated() -> void:
	var col := skills_tree.get_selected_column()
	if col == SCOL_CHECK:
		return
	_open_selected(skills_tree, SCOL_WARN)


func _on_item_activated() -> void:
	var col := items_tree.get_selected_column()
	if col == ICOL_CHECK:
		return
	if col == ICOL_SKILL:
		var selected := items_tree.get_selected()
		if selected == null:
			return
		var meta = selected.get_metadata(ICOL_SKILL)
		var skill_path: String = meta if meta != null else ""
		if skill_path != "":
			_jump_to_skill(skill_path)
			return
	_open_selected(items_tree, ICOL_WARN)


func _jump_to_skill(skill_path: String) -> void:
	tabs.current_tab = 0
	var root := skills_tree.get_root()
	if root == null:
		return
	var child := root.get_first_child()
	while child != null:
		if child.get_metadata(SCOL_WARN) == skill_path:
			child.select(SCOL_ID)
			skills_tree.scroll_to_item(child)
			return
		child = child.get_next()


func _open_selected(tree: Tree, meta_col: int) -> void:
	var item := tree.get_selected()
	if item == null:
		return
	var path = item.get_metadata(meta_col)
	if path == null or path == "":
		return
	EditorInterface.edit_resource(ResourceLoader.load(path))


# ---------------------------------------------------------------------------
# FILTRY
# ---------------------------------------------------------------------------

func _on_filter_changed(text: String) -> void:
	_current_filter = text
	_reapply_all_filters()


func _reset_all_filters() -> void:
	_current_filter = ""
	_skill_filter_effect = -1
	_skill_filter_element = -1
	_item_filter_rarity = -1
	_item_filter_slot = -1
	effect_filter_btn.select(0)
	element_filter_btn.select(0)
	rarity_filter_btn.select(0)
	slot_filter_btn.select(0)
	_reapply_all_filters()


func _reapply_all_filters() -> void:
	_apply_combined_filter_skills()
	_apply_combined_filter_items()


func _apply_combined_filter_skills() -> void:
	var needle := _current_filter.to_lower()
	var root := skills_tree.get_root()
	if root == null:
		return
	var idx := 0
	var child := root.get_first_child()
	while child != null:
		var visible := true

		if needle != "":
			var id_text := child.get_text(SCOL_ID).to_lower()
			var name_text := child.get_text(SCOL_NAME).to_lower()
			if not (needle in id_text or needle in name_text):
				visible = false

		if visible and _skill_filter_effect >= 0 and idx < skills_rows.size():
			if skills_rows[idx].get("effect_idx", -1) != _skill_filter_effect:
				visible = false

		if visible and _skill_filter_element >= 0 and idx < skills_rows.size():
			if skills_rows[idx].get("element_idx", -1) != _skill_filter_element:
				visible = false

		child.visible = visible
		child = child.get_next()
		idx += 1


func _apply_combined_filter_items() -> void:
	var needle := _current_filter.to_lower()
	var root := items_tree.get_root()
	if root == null:
		return
	var idx := 0
	var child := root.get_first_child()
	while child != null:
		var visible := true

		if needle != "":
			var id_text := child.get_text(ICOL_ID).to_lower()
			var name_text := child.get_text(ICOL_NAME).to_lower()
			if not (needle in id_text or needle in name_text):
				visible = false

		if visible and _item_filter_rarity >= 0 and idx < items_rows.size():
			if items_rows[idx].get("rarity_idx", -1) != _item_filter_rarity:
				visible = false

		if visible and _item_filter_slot >= 0 and idx < items_rows.size():
			if items_rows[idx].get("slot_idx", -1) != _item_filter_slot:
				visible = false

		child.visible = visible
		child = child.get_next()
		idx += 1


# ---------------------------------------------------------------------------
# EKSPORT
# ---------------------------------------------------------------------------

func _export_csv() -> void:
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("_exports"):
		dir.make_dir("_exports")
	_export_tree_to_csv(skills_tree, skills_titles, "res://_exports/skills.csv")
	_export_tree_to_csv(items_tree, items_titles, "res://_exports/items.csv")
	print("Item & Skill Overview: eksport CSV zakończony (res://_exports/)")


func _export_tree_to_csv(tree: Tree, titles: PackedStringArray, out_path: String) -> void:
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_warning("Nie udało się zapisać %s" % out_path)
		return

	var header: Array[String] = []
	for c in range(1, tree.columns):
		header.append(titles[c] if c < titles.size() else tree.get_column_title(c))
	file.store_line(",".join(header))

	var root := tree.get_root()
	if root:
		var child := root.get_first_child()
		while child != null:
			var row_data: Array[String] = []
			for c in range(1, tree.columns):
				row_data.append("\"%s\"" % child.get_text(c).replace("\"", "'"))
			file.store_line(",".join(row_data))
			child = child.get_next()

	file.close()


# ---------------------------------------------------------------------------
# SKANOWANIE / FORMATTERY
# ---------------------------------------------------------------------------

func _find_tres_files(folder_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with(".") or file_name == "addons":
			file_name = dir.get_next()
			continue
		var full_path := folder_path.path_join(file_name)
		if dir.current_is_dir():
			result.append_array(_find_tres_files(full_path))
		elif file_name.ends_with(".tres"):
			result.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func _format_scalings(scalings: Array[SkillScaling]) -> String:
	if scalings == null or scalings.is_empty():
		return "—"
	var parts: Array[String] = []
	for s in scalings:
		if s == null:
			parts.append("⚠NULL")
			continue
		parts.append("%s×%.2f" % [_enum_name(GameEnums.Stat.keys(), s.stat), s.weight])
	return ", ".join(parts)


func _format_bonus_hits(scaling: SkillScaling) -> String:
	if scaling == null:
		return "—"
	return "%s×%.2f" % [_enum_name(GameEnums.Stat.keys(), scaling.stat), scaling.weight]


func _format_affinities(affinities: Array[ItemAffinity]) -> String:
	if affinities == null or affinities.is_empty():
		return "—"
	var parts: Array[String] = []
	for a in affinities:
		if a == null:
			parts.append("⚠NULL")
			continue
		parts.append("%s×%.2f" % [_enum_name(GameEnums.DamageElement.keys(), a.element), a.multiplier])
	return ", ".join(parts)
