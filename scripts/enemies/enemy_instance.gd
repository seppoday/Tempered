class_name EnemyInstance
extends Node3D

signal died(enemy: EnemyInstance)
signal attack_declared(pattern: EnemyAttackPattern)
signal attack_finished

@export var definition: EnemyDefinition

var health: Health


func _ready() -> void:
	if definition == null:
		push_error("EnemyInstance: brak przypisanego EnemyDefinition")
		return

	health = Health.new(definition.max_hp)
	health.died.connect(_on_died)


## Wywoływane przez GameStateManager/CombatManager na początku tury wroga.
func take_turn() -> void:
	if health.is_dead():
		return

	var pattern := _pick_attack_pattern()
	attack_declared.emit(pattern)

	for i in range(pattern.hits):
		PlayerData.health.take_damage(pattern.damage)

	attack_finished.emit()


func _pick_attack_pattern() -> EnemyAttackPattern:
	var patterns := definition.attack_patterns
	if patterns.is_empty():
		push_warning("EnemyInstance: brak attack_patterns w definicji %s" % definition.enemy_name)
		return null

	var total_weight := 0.0
	for p in patterns:
		total_weight += p.weight

	var roll := randf() * total_weight
	var cumulative := 0.0
	for p in patterns:
		cumulative += p.weight
		if roll <= cumulative:
			return p

	return patterns[-1]  # fallback na wypadek błędów zaokrągleń


func _on_died() -> void:
	died.emit(self)
	queue_free()
