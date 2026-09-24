class_name ResourceDatabase extends RefCounted

var _entries: Dictionary = {}

func load_folder(path: String, expected_type) -> void:
	_scan_folder(path, expected_type)


func _scan_folder(path: String, expected_type) -> void:	
	var dir := DirAccess.open(path)
	if dir == null:
		Log.print("Nie udało się otworzyć katalogu: ", path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name

		if dir.current_is_dir():
			_scan_folder(full_path, expected_type)
			pass
		elif file_name.ends_with(".tres"):
			var resource := load(full_path)
			if is_instance_of(resource, expected_type):
				if _entries.has(resource.id):
					Log.print("UWAGA: Duplikat Resource o ID: ", resource.id, " w pliku: ", full_path)
				else:
					_entries[resource.id] = resource
			else:
				Log.print("Plik nie jest oczekiwanym typem: ", full_path)
			pass
		
		file_name = dir.get_next()

func get_entry(id: String) -> Resource:
	if not _entries.has(id):
		Log.warning("ResourceDatabase: Nie znaleziono Resource o ID: ", id)
		return null
	else:
		return _entries[id]

func get_entries() -> Array:
	return _entries.values()
