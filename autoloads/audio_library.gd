extends Node

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const UI_DIR := "res://assets/audio/ui/"

var music: Dictionary = {}
var sfx: Dictionary = {}
var ui: Dictionary = {}


func _ready() -> void:
	music = _scan_directory(MUSIC_DIR)
	sfx = _scan_directory(SFX_DIR)
	ui = _scan_directory(UI_DIR)


func get_sfx(key: StringName) -> AudioStream:
	return _get_or_warn(sfx, key, "sfx")


func get_ui(key: StringName) -> AudioStream:
	return _get_or_warn(ui, key, "ui")


func get_music(key: StringName) -> AudioStream:
	return _get_or_warn(music, key, "music")


func _get_or_warn(dict: Dictionary, key: StringName, category: String) -> AudioStream:
	if not dict.has(key):
		Log.warning("AudioLibrary: brak '%s' w kategorii '%s'" % [key, category])
		return null
	return dict[key]


func _scan_directory(path: String) -> Dictionary:
	var result := {}
	var dir := DirAccess.open(path)
	if dir == null:
		Log.warning("AudioLibrary: nie mogę otworzyć %s" % path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".import"):
			var stream := load(path + file_name) as AudioStream
			if stream:
				result[file_name.get_basename()] = stream
		file_name = dir.get_next()
	dir.list_dir_end()

	return result
