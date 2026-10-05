extends Node

#region Sygnały
signal enemy_changed(enemy: EnemyInstance)
signal player_died
signal enemy_died(enemy: EnemyInstance)
signal effect_applied(skill: SkillDefinition, value: int, target: String)
signal buff_applied_to_player(buff_name: String, value_text: String)
signal player_attack_finished
signal status_applied_to_enemy(status_name: String)
signal status_tick_on_enemy(status_name: String, damage: int)
#endregion

#region Ustawienia i stan
@export var delay_between_effects: float = 0.35
var current_turn_damage_bonus: float = 0.0
var next_attack_crit_multiplier: float = 1.0
## Indeks aktualnie rozpatrywanego skilla.
var current_result_index: int = 0
var current_enemy: EnemyInstance:
	set(value):
		if current_enemy == value: return
		if current_enemy != null and current_enemy.died.is_connected(_on_current_enemy_died):
			current_enemy.died.disconnect(_on_current_enemy_died)
		current_enemy = value
		if current_enemy != null:
			current_enemy.died.connect(_on_current_enemy_died)
		enemy_changed.emit(current_enemy)
var is_game_over: bool = false
#endregion

#region Inicjalizacja
## Inicjalizuje CombatManager i rejestruje komendę debugową `kill`.
func _ready() -> void:
	PlayerData.health.died.connect(_on_player_died)
	DebugConsole.register_command("kill", _cmd_kill_enemy, "kill = zabija bieżącego wroga")

## Zabija aktualnego przeciwnika za pomocą komendy debugowej.
func _cmd_kill_enemy(_args: Array) -> String:
	if current_enemy == null: return "[color=red]Brak aktywnego wroga[/color]"
	current_enemy.health.take_damage(current_enemy.health.max_hp)
	return "[color=green]Wróg zabity[/color]"

## Ustawia aktualnego przeciwnika.
func set_enemy(enemy: EnemyInstance) -> void:
	current_enemy = enemy
	Log.print("Następny wróg: %s, HP: %s" % [current_enemy.definition.enemy_name, current_enemy.definition.max_hp])
#endregion

#region Statystyki gracza
## Pobiera wartość statystyki z całkowitych statystyk gracza.
func _get_player_stat(stats: Dictionary, stat: GameEnums.Stat) -> float:
	var key: String = GameEnums.Stat.keys()[stat].to_lower()
	if not stats.has(key):
		Log.warning("CombatManager: brak statystyki '%s' w get_total_stats()" % key)
		return 0.0
	return float(stats[key])
#endregion

#region Główna pętla ataku
## Rozpatruje wszystkie wyniki wybranego ataku gracza.
func resolve_player_attack(selected_results: Array[Dictionary]) -> void:
	if is_game_over: return
	current_turn_damage_bonus = 0.0
	next_attack_crit_multiplier = 1.0
	var target := current_enemy
	for i in selected_results.size():
		if is_game_over or current_enemy == null or current_enemy != target: break
		var result: Dictionary = selected_results[i]
		current_result_index = i
		var skill: SkillDefinition = result["skill"]
		var item_instance: ItemInstance = result["item"]
		var rolled_face: int = result["face"]
		var max_face: int = GameEnums.DICE_PROGRESSION[item_instance.dice_level]
		var context := build_trigger_context(rolled_face, max_face)
		var effective_base := get_effective_base(skill, context)
		var value := calculate_effect_value(skill, item_instance.definition, rolled_face, effective_base, true)
		var hit_count := _calculate_hit_count(skill)
		Log.print("face=%d/%d → value=%.1f (hits: %d)" % [rolled_face, max_face, value, hit_count])
		for _hit in range(hit_count):
			match skill.effect_type:
				GameEnums.SkillEffect.DAMAGE:
					_apply_damage_to_enemy(skill, int(round(value)))
					_process_on_hit_triggers(skill, context, item_instance.definition, rolled_face)
				GameEnums.SkillEffect.HEAL: _apply_heal_to_player(skill, int(round(value)))
				GameEnums.SkillEffect.SHIELD: _apply_shield_to_player(skill, int(round(value)))
				GameEnums.SkillEffect.GOLD: _apply_gold_to_player(skill, int(round(value)))
				GameEnums.SkillEffect.BUFF_CRIT: _apply_crit_buff(skill, value)
				GameEnums.SkillEffect.BUFF_DAMAGE: _apply_damage_buff(skill, value)
				GameEnums.SkillEffect.DEBUFF_ARMOR: _apply_armor_debuff_to_enemy(skill, int(round(value)))
				_: Log.warning("CombatManager: nieobsłużony effect_type %s" % skill.effect_type)
			if current_enemy == null or current_enemy != target or is_game_over: break
			if delay_between_effects > 0.0:
				await get_tree().create_timer(delay_between_effects).timeout
	_tick_enemy_statuses()
	player_attack_finished.emit()

