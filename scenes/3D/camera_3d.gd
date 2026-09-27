extends Camera3D
class_name ShakingCamera3D

@export var noise: FastNoiseLite

# Maksymalne wychylenie w metrach (pozycja) i radianach (rotacja)
@export var max_position_strength: float = 0.2
@export var max_rotation_strength: float = 0.05 # ok. 6 stopni

# Szybkość trzęsienia
@export var noise_speed: float = 30.0

var shake_decay: float = 5.0 # Jak szybko wygasa (wyższa wartość = szybszy koniec)
var shake_strength: float = 0.0 # Aktualna siła (od 0.0 do 1.0)
var noise_time: float = 0.0

func _ready() -> void:
	randomize()
	# Jeśli nie przypisano szumu w Inspektorze, tworzymy domyślny
	if not noise:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.seed = randi()
		noise.frequency = 0.5

## Odpala trzęsienie. strength: 0.0 - 1.0, decay: szybkość wygasania
func shake(strength: float = 0.02, decay: float = 8.0) -> void:
	shake_strength = clamp(strength, 0.0, 1.0)
	shake_decay = decay


func _process(delta: float) -> void:
	if shake_strength > 0.0:
		# Płynne wygaszanie siły
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		
		# Jeśli trzęsienie jest już ledwo widoczne, resetujemy kamerę
		if shake_strength < 0.005:
			shake_strength = 0.0
			position = Vector3.ZERO
			rotation = Vector3.ZERO
			return
			
		noise_time += delta * noise_speed
		
		# Obliczamy przesunięcie pozycji za pomocą szumu (różne osie na różnych wysokościach szumu)
		var offset_pos := Vector3(
			noise.get_noise_2d(100, noise_time),
			noise.get_noise_2d(200, noise_time),
			noise.get_noise_2d(300, noise_time)
		) * max_position_strength * shake_strength
		
		# Obliczamy rotację (to daje najlepszy efekt uderzenia)
		var offset_rot := Vector3(
			noise.get_noise_2d(400, noise_time),
			noise.get_noise_2d(500, noise_time),
			noise.get_noise_2d(600, noise_time)
		) * max_rotation_strength * shake_strength
		
		# Zastosowanie lokalnego offsetu (dlatego ważne jest, aby lokalnie kamera startowała z 0,0,0)
		position = offset_pos
		rotation = offset_rot
