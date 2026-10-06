extends CanvasLayer

var resolutions: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

var window_modes: Array[String] = [
	"MENU_OPTIONS_WINDOW_MODE_WINDOWED",
	"MENU_OPTIONS_WINDOW_MODE_FULLSCREEN",
	"MENU_OPTIONS_WINDOW_MODE_BORDERLESS",
	"MENU_OPTIONS_WINDOW_MODE_EXCLUSIVE"
]

var languages: Array[String] = [
	"en", "pl", "fr", "de", "ja", "zh", "it", "es", "ko", "pt_BR", "ru"
]

var language_names: Array[String] = [
	"English", "Polski", "Français", "Deutsch", "日本語",
	"中文", "Italiano", "Español", "한국어", "Português (Brasil)", "Русский"
]

@onready var resolution_option: OptionButton = %ResolutionOptionButton
@onready var window_mode_option: OptionButton = %WindowModeOptionButton
@onready var vsync_check: CheckButton = %VSyncCheckButton
@onready var apply_button: Button = %ApplyButton
@onready var back_button: Button = %BackButton
@onready var language_label: Label = %LanguageLabel
@onready var language_option_button: OptionButton = %LanguageOptionButton

const CONFIG_PATH = "user://settings.cfg"


func _ready() -> void:
	GameManager.set_state(GameManager.State.SETTINGS, self)
	_populate_resolutions()
	_populate_window_modes()
	_populate_languages()
	_load_settings()
	_connect_signals()


func _populate_resolutions() -> void:
	resolution_option.clear()
	for res in resolutions:
		resolution_option.add_item("%d x %d" % [res.x, res.y])

	var current_res = DisplayServer.window_get_size()
	for i in range(resolutions.size()):
		if resolutions[i] == current_res:
			resolution_option.selected = i
			break


func _populate_window_modes(keep_selection: bool = false) -> void:
	# Zapamiętujemy, co gracz miał zaznaczone przed chwilą
	var previous_selected = window_mode_option.selected
	
	window_mode_option.clear()
	for mode in window_modes:
		# tr() automatycznie przetłumaczy klucz na aktualnie ustawiony język
		window_mode_option.add_item(tr(mode))

	if keep_selection and previous_selected != -1:
		window_mode_option.selected = previous_selected
	else:
		# Standardowe zaznaczanie na podstawie aktualnego stanu systemu
		var current_mode = DisplayServer.window_get_mode()
		match current_mode:
			DisplayServer.WINDOW_MODE_WINDOWED:
				window_mode_option.selected = 0
			DisplayServer.WINDOW_MODE_FULLSCREEN:
				window_mode_option.selected = 1
			DisplayServer.WINDOW_MODE_MAXIMIZED:
				window_mode_option.selected = 2
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				window_mode_option.selected = 3


func _populate_languages() -> void:
	language_option_button.clear()
	for i in range(languages.size()):
		language_option_button.add_item(language_names[i])

	var current_locale := TranslationServer.get_locale()
	var language_index := languages.find(current_locale)

	if language_index == -1:
		var short_locale := current_locale.split("_")[0]
		language_index = languages.find(short_locale)

	if language_index == -1:
		language_index = 0

	language_option_button.selected = language_index


func _connect_signals() -> void:
	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)
	LocaleManager.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_locale: String) -> void:
	_populate_languages()           # dropdown języka pokaże aktualny wybór
	_populate_window_modes(true)    # przetłumaczone nazwy trybów okna

func _on_apply_pressed() -> void:
	_apply_settings()
	_save_settings()


func _on_back_pressed() -> void:
	SceneTransition.fade_to_scene("uid://bxiyugah6we1q")


func _apply_language() -> void:
	var selected_index := language_option_button.selected
	if selected_index < 0 or selected_index >= LocaleManager.languages.size():
		return
	LocaleManager.set_language(LocaleManager.languages[selected_index], false)


func _update_localized_text() -> void:
	# Przeładuj dropdown z trybami okna, zachowując obecny wybór
	_populate_window_modes(true)
	
	# Jeśli masz inne elementy UI, które zmieniasz z poziomu kodu:
	# apply_button.text = tr("APPLY_BUTTON_KEY")
	# back_button.text = tr("BACK_BUTTON_KEY")
	
	# Powiadom resztę gry o zmianie języka
	get_tree().call_group("localized", "update_localization")


func _apply_settings() -> void:
	_apply_language()
	_apply_display_settings()


func _apply_display_settings() -> void:
	var selected_mode := window_mode_option.selected
	var selected_res := resolutions[resolution_option.selected]

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

	match selected_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(selected_res)
			_center_window()
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen := DisplayServer.window_get_current_screen()
			var screen_size := DisplayServer.screen_get_size(screen)
			DisplayServer.window_set_size(screen_size)
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
		3:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	if vsync_check.button_pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _center_window() -> void:
	var screen_size = DisplayServer.screen_get_size()
	var window_size = DisplayServer.window_get_size()
	var centered_pos = (screen_size - window_size) / 2
	DisplayServer.window_set_position(centered_pos)


func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("display", "resolution_index", resolution_option.selected)
	config.set_value("display", "window_mode", window_mode_option.selected)
	config.set_value("display", "vsync", vsync_check.button_pressed)
	config.set_value("language", "locale", languages[language_option_button.selected])
	config.save(CONFIG_PATH)


func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)

	if err != OK:
		language_option_button.selected = 0
		_apply_settings()
		return

	var res_index = config.get_value("display", "resolution_index", 3)
	var win_mode = config.get_value("display", "window_mode", 0)
	var vsync = config.get_value("display", "vsync", true)

	var locale = config.get_value("language", "locale", "pl")
	var language_index := languages.find(locale)
	if language_index == -1:
		language_index = 0
	language_option_button.selected = language_index

	resolution_option.selected = res_index
	window_mode_option.selected = win_mode
	vsync_check.button_pressed = vsync

	_apply_display_settings()