## Oblicza efektywną wartość bazową po uwzględnieniu aktywnych triggerów.
func get_effective_base(skill: SkillDefinition, context: Dictionary) -> float:
	var base := skill.base_value
	for trigger in skill.triggers:
		if trigger.base_value_override > 0.0 and trigger.should_activate(context):
			base *= trigger.base_value_override
			Log.print("Trigger %s → base ×%.2f = %.2f" % [GameEnums.TriggerType.keys()[trigger.trigger_type], trigger.base_value_override, base])
	return base
#endregion

#region Triggery i statusy
## Buduje kontekst używany do sprawdzania triggerów.
func build_trigger_context(rolled_face: int, max_face: int) -> Dictionary:
	var caster_hp_ratio: float = 1.0
	if PlayerData.health.max_hp > 0:
		caster_hp_ratio = float(PlayerData.health.current) / float(PlayerData.health.max_hp)
	var target_hp_ratio: float = 1.0
	if current_enemy != null and current_enemy.health.max_hp > 0:
		target_hp_ratio = float(current_enemy.health.current) / float(current_enemy.health.max_hp)
	return {"face": rolled_face, "max_face": max_face, "caster_hp_ratio": caster_hp_ratio, "target_hp_ratio": target_hp_ratio}

## Nakłada statusy wynikające z aktywnych triggerów po trafieniu.
func _process_on_hit_triggers(skill: SkillDefinition, context: Dictionary, item: ItemDefinition, rolled_face: int) -> void:
	if current_enemy == null: return
	for trigger in skill.triggers:
		if not trigger.should_activate(context): continue
		if trigger.trigger_type in [GameEnums.TriggerType.ON_HIT, GameEnums.TriggerType.ON_HIGH_ROLL, GameEnums.TriggerType.ON_MAX_ROLL]:
			for _i in range(trigger.status_stacks):
				var status := _create_status_from_trigger(trigger, item, rolled_face)
				current_enemy.status_manager.apply_status(status)
				status_applied_to_enemy.emit(GameEnums.StatusType.keys()[status.status_type])

## Tworzy StatusEffect na podstawie triggera i statystyk gracza.
func _create_status_from_trigger(trigger: SkillTrigger, _item: ItemDefinition, dice_roll: int) -> StatusEffect:
	var status_type := trigger.apply_status
	var tick := 0.0
	var initial := 0.0
	var duration := 3
	var player_stats := PlayerData.get_total_stats()
	match status_type:
		GameEnums.StatusType.BURN:
			var stat_status := _get_player_stat(player_stats, GameEnums.Stat.STATUS)
			tick = stat_status * 0.4 * dice_roll
			duration = 3 + int(floor(stat_status / 20.0))
		GameEnums.StatusType.POISON:
			var stat_magic := _get_player_stat(player_stats, GameEnums.Stat.MAGIC)
			var stat_status := _get_player_stat(player_stats, GameEnums.Stat.STATUS)
			initial = stat_magic * 0.3 * dice_roll
			tick = stat_status * 0.6 * dice_roll
			duration = 4
		GameEnums.StatusType.BLEED:
			var stat_dmg := _get_player_stat(player_stats, GameEnums.Stat.DMG)
			tick = stat_dmg * 0.25
			duration = 3
	return StatusEffect.new(status_type, duration, tick, initial)

## Wykonuje tick statusów przeciwnika i zadaje obrażenia DoT.
func _tick_enemy_statuses() -> void:
	if current_enemy == null or current_enemy.health.is_dead(): return
	var ticks := current_enemy.status_manager.tick_all()
	for tick_data in ticks:
		var dmg: int = tick_data["damage"]
		var status_type: GameEnums.StatusType = tick_data["type"]
		var status_name: String = GameEnums.StatusType.keys()[status_type]
		if dmg > 0:
			current_enemy.health.take_damage(dmg)
			status_tick_on_enemy.emit(status_name, dmg)
			Log.print("DoT [%s]: %d obrażeń" % [status_name, dmg])
		if current_enemy == null: return
#endregion

#region Kalkulator wartości
## Oblicza końcową wartość efektu skilla z uwzględnieniem skalowania i modyfikatorów.
func calculate_effect_value(skill: SkillDefinition, item: ItemDefinition, dice_roll: int, base_override: float = -1.0, apply_modifiers: bool = false) -> float:
	var effective_base := base_override if base_override > 0.0 else skill.base_value
	var player_stats := PlayerData.get_total_stats()
	var stat_scaling: float = 0.0
	if skill.scalings.is_empty():
		stat_scaling = 1.0
	else:
		for scaling in skill.scalings:
			stat_scaling += _get_player_stat(player_stats, scaling.stat) * scaling.weight
	var affinity_multiplier: float = item.get_affinity_multiplier(skill.damage_element)
	var final_value: float = effective_base * dice_roll * stat_scaling * affinity_multiplier
	if apply_modifiers and skill.effect_type == GameEnums.SkillEffect.DAMAGE:
		if current_turn_damage_bonus > 0.0:
			final_value *= 1.0 + current_turn_damage_bonus
			Log.print("Buff damage: +%.0f%%" % (current_turn_damage_bonus * 100.0))
		if next_attack_crit_multiplier > 1.0:
			final_value *= next_attack_crit_multiplier
			Log.print("CRIT! x%.2f" % next_attack_crit_multiplier)
			next_attack_crit_multiplier = 1.0
	Log.print("=== SKILL VALUE ===\nBase: %.2f | Roll: %d | Scaling: %.2f | Affinity: %.2f | Final: %.2f" % [effective_base, dice_roll, stat_scaling, affinity_multiplier, final_value])
	return final_value

