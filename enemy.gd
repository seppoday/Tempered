class_name EnemyInstance
extends Control

signal died(enemy: EnemyInstance)
signal attack_declared(pattern: EnemyAttackPattern)
signal attack_finished

#@onready var sprite_3d: Sprite3D = $Sprite3D
#@onready var health_bar_fill: MeshInstance3D = %HealthBarFill
#@onready var attack_label: Label3D = %AttackLabel
#@onready var hp_label: Label3D = %HPLabel

@onready var enemy_texture_rect: TextureRect = %EnemyTextureRect
@onready var enemy_hp_current: Label = %EnemyHpCurrent
@onready var enemy_shield_current: Label = %EnemyShieldCurrent
@onready var enemy_hp_progress_bar: ProgressBar = %EnemyHpProgressBar
@onready var enemy_shield_progress_bar: ProgressBar = %EnemyShieldProgressBar
@onready var enemy_hp_max: Label = %EnemyHpMax
@onready var enemy_shield_max: Label = %EnemyShieldMax
@onready var enemy_dmg: Label = $MarginContainer/EnemyDmg


@export var definition: EnemyDefinition # Tutaj mamy już damage_growth

#const HEALTH_BAR_WIDTH: float = 1.0

var _shield_tween: Tween
var _hp_tween: Tween

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
	enemy_texture_rect.texture = definition.sprite
	
	_on_health_changed(health.current, health.max_hp)
	_update_attack_label()

	enemy_hp_max.text = str(health.max_hp)
	DebugConsole.register_command("damage", _cmd_damage, "damage [ilość] - atakuje obecnego przeciwnika o X dmg")


func _on_health_changed(current: int, max_hp: int) -> void:
	enemy_hp_progress_bar.max_value = max_hp
	enemy_hp_current.text = str(current)
	enemy_hp_max.text = str(max_hp)
	
	# Zawsze zatrzymaj poprzedni tween zanim stworzysz nowy
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()

	_hp_tween = create_tween()
	_hp_tween.tween_property(enemy_hp_progress_bar, "value", float(current), 0.25)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func _on_shield_changed(current: int, max_shield: int) -> void:
	enemy_shield_progress_bar.max_value = max_shield
	enemy_shield_current.text = str(current)
	enemy_shield_max.text = str(max_shield)

	# Zawsze zatrzymaj poprzedni tween zanim stworzysz nowy
	if _shield_tween != null and _shield_tween.is_valid():
		_shield_tween.kill()

	_shield_tween = create_tween()
	_shield_tween.tween_property(enemy_shield_progress_bar, "value", float(current), 0.25)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


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
	if enemy_dmg == null:
		return
	if definition.attack_patterns.size() > 0:
		var base_dmg: int = definition.attack_patterns[0].damage
		var effective: int = get_effective_damage(base_dmg)
		enemy_dmg.text = "DMG: %d" % effective


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
	EventBus.enemy_died.emit(self)
	Utilities.safe_free(self)
