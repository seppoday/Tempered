extends Node

const CONFIG_PATH = "user://settings.cfg"

var languages: Array[String] = [
	"en", "pl", "fr", "de", "ja", "zh", "it", "es", "ko", "pt_BR", "ru"
]

func _ready() -> void:
	_load_locale()

func _load_locale() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)

	var locale := "en" # domyślny

	if err == OK:
		locale = config.get_value("language", "locale", "pl")

	TranslationServer.set_locale(locale)
	print("LocaleManager: ustawiono język na ", locale)
