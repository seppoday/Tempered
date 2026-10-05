# SettingsManager.gd - dodaj jako Autoload w Project Settings
extends Node

const CONFIG_PATH = "user://settings.cfg"

var resolutions: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]


func _ready() -> void:
	load_and_apply()


func load_and_apply() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	if err != OK:
		return
	
	var res_index: int = config.get_value("display", "resolution_index", 3)
	var win_mode: int = config.get_value("display", "window_mode", 0)
	var vsync: bool = config.get_value("display", "vsync", true)
	
	# Tryb okna
	match win_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen_size = DisplayServer.screen_get_size()
			DisplayServer.window_set_size(screen_size)
			DisplayServer.window_set_position(Vector2i.ZERO)
		3:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	# Rozdzielczość (tylko w trybie okienkowym)
	if win_mode == 0:
		if res_index >= 0 and res_index < resolutions.size():
			DisplayServer.window_set_size(resolutions[res_index])
			# Centruj
			var screen_size = DisplayServer.screen_get_size()
			var window_size = DisplayServer.window_get_size()
			DisplayServer.window_set_position((screen_size - window_size) / 2)
	
	# VSync
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
