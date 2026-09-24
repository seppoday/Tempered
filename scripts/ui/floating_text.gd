extends Node2D

@onready var label: Label = $Label

# Wartości dostosowane do Pixel Artu (mniejsze odległości):
@export var float_distance: float = 20.0     # o ile pikseli w górę (dla pixel artu 15-25 jest super)
@export var float_duration: float = 0.7      # czas trwania
@export var scale_up: float = 1.2            # delikatne powiększenie
@export var scale_duration: float = 0.1
@export var fade_duration: float = 0.2

func _ready() -> void:
	_update_pivot()
	_animate()

func setup(text: String, color: Color = Color.WHITE) -> void:
	if not is_node_ready():
		await ready
		
	label.text = text

	label.add_theme_color_override("font_color", color)
	_update_pivot()

func _update_pivot() -> void:
	Utilities.center_pivot(label)
	label.position = -label.size * 0.5

func _animate() -> void:
	scale = Vector2.ZERO
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# 1. Efekt "POP" (skalowanie)
	tween.tween_property(self, "scale", Vector2.ONE * scale_up, scale_duration)
	tween.tween_property(self, "scale", Vector2.ONE, scale_duration).set_delay(scale_duration)
	
	# 2. Ruch w górę - KLUCZOWA ZMIANA: .as_relative()
	# Dzięki .as_relative() ruch zawsze odbędzie się O float_distance w górę
	# niezależnie od tego, kiedy ustawisz global_position tekstu!
	tween.tween_property(self, "position:y", -float_distance, float_duration).as_relative()
	
	# 3. Zanikanie (Fade out)
	var fade_delay: float = float_duration - fade_duration
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_delay(fade_delay)
	
	# 4. Usunięcie po zakończeniu
	tween.chain().tween_callback(queue_free)
