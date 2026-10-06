extends Node

signal locale_changed(locale: String)

const CONFIG_PATH = "user://settings.cfg"

var languages: Array[String] = [
	"en", "pl", "fr", "de", "ja", "zh", "it", "es", "ko", "pt_BR", "ru"
]

var language_names: Array[String] = [
	"English", "Polski", "Français", "Deutsch", "日本語",
	"中文", "Italiano", "Español", "한국어", "Português (Brasil)", "Русский"
]


func _ready() -> void:
	_load_locale()


func _load_locale() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)

	var locale := "en"
	if err == OK:
		locale = config.get_value("language", "locale", "pl")

	TranslationServer.set_locale(locale)
	print("LocaleManager: ustawiono język na ", locale)


## Zwraca kanoniczny kod (np. "pt_BR") albo "" jeśli nie ma takiego języka.
func find_language(code: String) -> String:
	for lang in languages:
		if lang.to_lower() == code.to_lower().replace("-", "_"):
			return lang
	return ""


func set_language(code: String, save: bool = true) -> bool:
	var canonical := find_language(code)
	if canonical.is_empty():
		return false

	TranslationServer.set_locale(canonical)
	if save:
		_save_locale(canonical)

	get_tree().call_group("localized", "update_localization")
	locale_changed.emit(canonical)
	return true


func _save_locale(code: String) -> void:
	# Ładujemy istniejący plik, żeby nie nadpisać ustawień wyświetlania
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("language", "locale", code)
	config.save(CONFIG_PATH)
