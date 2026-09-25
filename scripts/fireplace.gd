extends Node3D

@onready var fireplace: Light3D = %Fireplace

# Bazy do resetu / obliczeń
var base_energy: float = 2.0
var base_range: float = 10.0
var base_color: Color

# Konfiguracja efektu
@export var min_energy_mult: float = 0.85   # było 0.65 — teraz spada max do 85%
@export var max_energy_mult: float = 1.12   # było 1.30 — teraz rośnie max do 112%
@export var flicker_speed_min: float = 0.2  # było 0.05 — wolniejsze mignięcia
@export var flicker_speed_max: float = 0.5  # było 0.18 — bardziej leniwe przejściae

var fireplace_tween: Tween

func _ready() -> void:
	if fireplace:
		# Zapisujemy wartości początkowe ustawione w edytorze
		base_energy = fireplace.light_energy
		base_color = fireplace.light_color
		
		if fireplace is OmniLight3D:
			base_range = fireplace.omni_range
		elif fireplace is SpotLight3D:
			base_range = fireplace.spot_range
			
		# Uruchamiamy migotanie
		start_fireplace()


func start_fireplace() -> void:
	_flicker_step()


func stop_fireplace() -> void:
	if fireplace_tween:
		fireplace_tween.kill()


func _flicker_step() -> void:
	if not is_instance_valid(fireplace):
		return

	# Tworzymy tween, który wykona JEDNO mignięcie
	fireplace_tween = create_tween().set_parallel(true)

	# 1. Losujemy czas trwania tego konkretnego mignięcia
	var duration := randf_range(flicker_speed_min, flicker_speed_max)

	# 2. Losujemy nową jasność i zasięg
	var energy_factor := randf_range(min_energy_mult, max_energy_mult)
	var target_energy := base_energy * energy_factor
	var target_range := base_range * randf_range(0.9, 1.1) # delikatne kurczenie/rozszerzanie światła

	# 3. Dynamiczna zmiana koloru (bardzo realistyczne!)
	# Gdy ogień przygasa (niski energy_factor), idzie w głęboką czerwień.
	# Gdy błyszczy (wysoki), idzie w jasny żółty/pomarańczowy.
	var target_color := base_color
	if energy_factor < 1.0:
		# Przejście w czerwień przy przygasaniu
		target_color = base_color.lerp(Color(1.0, 0.15, 0.0), (1.0 - energy_factor) * 0.6)
	else:
		# Przejście w jasny żółty przy rozbłysku
		target_color = base_color.lerp(Color(1.0, 0.85, 0.3), (energy_factor - 1.0) * 0.5)

	# Animujemy parametry światła
	fireplace_tween.tween_property(fireplace, "light_energy", target_energy, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	fireplace_tween.tween_property(fireplace, "light_color", target_color, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Animujemy zasięg w zależności od typu światła
	var range_property = "omni_range" if fireplace is OmniLight3D else "spot_range"
	fireplace_tween.tween_property(fireplace, range_property, target_range, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 4. Sekwencyjnie po zakończeniu tego mignięcia, wywołaj kolejny krok
	fireplace_tween.chain().tween_callback(_flicker_step)
