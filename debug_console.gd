extends CanvasLayer

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


## Wywoływane z dowolnego autoloadu/skryptu, żeby dodać nową komendę.
## callable dostaje Array[String] argumentów (bez nazwy komendy) i zwraca String do wypisania.
func register_command(name: String, callable: Callable, usage: String = "") -> void:
	_commands[name] = {"callable": callable, "usage": usage}

func unregister_command(name: String, callable: Callable = Callable()) -> void:
	if not _commands.has(name):
		return
	# Jeśli podano callable i nie zgadza się z aktualnie zarejestrowanym,
	# to znaczy że ktoś inny już przejął tę nazwę — nie usuwaj cudzej komendy.
	if callable.is_valid() and _commands[name]["callable"] != callable:
		return
	_commands.erase(name)

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

	var inventory := get_tree().get_first_node_in_group("inventory")
	if inventory == null:
		return "[color=red]Brak aktywnego plecaka w scenie[/color]"

	if inventory.add_item(ItemInstance.new(definition, amount)):
		return "[color=green]Dodano %dx %s[/color]" % [amount, definition.name]
	return "[color=red]Plecak pełny[/color]"


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


## Wspólne źródło dla additem i listitems — jedno miejsce, jeśli kiedyś dojdzie kolejna baza.
func _inventory_databases() -> Dictionary:
	return {
		"item": ItemDatabase,
		"material": MaterialDatabase,
		"consumable": ConsumableDatabase,
		"skill_item": SkillItemDatabase,
	}


func _find_entry(id: String) -> InventoryEntry:
	for database in _inventory_databases().values():
		var found: InventoryEntry = database.get_by_id(id)
		if found:
			return found
	return null
