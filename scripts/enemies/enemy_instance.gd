class_name EnemyInstance
extends Node3D

signal died(enemy: EnemyInstance)
signal attack_declared(pattern: EnemyAttackPattern)
signal attack_finished

@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var health_bar_fill: MeshInstance3D = %HealthBarFill

@export var definition: EnemyDefinition

const HEALTH_BAR_WIDTH: float = 1.0  # musi się zgadzać z szerokością QuadMesh w scenie

var health: Health

func _ready() -> void:
	if definition == null:
		Log.error("EnemyInstance: brak przypisanego EnemyDefinition")
		return

	health = Health.new(definition.max_hp)
	health.died.connect(_on_died)
	health.changed.connect(_on_health_changed)
	sprite_3d.texture = definition.sprite

	_on_health_changed(health.current, health.max_hp)  # ustaw pasek od razu na starcie

	DebugConsole.register_command("damage", _cmd_damage, "damage [ilość] - atakuje obecnego przeciwnika o X dmg")


func _on_health_changed(current: int, max_hp: int) -> void:
	var percentage: float = float(current) / float(max_hp) if max_hp > 0 else 0.0
	health_bar_fill.scale.x = percentage
	# przesunięcie w lewo o połowę "ubytku", żeby pasek opróżniał się od prawej,
	# a nie kurczył symetrycznie do środka
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
	Utilities.safe_free(self)
