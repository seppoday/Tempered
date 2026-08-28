extends Node

var _generator := RandomNumberGenerator.new()
var current_seed: int

func _ready() -> void:
	# Przykład użycia RandomNumberGenerator
	_generator.randomize()
	current_seed = _generator.seed

func set_seed(seed: int) -> void:
	_generator.seed = seed

func randi_range(min: int, max: int) -> int:
	return _generator.randi_range(min, max)