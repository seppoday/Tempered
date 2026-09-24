class_name Log extends RefCounted

const ERR_TEMPLATE: String = "{message} [b]FROM[/b] {source}:{line} [b]@{function}()[/b]"
const WRN_TEMPLATE: String = "{message} [b]FROM[/b] {source}:{line} [b]@{function}()[/b]"
const PRINT_TEMPLATE: String = "[color=cyan]▶[/color] {message} [color=gray]│[/color] [color=orange]{source}:{line}[/color] [color=gray]@{function}()[/color]"

static func print(...args: Array) -> void:
	var message: String = as_string(args)
	var data: Dictionary = {
		"message": message,
	}.merged( get_line(2) )
	print_rich(PRINT_TEMPLATE.format(data))

static func error(...args: Array) -> void:
	var message: String = as_string(args)
	var data: Dictionary = {
		"message": message,
	}.merged( get_line(2) )
	push_error(message)
	printerr(ERR_TEMPLATE.format( data ))

static func warning(...args: Array) -> void:
	var message: String = as_string(args)
	var data: Dictionary = {
		"message": message,
	}.merged( get_line(2) )
	push_warning(message)
	print_rich(
		"[color=khaki][b]WARNING: [/b]",
		WRN_TEMPLATE.format( data ),
		"[/color]"
	)

static func get_line(index: int) -> Dictionary:
	var stack: Array = get_stack()
	if index < 0 || index > stack.size() -1:
		return {}
	return stack[index]

static func get_enum_name(dict: Dictionary, value: int) -> String:
	if !dict:
		return "(NULL)"
	var index: int = dict.values().find(value)
	if index == -1:
		return "(OUT OF BOUNDS)"
	return str(dict.keys()[index])

static func as_string(args: Array) -> String:
	return str("".join(args))
