@tool
extends EditorScript

const DIRS := {
	"MUSIC": "res://assets/audio/music/",
	"SFX": "res://assets/audio/sfx/",
	"UI": "res://assets/audio/ui/",
}

const OUTPUT_PATH := "res://scripts/audio/audio_keys.gd"

func _run() -> void:
	var lines: Array[String] = []
	lines.append("# AUTO-GENERATED — nie edytuj ręcznie. Uruchom generate_audio_keys.gd, żeby odświeżyć.")
	lines.append("class_name AudioKeys")
	lines.append("extends RefCounted")
	lines.append("")

	for category in DIRS:
		var path: String = DIRS[category]
		var names := _scan_names(path)
		lines.append("# %s" % category)
		for n in names:
			var const_name := "%s_%s" % [category, n.to_upper()]
			lines.append('const %s: StringName = &"%s"' % [const_name, n])
		lines.append("")

	# NOWE: upewnij się, że folder docelowy istnieje
	var dir_path := OUTPUT_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			Log.error("Nie udało się utworzyć folderu: %s (błąd %d)" % [dir_path, err])
			return

	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		Log.error("Nie udało się otworzyć pliku do zapisu: %s (błąd %d)" % [OUTPUT_PATH, FileAccess.get_open_error()])
		return

	file.store_string("\n".join(lines))
	file.close()

	Log.print("AudioKeys wygenerowane: ", OUTPUT_PATH)


func _scan_names(path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".import"):
			result.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()

	result.sort()
	return result
