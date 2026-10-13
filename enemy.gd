class_name EnemyInstance
extends Control

signal died(enemy: EnemyInstance)
signal attack_declared(pattern: EnemyAttackPattern)
signal attack_finished

@onready var enemy_texture_rect: TextureRect = %EnemyTextureRect
@onready var enemy_hp_current: Label = %EnemyHpCurrent
@onready var enemy_shield_current: Label = %EnemyShieldCurrent
@onready var enemy_hp_progress_bar: ProgressBar = %EnemyHpProgressBar
@onready var enemy_shield_progress_bar: ProgressBar = %EnemyShieldProgressBar
@onready var enemy_hp_max: Label = %EnemyHpMax
@onready var enemy_shield_max: Label = %EnemyShieldMax
@onready var enemy_dmg: Label = $MarginContainer/EnemyDmg
@onready var status_label: Label = %StatusLabel

@export var definition: EnemyDefinition

var _shield_tween: Tween
var _hp_tween: Tween

var _pending_pattern: EnemyAttackPattern

var health: Health
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
	
	status_manager.status_applied.connect(_on_status_changed)
	status_manager.status_removed.connect(_on_status_changed)
	refresh_status_label()
	
	_on_health_changed(health.current, health.max_hp)
	_pending_pattern = _pick_attack_pattern()
	_update_attack_label()

	enemy_hp_max.text = str(health.max_hp)
	DebugConsole.register_command("damage", _cmd_damage, "damage [ilość] - atakuje obecnego przeciwnika o X dmg")

func _on_status_changed(_status: StatusEffect) -> void:
	refresh_status_label()


func refresh_status_label() -> void:
	if status_label == null:
		return

	if status_manager.active_statuses.is_empty():
		status_label.text = ""
		return

	var lines: Array[String] = []
	for status in status_manager.active_statuses:
		var status_name: String = GameEnums.StatusType.keys()[status.status_type].capitalize()
		var icon := _get_status_icon(status.status_type)
		var tick_dmg := int(round(status.get_total_tick_damage()))
		var stacks_suffix := " x%d" % status.stacks if status.stacks > 1 else ""
		lines.append("%s %s%s (%d) — %d dmg" % [icon, status_name, stacks_suffix, status.remaining_rounds, tick_dmg])

	status_label.text = "\n".join(lines)


func _get_status_icon(status_type: GameEnums.StatusType) -> String:
	match status_type:
		GameEnums.StatusType.BURN:
			return "🔥"
		GameEnums.StatusType.POISON:
			return "☠"
		GameEnums.StatusType.BLEED:
			return "🩸"
		_:
			return "●"
			
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


func _update_attack_label() -> void:
	if enemy_dmg == null:
		return
	if _pending_pattern == null or _pending_pattern.skill == null:
		enemy_dmg.text = ""
		return

	var skill: SkillDefinition = _pending_pattern.skill
	var value := CombatManager.calculate_enemy_effect_value(skill, self)
	var label_text := _get_effect_label(skill.effect_type)

	enemy_dmg.text = "%s: %d" % [label_text, int(round(value))]


func _get_effect_label(effect_type: GameEnums.SkillEffect) -> String:
	match effect_type:
		GameEnums.SkillEffect.DAMAGE:
			return "DMG"
		GameEnums.SkillEffect.HEAL:
			return "HEAL"
		GameEnums.SkillEffect.SHIELD:
			return "SHIELD"
		_:
			return "?"


func take_turn() -> void:
	if health.is_dead():
		return

	var pattern := _pending_pattern
	if pattern == null:
		pattern = _pick_attack_pattern()

	if pattern == null or pattern.skill == null:
		Log.warning("EnemyInstance: brak poprawnego attack pattern/skilla")
		attack_finished.emit()
		return

	attack_declared.emit(pattern)
	await CombatManager.resolve_enemy_attack(pattern, self)

	turn_count += 1
	_pending_pattern = _pick_attack_pattern()
	_update_attack_label()

	attack_finished.emit()


func _pick_attack_pattern() -> EnemyAttackPattern:
	var patterns := definition.attack_patterns
	return RNG.weighted_pick(patterns)


func get_effective_armor() -> float:
	return max(0.0, definition.def)


func _on_died() -> void:
	status_manager.clear_all()
	died.emit(self)
	EventBus.enemy_died.emit(self)
	Utilities.safe_free(self)
