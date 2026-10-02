class_name EnemyInstance
extends Node3D

signal died(enemy: EnemyInstance)
signal attack_declared(pattern: EnemyAttackPattern)
signal attack_finished

@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var health_bar_fill: MeshInstance3D = %HealthBarFill
@onready var attack_label: Label3D = %AttackLabel

@export var definition: EnemyDefinition # Tutaj mamy już damage_growth

const HEALTH_BAR_WIDTH: float = 1.0

var health: Health
var armor_debuff: float = 0.0
var turn_count: int = 0 # Licznik tur zostaje tutaj (bo jest unikalny dla tej konkretnej instancji w walce)

var status_manager: StatusManager = StatusManager.new()


func _ready() -> void:
	if definition == null:
		Log.error("EnemyInstance: brak przypisanego EnemyDefinition")
		return

	health = Health.new(definition.max_hp)
	health.died.connect(_on_died)
	health.changed.connect(_on_health_changed)
	sprite_3d.texture = definition.sprite

	_on_health_changed(health.current, health.max_hp)
	_update_attack_label()

	DebugConsole.register_command("damage", _cmd_damage, "damage [ilość] - atakuje obecnego przeciwnika o X dmg")


func _on_health_changed(current: int, max_hp: int) -> void:
	var percentage: float = float(current) / float(max_hp) if max_hp > 0 else 0.0
	health_bar_fill.scale.x = percentage
	health_bar_fill.position.x = -(HEALTH_BAR_WIDTH * 0.5) * (1.0 - percentage)
	print(current)


func _exit_tree() -> void:
	DebugConsole.unregister_command("damage", _cmd_damage)


func _cmd_damage(args: Array) -> String:
	if args.size() <= 0:
		return "[color=red]Użycie: damage <ilość>[/color]"
	var amount: int = int(args[0])
	health.take_damage(amount)
	return "[color=green]Enemy dostał obrażenia warte %d[/color]" % amount


# Pobieramy damage_growth bezpośrednio z definicji
func get_effective_damage(base_damage: int) -> int:
	var growth = definition.damage_growth if "damage_growth" in definition else 1
	return base_damage + (turn_count * growth)


func _update_attack_label() -> void:
	if attack_label == null:
		return
	if definition.attack_patterns.size() > 0:
		var base_dmg: int = definition.attack_patterns[0].damage
		var effective: int = get_effective_damage(base_dmg)
		attack_label.text = "DMG: %d" % effective


func take_turn() -> void:
	if health.is_dead():
		return

	var pattern := _pick_attack_pattern()
	var effective_dmg: int = get_effective_damage(pattern.damage)
	
	var modified_pattern: EnemyAttackPattern = pattern.duplicate()
	modified_pattern.damage = effective_dmg
	
	attack_declared.emit(modified_pattern)

	for i in range(modified_pattern.hits):
		PlayerData.take_damage(modified_pattern.damage)

	turn_count += 1
	_update_attack_label()

	attack_finished.emit()


func _pick_attack_pattern() -> EnemyAttackPattern:
	var patterns := definition.attack_patterns
	return RNG.weighted_pick(patterns)


func get_effective_armor() -> float:
	var base_armor: float = 0.0
	if "def" in definition:
		base_armor = definition.def
	elif "armor" in definition:
		base_armor = definition.armor
	return max(0.0, base_armor - armor_debuff)


func _on_died() -> void:
	status_manager.clear_all()
	died.emit(self)
	Utilities.safe_free(self)
