class_name DiceFaceMapper
extends RefCounted

# Mapowanie: max_face (6, 20...) -> { numer_ścianki: wektor_lokalny_"do góry" }
static var FACE_UP_BY_NUMBER: Dictionary = _build_face_maps()


static func _build_face_maps() -> Dictionary:
	return {
		6: {
			1: Vector3.DOWN,
			2: Vector3.LEFT,
			3: Vector3.BACK,
			4: Vector3.FORWARD,
			5: Vector3.RIGHT,
			6: Vector3.UP,
		},
		20: {
			# Bieguny
			20: Vector3(0.0, 1.0, 0.0).normalized(),
			1: Vector3(0.0, -1.0, 0.0).normalized(),

			# Górny pierścień
			14: Vector3(0.0, 0.745, 0.667).normalized(),
			8:  Vector3(-0.577, 0.745, -0.333).normalized(),
			2:  Vector3(0.577, 0.745, -0.333).normalized(),

			# Dolny pierścień
			7:  Vector3(0.0, -0.745, -0.667).normalized(),
			13: Vector3(0.577, -0.745, 0.333).normalized(),
			19: Vector3(-0.577, -0.745, 0.333).normalized(),

			# Pasek górny
			10: Vector3(-0.471, 0.333, -0.816).normalized(),
			12: Vector3( 0.471, 0.333, -0.816).normalized(),
			18: Vector3( 0.943, 0.333, 0.0).normalized(),
			4:  Vector3( 0.471, 0.333, 0.816).normalized(),
			6:  Vector3(-0.471, 0.333, 0.816).normalized(),
			16: Vector3(-0.943, 0.333, 0.0).normalized(),

			# Pasek dolny
			17: Vector3(-0.471, -0.333, -0.816).normalized(),
			15: Vector3( 0.471, -0.333, -0.816).normalized(),
			5:  Vector3( 0.943, -0.333, 0.0).normalized(),
			11: Vector3( 0.471, -0.333, 0.816).normalized(),
			9:  Vector3(-0.471, -0.333, 0.816).normalized(),
			3:  Vector3(-0.943, -0.333, 0.0).normalized(),
		}
	}


## Zwraca mapę ścianek dla danego max_face, z fallbackiem do d6.
static func get_face_map(max_face: int) -> Dictionary:
	return FACE_UP_BY_NUMBER.get(max_face, FACE_UP_BY_NUMBER.get(6, {}))


## Zwraca lokalny wektor "do góry" dla danej ścianki (z fallbackiem do Vector3.UP).
static func get_local_up(max_face: int, face_number: int) -> Vector3:
	var face_map := get_face_map(max_face)
	return face_map.get(face_number, Vector3.UP)


## Odczytuje, która ścianka aktualnie jest skierowana najbardziej "do góry" w świecie.
static func get_landed_face(die: RigidBody3D, max_face: int) -> int:
	var face_map := get_face_map(max_face)
	var best_face := 1
	var max_dot := -10.0

	for face_num in face_map:
		var local_up: Vector3 = face_map[face_num]
		var world_up: Vector3 = (die.global_basis * local_up).normalized()
		var dot := world_up.dot(Vector3.UP)
		if dot > max_dot:
			max_dot = dot
			best_face = face_num

	return best_face