## Oblicza liczbę trafień na podstawie statystyki gracza.
func _calculate_hit_count(skill: SkillDefinition) -> int:
	if skill.bonus_hits_per_stat == null: return 1
	var stats := PlayerData.get_total_stats()
	var bonus: float = _get_player_stat(stats, skill.bonus_hits_per_stat.stat) * skill.bonus_hits_per_stat.weight
	return 1 + int(floor(bonus))
#endregion

#region Tura przeciwnika
## Rozpoczyna turę aktualnego przeciwnika.
func enemy_take_turn() -> void:
	if is_game_over: return
	if current_enemy == null:
		Log.warning("CombatManager: brak current_enemy, pomijam turę wroga")
		return
	current_enemy.take_turn()
#endregion

#region Aplikacja efektów
## Zadaje przeciwnikowi obrażenia po uwzględnieniu pancerza.
func _apply_damage_to_enemy(skill: SkillDefinition, value: int) -> void:
	if current_enemy == null:
		Log.warning("CombatManager: brak wroga, pomijam %d dmg" % value)
		return
	var effective_armor: float = current_enemy.get_effective_armor()
	var reduction: float = effective_armor / (effective_armor + 100.0)
	var final_damage: int = int(round(value * (1.0 - reduction)))
	if reduction > 0.0:
		Log.print("Pancerz wroga: %.0f → redukcja %.1f%% → dmg %d → %d" % [effective_armor, reduction * 100.0, value, final_damage])
	current_enemy.health.take_damage(final_damage)
	effect_applied.emit(skill, final_damage, "enemy")

## Leczy gracza.
func _apply_heal_to_player(skill: SkillDefinition, value: int) -> void:
	PlayerData.health.heal(value)
	effect_applied.emit(skill, value, "player")

## Dodaje graczowi block.
func _apply_shield_to_player(skill: SkillDefinition, value: int) -> void:
	PlayerData.add_block(float(value))
	effect_applied.emit(skill, value, "player")
	Log.print("Gracz zyskał %d block" % value)

## Dodaje graczowi złoto.
func _apply_gold_to_player(skill: SkillDefinition, value: int) -> void:
	MetaProgressionManager.add_gold(value)
	effect_applied.emit(skill, value, "player")
	Log.print("Gracz zyskał %d złota" % value)

## Nakłada buff krytycznego trafienia na następny atak.
func _apply_crit_buff(_skill: SkillDefinition, value: float) -> void:
	next_attack_crit_multiplier = max(next_attack_crit_multiplier, value)
	buff_applied_to_player.emit("CRIT", "x%.2f" % value)
	Log.print("Crit buff: x%.2f do następnego ataku" % value)

## Dodaje bonus obrażeń na bieżącą turę.
func _apply_damage_buff(_skill: SkillDefinition, value: float) -> void:
	current_turn_damage_bonus += value
	buff_applied_to_player.emit("DAMAGE", "+%.0f%%" % (value * 100.0))
	Log.print("Damage buff: +%.0f%% na tę turę" % (value * 100.0))

## Nakłada debuff pancerza na przeciwnika.
func _apply_armor_debuff_to_enemy(skill: SkillDefinition, value: int) -> void:
	if current_enemy == null: return
	current_enemy.armor_debuff += float(value)
	effect_applied.emit(skill, value, "enemy")
	Log.print("Armor debuff: -%d (łącznie -%.0f)" % [value, current_enemy.armor_debuff])
#endregion

#region Nagrody i koniec gry
## Obsługuje śmierć przeciwnika, generuje nagrody i emituje sygnał.
func _on_current_enemy_died(enemy: EnemyInstance) -> void:
	Log.print("Wróg pokonany: %s" % enemy.definition.enemy_name)
	RewardManager.generate_rewards(enemy.definition)
	current_enemy = null
	enemy_died.emit(enemy)

## Obsługuje śmierć gracza i kończy grę.
func _on_player_died() -> void:
	if is_game_over: return
	is_game_over = true
	Log.print("PRZEGRANA — gracz zginął")
	player_died.emit()
#endregion
