class_name EnemyInstance
extends Node3D

signal died(enemy: EnemyInstance)
signal attack_declared(pattern: EnemyAttackPattern)
signal attack_finished

@onready var sprite_3d: Sprite3D = $Sprite3D

@export var definition: EnemyDefinition

var health: Health

func _ready() -> void:
	if definition == null:
		Log.error("EnemyInstance: brak przypisanego EnemyDefinition")
		return

	health = Health.new(definition.max_hp)
	health.died.connect(_on_died)
	sprite_3d.texture = definition.sprite

	DebugConsole.register_command("damage", _cmd_damage, "damage [ilość] - atakuje obecnego przeciwnika o X dmg")
	
func _exit_tree() -> void:
	DebugConsole.unregister_command("damage", _cmd_damage)

func _cmd_damage(args: Array) -> String:
	if args.size() <= 0:
		return "[color=red]Użycie: damage <ilość>[/color]"
	var amount: int = int(args[0])
	health.take_damage(amount)
	return "[color=green]Enemy dostał obrażenia warte %d[/color]" % amount
	
## Wywoływane przez GameStateManager/CombatManager na początku tury wroga.
func take_turn() -> void:
	if health.is_dead():
		return

	var pattern := _pick_attack_pattern()
	attack_declared.emit(pattern)

	for i in range(pattern.hits):
		PlayerData.take_damage(pattern.damage)

	attack_finished.emit()


func _pick_attack_pattern() -> EnemyAttackPattern:
	var patterns := definition.attack_patterns
	return RNG.weighted_pick(patterns)


func _on_died() -> void:
	died.emit(self)
	queue_free()
