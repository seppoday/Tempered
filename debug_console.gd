extends CanvasLayer
# Autoload

@onready var panel: PanelContainer = $PanelContainer
@onready var output: RichTextLabel = %Output
@onready var scroll: ScrollContainer = %ScrollContainer
@onready var input: LineEdit = %Input

var _commands: Dictionary = {}


func _ready() -> void:
	layer = 999
	panel.visible = false
	input.text_submitted.connect(_on_submitted)

	register_command("help", _cmd_help, "help — lista komend")
	register_command("additem", _cmd_additem, "additem <id> [ilość] — dodaje item do plecaka po ID")
	register_command("listitems", _cmd_list_items, "listitems [filtr] — wypisuje dostępne ID przedmiotów")
	register_command("lang", _cmd_lang, "lang [kod] — pokazuje lub zmienia język (np. lang en, lang pt_BR)")
	register_command("gold", _cmd_gold, "gold [ilość] — pokazuje złoto; gold 0 zeruje; gold 500 ustawia")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		_set_open(not panel.visible)
		get_viewport().set_input_as_handled()
	elif panel.visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _set_open(value: bool) -> void:
	panel.visible = value
	if value:
		input.grab_focus()

func register_command(name: String, callable: Callable, usage: String = "") -> void:
	_commands[name] = {"callable": callable, "usage": usage}

func unregister_command(name: String, callable: Callable = Callable()) -> void:
	if not _commands.has(name):
		return
	if callable.is_valid() and _commands[name]["callable"] != callable:
		return
	_commands.erase(name)

func _cmd_gold(args: Array) -> String:
	# Dostosuj getter/setter do MetaProgressionManager (gold / get_gold / set_gold)
	var current: int = 0
	if "gold" in MetaProgressionManager:
		current = int(MetaProgressionManager.gold)
	elif MetaProgressionManager.has_method("get_gold"):
		current = int(MetaProgressionManager.get_gold())

	if args.is_empty():
		return "Złoto: [color=yellow]%d[/color]  (wpisz [color=gray]gold 0[/color] aby wyzerować)" % current

	var target: int = int(args[0])
	if target < 0:
		return "[color=red]Ilość nie może być ujemna[/color]"

	if MetaProgressionManager.has_method("set_gold"):
		MetaProgressionManager.set_gold(target)
	elif "gold" in MetaProgressionManager:
		# Fallback przez add_gold, jeśli nie ma settera
		var delta: int = target - current
		if delta != 0 and MetaProgressionManager.has_method("add_gold"):
			MetaProgressionManager.add_gold(delta)
		else:
			MetaProgressionManager.gold = target
	elif MetaProgressionManager.has_method("add_gold"):
		MetaProgressionManager.add_gold(target - current)
	else:
		return "[color=red]MetaProgressionManager nie ma gold / set_gold / add_gold[/color]"

	return "[color=green]Złoto: %d → %d[/color]" % [current, target]

func _cmd_lang(args: Array) -> String:
	if args.is_empty():
		var lines: Array[String] = [
			"Aktualny język: [color=yellow]%s[/color]" % TranslationServer.get_locale()
		]
		for i in LocaleManager.languages.size():
			lines.append("  %s — %s" % [LocaleManager.languages[i], LocaleManager.language_names[i]])
		return "\n".join(lines)

	var code := String(args[0])
	if not LocaleManager.set_language(code):
		return "[color=red]Nieznany język '%s' (wpisz 'lang' aby zobaczyć listę)[/color]" % code
	return "[color=green]Zmieniono język na %s[/color]" % LocaleManager.find_language(code)

func _on_submitted(text: String) -> void:
	input.clear()
	if text.strip_edges().is_empty():
		return

	_log("[color=gray]> %s[/color]" % text)

	var parts := text.strip_edges().split(" ", false)
	var command_name := parts[0]
	var args := parts.slice(1)

	if not _commands.has(command_name):
		_log("[color=red]Nieznana komenda: %s (wpisz 'help')[/color]" % command_name)
		return

	var result: String = _commands[command_name]["callable"].call(args)
	if result:
		_log(result)


func _log(text: String) -> void:
	output.append_text(text + "\n")
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _cmd_help(_args: Array) -> String:
	var lines: Array[String] = []
	for command_name in _commands:
		lines.append(_commands[command_name]["usage"])
	return "\n".join(lines)


func _cmd_additem(args: Array) -> String:
	if args.is_empty():
		return "[color=red]Użycie: additem <id> [ilość][/color]"

	var id: String = args[0]
	var amount: int = int(args[1]) if args.size() > 1 else 1

	var definition: InventoryEntry = _find_entry(id)
	if definition == null:
		return "[color=red]Nie znaleziono itemu o id '%s'[/color]" % id

	if not definition is ItemDefinition:
		return "[color=red]'%s' nie jest itemem do założenia (ItemDefinition)[/color]" % id

	var previous: ItemInstance = PlayerData.equip_item(ItemInstance.new(definition, amount))
	if previous != null:
		return "[color=green]Założono %dx %s (zastąpiono %s)[/color]" % [amount, definition.name, previous.definition.name]
	return "[color=green]Założono %dx %s[/color]" % [amount, definition.name]


func _cmd_list_items(args: Array) -> String:
	var filter: String = args[0].to_lower() if args.size() > 0 else ""
	var lines: Array[String] = []

	for category in _inventory_databases():
		var database = _inventory_databases()[category]
		for entry: InventoryEntry in database.get_all():
			var matches := filter.is_empty() \
				or filter in entry.id.to_lower() \
				or filter in entry.name.to_lower()
			if matches:
				lines.append("[color=gray]%s[/color]  %s — %s" % [category, entry.id, entry.name])

	if lines.is_empty():
		return "[color=red]Brak wyników dla '%s'[/color]" % filter

	lines.sort()
	return "\n".join(lines)

func _inventory_databases() -> Dictionary:
	return {
		"item": ItemDatabase,
		"material": MaterialDatabase,
		"consumable": ConsumableDatabase,
	}


func _find_entry(id: String) -> InventoryEntry:
	for database in _inventory_databases().values():
		var found: InventoryEntry = database.get_by_id(id)
		if found:
			return found
	return null
