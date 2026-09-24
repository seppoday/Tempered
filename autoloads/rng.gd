extends Node

var _generator := RandomNumberGenerator.new()
var current_seed: int

func _ready() -> void:
	# Przykład użycia RandomNumberGenerator
	_generator.randomize()
	current_seed = _generator.seed

func set_seed(_seed: int) -> void:
	_generator.seed = _seed

func randi_range(_min: int, _max: int) -> int:
	return _generator.randi_range(_min, _max)

func randf_range(_min: float, _max: float) -> float:
	return _generator.randf_range(_min, _max)

func weighted_pick(entries: Array) -> Variant:
	if entries.is_empty():
		return null

	var total_weight := 0
	for entry in entries:
		total_weight += entry.weight

	var roll := randi_range(0, total_weight - 1)

	var cumulative := 0
	for entry in entries:
		cumulative += entry.weight
		if roll < cumulative:
			return entry
	
	return null

func randi() -> float:
	return _generator.randi()

func randf() -> float:
	return _generator.randf()
