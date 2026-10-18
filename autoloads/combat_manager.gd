extends Node

#region Sygnały
signal enemy_changed(enemy: EnemyInstance)
signal player_died
signal enemy_died(enemy: EnemyInstance)
signal effect_applied(skill: SkillDefinition, value: int, target: String, source: String)
signal buff_applied_to_player(buff_name: String, value_text: String)
signal player_attack_finished
signal status_applied_to_enemy(status_name: String)
signal status_tick_on_enemy(status_name: String, damage: int)
signal status_applied_to_player(status_name: String)
signal status_tick_on_player(status_name: String, damage: int)
#endregion

#region Ustawienia i stan
@export var delay_between_effects: float = 0.35
var permanent_damage_bonus: float = 0.0  # TODO: wyzeruj tam, gdzie zaczynacie nową walkę
## Indeks aktualnie rozpatrywanego skilla.
var current_result_index: int = 0
var current_enemy: EnemyInstance:
	set(value):
		if current_enemy == value:
			return
		if current_enemy != null and current_enemy.died.is_connected(_on_current_enemy_died):
			current_enemy.died.disconnect(_on_current_enemy_died)
		current_enemy = value
		if current_enemy != null:
			current_enemy.died.connect(_on_current_enemy_died)
		enemy_changed.emit(current_enemy)
var is_game_over: bool = false
#endregion

#region Inicjalizacja
func _ready() -> void:
	PlayerData.health.died.connect(_on_player_died)
	DebugConsole.register_command("kill", _cmd_kill_enemy, "kill = zabija bieżącego wroga")


func _cmd_kill_enemy(_args: Array) -> String:
	if current_enemy == null:
		return "[color=red]Brak aktywnego wroga[/color]"
	current_enemy.health.take_damage(current_enemy.health.max_hp)
	return "[color=green]Wróg zabity[/color]"


func set_enemy(enemy: EnemyInstance) -> void:
	current_enemy = enemy
	permanent_damage_bonus = 0.0
	Log.print("Następny wróg: %s, HP: %s" % [current_enemy.definition.enemy_name, current_enemy.definition.max_hp])
#endregion

#region Statystyki gracza
func _get_player_stat(stats: Dictionary, stat: GameEnums.Stat) -> float:
	var key: String = GameEnums.Stat.keys()[stat].to_lower()
	if not stats.has(key):
		Log.warning("CombatManager: brak statystyki '%s' w get_total_stats()" % key)
		return 0.0
	return float(stats[key])
#endregion

#region Główna pętla ataku
func resolve_player_attack(selected_results: Array[Dictionary]) -> void:
	if is_game_over:
		return
	var target := current_enemy
	for i in selected_results.size():
		if is_game_over or current_enemy == null or current_enemy != target:
			break
		var result: Dictionary = selected_results[i]
		current_result_index = i
		var skill: SkillDefinition = result["skill"]
		var item_instance: ItemInstance = result["item"]
		var rolled_face: int = result["face"]
		var dice_level: int = item_instance.dice_level
		var max_face: int = GameEnums.DICE_PROGRESSION[dice_level]
		var context := build_trigger_context(rolled_face, max_face)
		var value := calculate_effect_value(skill, item_instance.definition, rolled_face, dice_level)
		var pre := _resolve_pre_hit_triggers(skill, item_instance.definition, context, value, dice_level)
		value = pre["value"]
		var ignore_shield: bool = pre["ignore_shield"]
		var hit_count := _calculate_hit_count(skill)
		Log.print("face=%d/%d → value=%.1f (hits: %d)" % [rolled_face, max_face, value, hit_count])
		for _hit in range(hit_count):
			match skill.effect_type:
				GameEnums.SkillEffect.DAMAGE:
					_apply_damage_to_enemy(skill, int(round(value)), ignore_shield)
				GameEnums.SkillEffect.HEAL:
					_apply_heal_to_player(skill, int(round(value)))
				GameEnums.SkillEffect.SHIELD:
					_apply_shield_to_player(skill, int(round(value)))
				GameEnums.SkillEffect.GOLD:
					_apply_gold_to_player(skill, int(round(value)))
				GameEnums.SkillEffect.CLEANSE:
					_apply_cleanse_to_player(skill)
				_:
					Log.warning("CombatManager: nieobsłużony effect_type %s" % skill.effect_type)
			var enemy_died := current_enemy == null or (current_enemy.health != null and current_enemy.health.current <= 0)
			var post_context := build_trigger_context(rolled_face, max_face, enemy_died)
			_apply_post_hit_triggers(skill, post_context, value, item_instance.definition, enemy_died, dice_level)
			if current_enemy == null or current_enemy != target or is_game_over:
				break
			if delay_between_effects > 0.0:
				await get_tree().create_timer(delay_between_effects).timeout
	_tick_enemy_statuses()
	player_attack_finished.emit()
#endregion

#region Triggery i statusy
func build_trigger_context(rolled_face: int, max_face: int, enemy_dead: bool = false) -> Dictionary:
	var caster_hp_ratio: float = 1.0
	if PlayerData.health.max_hp > 0:
		caster_hp_ratio = float(PlayerData.health.current) / float(PlayerData.health.max_hp)
	var target_hp_ratio: float = 1.0
	if enemy_dead:
		target_hp_ratio = 0.0
	elif current_enemy != null and current_enemy.health.max_hp > 0:
		target_hp_ratio = float(current_enemy.health.current) / float(current_enemy.health.max_hp)
	return {
		"face": rolled_face,
		"max_face": max_face,
		"caster_hp_ratio": caster_hp_ratio,
		"target_hp_ratio": target_hp_ratio,
	}


func _create_status_from_trigger(trigger: SkillTriggerBase, item: ItemDefinition, dice_roll: int, dice_level: int = 0) -> StatusEffect:
	var status_type := trigger.apply_status
	var tick := 0.0
	var initial := 0.0
	var duration := 3
	match status_type:
		GameEnums.StatusType.BURN:
			var stat_status := item.get_stat(GameEnums.Stat.STATUS, dice_level)
			tick = stat_status * 0.4 * dice_roll
			duration = 3 + int(floor(stat_status / 20.0))
		GameEnums.StatusType.POISON:
			var stat_magic := item.get_stat(GameEnums.Stat.MAGIC, dice_level)
			var stat_status := item.get_stat(GameEnums.Stat.STATUS, dice_level)
			initial = stat_magic * 0.3 * dice_roll
			tick = stat_status * 0.6 * dice_roll
			duration = 4
		GameEnums.StatusType.BLEED:
			var stat_dmg := item.get_stat(GameEnums.Stat.DMG, dice_level)
			tick = stat_dmg * 0.25
			duration = 3
	return StatusEffect.new(status_type, duration, tick, initial)


func _tick_enemy_statuses() -> void:
	if current_enemy == null or current_enemy.health.is_dead():
		return
	var ticks := current_enemy.status_manager.tick_all()
	for tick_data in ticks:
		var dmg: int = tick_data["damage"]
		var status_type: GameEnums.StatusType = tick_data["type"]
		var status_name: String = GameEnums.StatusType.keys()[status_type]
		if dmg > 0:
			current_enemy.health.take_damage(dmg)
			status_tick_on_enemy.emit(status_name, dmg)
			Log.print("DoT [%s]: %d obrażeń" % [status_name, dmg])
		if current_enemy == null:
			return
	if current_enemy != null:
		current_enemy.refresh_status_label()
#endregion

#region Kalkulator wartości
func calculate_effect_value(skill: SkillDefinition, item: ItemDefinition, dice_roll: int, dice_level: int = 0) -> float:
	if skill.scalings.is_empty():
		Log.warning("Skill '%s' nie ma scalingu — wynik = 0" % skill.skill_name)
		return 0.0
	var primary := skill.scalings[0]
	var inner_sum: float = item.get_stat(primary.stat, dice_level)
	for i in range(1, skill.scalings.size()):
		var secondary := skill.scalings[i]
		inner_sum += item.get_stat(secondary.stat, dice_level) * secondary.weight
	var final_value: float = dice_roll * primary.weight * inner_sum
	if skill.element_synergy_bonus > 0.0:
		var synergy_count := _count_equipped_skills_with_element(skill.damage_element, skill)
		if synergy_count > 0:
			final_value += synergy_count * skill.element_synergy_bonus
	Log.print("=== SKILL VALUE ===\nRoll: %d | lvl: %d | weight: %.2f | item_sum: %.2f | final: %.2f" % [
		dice_roll, dice_level, primary.weight, inner_sum, final_value
	])
	return final_value


func _count_equipped_skills_with_element(element: GameEnums.DamageElement, exclude_skill: SkillDefinition) -> int:
	var count := 0
	for item_instance in PlayerData.equipped_items.values():
		if item_instance == null or item_instance.definition == null or item_instance.definition.default_skill == null:
			continue
		var equipped_skill: SkillDefinition = item_instance.definition.default_skill
		if equipped_skill == exclude_skill:
			continue
		if equipped_skill.damage_element == element:
			count += 1
	return count


func _trigger_condition_met(trigger: SkillTriggerBase, context: Dictionary, enemy_died: bool) -> bool:
	match trigger.trigger_type:
		GameEnums.TriggerType.ON_HIT:
			return true
		GameEnums.TriggerType.ON_ROLL_AT_LEAST:
			return context["face"] >= trigger.threshold
		GameEnums.TriggerType.ON_ROLL_AT_MOST:
			return context["face"] <= trigger.threshold
		GameEnums.TriggerType.ON_MAX_ROLL:
			return context["face"] == context["max_face"]
		GameEnums.TriggerType.ON_LOW_ROLL:
			return context["face"] == 1
		GameEnums.TriggerType.ON_KILL:
			return enemy_died
		GameEnums.TriggerType.ON_SELF_HP_BELOW:
			return context["caster_hp_ratio"] <= trigger.threshold
		GameEnums.TriggerType.ON_TARGET_HP_BELOW:
			return context["target_hp_ratio"] <= trigger.threshold
		GameEnums.TriggerType.ON_TARGET_STATUS:
			if current_enemy == null:
				return false
			for status in trigger.required_target_statuses:
				if current_enemy.status_manager.has_status(status):
					return true
			return false
		GameEnums.TriggerType.ON_ROLL_PERCENT_AT_LEAST:
			return float(context["face"]) / float(context["max_face"]) >= trigger.threshold
		GameEnums.TriggerType.ON_ROLL_PERCENT_AT_MOST:
			return float(context["face"]) / float(context["max_face"]) <= trigger.threshold
		_:
			return false


func _pay_hp_cost(trigger: SkillTriggerBase) -> void:
	if trigger.hp_cost > 0.0:
		PlayerData.health.take_damage(int(round(trigger.hp_cost)))
		Log.print("Trigger koszt: -%d HP" % int(round(trigger.hp_cost)))


func _apply_trigger_status_to_enemy(trigger: SkillTriggerBase, item_def: ItemDefinition, rolled_face: int, dice_level: int = 0) -> void:
	if current_enemy == null:
		return
	for _i in range(trigger.status_stacks):
		var status := _create_status_from_trigger(trigger, item_def, rolled_face, dice_level)
		if status.get_total_tick_damage() <= 0:
			continue
		current_enemy.status_manager.apply_status(status)
		status_applied_to_enemy.emit(GameEnums.StatusType.keys()[status.status_type])


func _apply_trigger_status_to_player(trigger: SkillTriggerBase, enemy: EnemyInstance) -> void:
	for _i in range(trigger.status_stacks):
		var status := _create_status_from_enemy_trigger(trigger, enemy)
		if status.get_total_tick_damage() <= 0:
			continue
		PlayerData.status_manager.apply_status(status)
		status_applied_to_player.emit(GameEnums.StatusType.keys()[status.status_type])


func _resolve_pre_hit_triggers(skill: SkillDefinition, item_def: ItemDefinition, context: Dictionary, base_value: float, dice_level: int = 0) -> Dictionary:
	var hit_data := {
		"skill": skill,
		"item_def": item_def,
		"context": context,
		"value": base_value,
		"ignore_shield": false,
		"dice_level": dice_level,
	}
	for trigger in skill.triggers:
		if not trigger.is_pre_hit():
			continue
		if not _trigger_condition_met(trigger, context, false):
			continue
		if not trigger.should_fire(hit_data):
			continue
		_pay_hp_cost(trigger)
		trigger.apply(self, hit_data)
		_apply_trigger_status_to_enemy(trigger, item_def, context["face"], dice_level)
	return {"value": hit_data["value"], "ignore_shield": hit_data["ignore_shield"]}


func _resolve_enemy_pre_hit_triggers(skill: SkillDefinition, enemy: EnemyInstance, context: Dictionary, base_value: float) -> Dictionary:
	var hit_data := {
		"skill": skill,
		"context": context,
		"enemy": enemy,
		"value": base_value,
		"ignore_shield": false,
		"target": "player",
	}
	for trigger in skill.triggers:
		if not trigger.is_pre_hit():
			continue
		if not trigger.is_valid_for_enemy_cast():
			Log.warning("Skill '%s' (enemy) ma pre-hit trigger %s, który nie jest przeznaczony dla wroga — pomijam" % [skill.skill_name, trigger.get_class()])
			continue
		if not _trigger_condition_met(trigger, context, false):
			continue
		if not trigger.should_fire(hit_data):
			continue
		trigger.apply(self, hit_data)
		_apply_trigger_status_to_player(trigger, enemy)
	return {"value": hit_data["value"], "ignore_shield": hit_data["ignore_shield"]}


func _apply_post_hit_triggers(skill: SkillDefinition, context: Dictionary, hit_value: float, item_def: ItemDefinition, enemy_died: bool, dice_level: int = 0) -> void:
	for trigger in skill.triggers:
		if trigger.is_pre_hit():
			continue
		if not _trigger_condition_met(trigger, context, enemy_died):
			continue
		var hit_data := {
			"skill": skill,
			"item_def": item_def,
			"context": context,
			"value": hit_value,
			"enemy_died": enemy_died,
			"target": "enemy",
			"dice_level": dice_level,
		}
		if not trigger.should_fire(hit_data):
			continue
		_pay_hp_cost(trigger)
		trigger.apply(self, hit_data)
		_apply_trigger_status_to_enemy(trigger, item_def, context["face"], dice_level)


func _apply_post_hit_triggers_to_player(skill: SkillDefinition, context: Dictionary, enemy: EnemyInstance, hit_value: float, player_died: bool) -> void:
	for trigger in skill.triggers:
		if trigger.is_pre_hit():
			continue
		if not trigger.is_valid_for_enemy_cast():
			Log.warning("Skill '%s' (enemy) ma trigger %s, który nie jest przeznaczony dla wroga — pomijam" % [skill.skill_name, trigger.get_class()])
			continue
		if not _trigger_condition_met(trigger, context, player_died):
			continue
		var hit_data := {
			"skill": skill,
			"context": context,
			"enemy": enemy,
			"value": hit_value,
			"player_died": player_died,
			"target": "player",
		}
		if not trigger.should_fire(hit_data):
			continue
		trigger.apply(self, hit_data)
		_apply_trigger_status_to_player(trigger, enemy)


func _apply_damage_to_enemy(skill: SkillDefinition, value: int, ignore_shield: bool = false) -> void:
	if current_enemy == null:
		Log.warning("CombatManager: brak wroga, pomijam %d dmg" % value)
		return
	var total_value := value + int(round(permanent_damage_bonus))
	# TODO: jeśli wróg ma mechanikę tarczy, tu pominąć ją gdy ignore_shield == true
	var effective_armor: float = current_enemy.get_effective_armor()
	var reduction: float = effective_armor / (effective_armor + 100.0)
	var final_damage: int = int(round(total_value * (1.0 - reduction)))
	if reduction > 0.0:
		Log.print("Pancerz wroga: %.0f → redukcja %.1f%% → dmg %d → %d" % [effective_armor, reduction * 100.0, total_value, final_damage])
	current_enemy.health.take_damage(final_damage)
	effect_applied.emit(skill, final_damage, "enemy", "player")
	_apply_lifesteal(final_damage)


func _kill_enemy(skill: SkillDefinition) -> void:
	if current_enemy == null:
		return
	var remaining: int = current_enemy.health.current
	if remaining <= 0:
		return
	current_enemy.health.take_damage(remaining)
	effect_applied.emit(skill, remaining, "enemy", "player")
	_apply_lifesteal(remaining)


func _calculate_hit_count(skill: SkillDefinition) -> int:
	if skill.bonus_hits_per_stat == null:
		return 1
	var stats := PlayerData.get_total_stats()
	var bonus: float = _get_player_stat(stats, skill.bonus_hits_per_stat.stat) * skill.bonus_hits_per_stat.weight
	return 1 + int(floor(bonus))
#endregion

#region Tura przeciwnika
func build_enemy_trigger_context(enemy: EnemyInstance) -> Dictionary:
	var caster_hp_ratio: float = 1.0
	if enemy.health.max_hp > 0:
		caster_hp_ratio = float(enemy.health.current) / float(enemy.health.max_hp)
	var target_hp_ratio: float = 1.0
	if PlayerData.health.max_hp > 0:
		target_hp_ratio = float(PlayerData.health.current) / float(PlayerData.health.max_hp)
	return {"face": 0, "max_face": 1, "caster_hp_ratio": caster_hp_ratio, "target_hp_ratio": target_hp_ratio}


func _create_status_from_enemy_trigger(trigger: SkillTriggerBase, enemy: EnemyInstance) -> StatusEffect:
	var status_type := trigger.apply_status
	var tick := 0.0
	var initial := 0.0
	var duration := 3
	var enemy_stats := enemy.definition.get_total_stats()
	match status_type:
		GameEnums.StatusType.BURN:
			var stat_status := _get_player_stat(enemy_stats, GameEnums.Stat.STATUS)
			tick = stat_status * 0.4
			duration = 3 + int(floor(stat_status / 20.0))
		GameEnums.StatusType.POISON:
			var stat_magic := _get_player_stat(enemy_stats, GameEnums.Stat.MAGIC)
			var stat_status := _get_player_stat(enemy_stats, GameEnums.Stat.STATUS)
			initial = stat_magic * 0.3
			tick = stat_status * 0.6
			duration = 4
		GameEnums.StatusType.BLEED:
			var stat_dmg := _get_player_stat(enemy_stats, GameEnums.Stat.DMG)
			tick = stat_dmg * 0.25
			duration = 3
	return StatusEffect.new(status_type, duration, tick, initial)


func _tick_player_statuses() -> void:
	var ticks := PlayerData.status_manager.tick_all()
	for tick_data in ticks:
		var dmg: int = tick_data["damage"]
		var status_type: GameEnums.StatusType = tick_data["type"]
		var status_name: String = GameEnums.StatusType.keys()[status_type]
		if dmg > 0:
			PlayerData.health.take_damage(dmg)
			status_tick_on_player.emit(status_name, dmg)
			Log.print("DoT na graczu [%s]: %d obrażeń" % [status_name, dmg])


func enemy_take_turn() -> void:
	if is_game_over:
		return
	if current_enemy == null:
		Log.warning("CombatManager: brak current_enemy, pomijam turę wroga")
		return
	current_enemy.take_turn()


func resolve_enemy_attack(pattern: EnemyAttackPattern, enemy: EnemyInstance) -> void:
	if is_game_over or enemy == null or enemy.health.is_dead():
		return
	var skill: SkillDefinition = pattern.skill
	var value := calculate_enemy_effect_value(skill, enemy)
	var hit_count := _calculate_enemy_hit_count(skill, enemy)
	var context := build_enemy_trigger_context(enemy)
	var pre := _resolve_enemy_pre_hit_triggers(skill, enemy, context, value)
	value = pre["value"]
	var ignore_shield: bool = pre["ignore_shield"]
	for _hit in range(hit_count):
		match skill.effect_type:
			GameEnums.SkillEffect.DAMAGE:
				_apply_damage_to_player(skill, int(round(value)), ignore_shield)
				var player_died := PlayerData.health.current <= 0
				_apply_post_hit_triggers_to_player(skill, context, enemy, value, player_died)
			GameEnums.SkillEffect.HEAL:
				_apply_heal_to_enemy(skill, int(round(value)), enemy)
			GameEnums.SkillEffect.SHIELD:
				Log.warning("resolve_enemy_attack: SHIELD dla wroga jeszcze nie podłączone (enemy nie ma systemu block)")
			_:
				Log.warning("CombatManager: nieobsłużony enemy effect_type %s" % skill.effect_type)
		if is_game_over or enemy.health.is_dead():
			break
		if delay_between_effects > 0.0:
			await get_tree().create_timer(delay_between_effects).timeout
	_tick_player_statuses()


func calculate_enemy_effect_value(skill: SkillDefinition, enemy: EnemyInstance) -> float:
	if skill.scalings.is_empty():
		Log.warning("Skill wroga '%s' nie ma scalingu — wynik = 0" % skill.skill_name)
		return 0.0
	var enemy_stats := enemy.definition.get_total_stats()
	var primary := skill.scalings[0]
	var inner_sum: float = _get_player_stat(enemy_stats, primary.stat)
	for i in range(1, skill.scalings.size()):
		var secondary := skill.scalings[i]
		inner_sum += _get_player_stat(enemy_stats, secondary.stat) * secondary.weight
	var escalation: float = 1.0 + (enemy.turn_count * enemy.definition.escalation_rate)
	var final_value: float = primary.weight * inner_sum * escalation
	Log.print("=== ENEMY SKILL VALUE ===\nweight: %.2f | suma: %.2f | escalation: %.2f (tura %d) | final: %.2f" % [
		primary.weight, inner_sum, escalation, enemy.turn_count, final_value
	])
	return final_value


func _calculate_enemy_hit_count(skill: SkillDefinition, enemy: EnemyInstance) -> int:
	if skill.bonus_hits_per_stat == null:
		return 1
	var stats := enemy.definition.get_total_stats()
	var bonus: float = _get_player_stat(stats, skill.bonus_hits_per_stat.stat) * skill.bonus_hits_per_stat.weight
	return 1 + int(floor(bonus))
#endregion

#region Aplikacja efektów wroga na gracza
func _apply_damage_to_player(skill: SkillDefinition, value: int, ignore_shield: bool = false) -> void:
	PlayerData.take_damage(value, ignore_shield)
	effect_applied.emit(skill, value, "player", "enemy")


func _apply_heal_to_enemy(skill: SkillDefinition, value: int, enemy: EnemyInstance) -> void:
	enemy.health.heal(value)
	effect_applied.emit(skill, value, "enemy", "enemy")
#endregion

#region Aplikacja efektów
func _apply_lifesteal(damage_dealt: int) -> void:
	var lifesteal_percent := _get_total_lifesteal_percent()
	if lifesteal_percent <= 0.0:
		return
	var heal_value := int(round(damage_dealt * lifesteal_percent))
	if heal_value <= 0:
		return
	PlayerData.health.heal(heal_value)
	Log.print("Lifesteal: +%d HP (%.0f%% z %d dmg)" % [heal_value, lifesteal_percent * 100.0, damage_dealt])


func _get_total_lifesteal_percent() -> float:
	var total := 0.0
	for item_instance in PlayerData.equipped_items.values():
		if item_instance != null and item_instance.definition != null:
			total += item_instance.definition.lifesteal_percent
	return total


func _apply_heal_to_player(skill: SkillDefinition, value: int) -> void:
	PlayerData.health.heal(value)
	effect_applied.emit(skill, value, "player", "player")


func _apply_shield_to_player(skill: SkillDefinition, value: int) -> void:
	PlayerData.add_block(float(value))
	effect_applied.emit(skill, value, "player", "player")
	Log.print("Gracz zyskał %d block" % value)


func _apply_gold_to_player(skill: SkillDefinition, value: int) -> void:
	MetaProgressionManager.add_gold(value)
	effect_applied.emit(skill, value, "player", "player")
	Log.print("Gracz zyskał %d złota" % value)


func _apply_cleanse_to_player(skill: SkillDefinition) -> void:
	if PlayerData.status_manager.active_statuses.is_empty():
		Log.print("Cleanse: brak statusów do usunięcia")
		return
	PlayerData.status_manager.clear_all()
	effect_applied.emit(skill, 0, "player", "player")
	Log.print("Cleanse: usunięto wszystkie statusy gracza")
#endregion

#region Nagrody i koniec gry
func _on_current_enemy_died(enemy: EnemyInstance) -> void:
	Log.print("Wróg pokonany: %s" % enemy.definition.enemy_name)
	RewardManager.generate_rewards(enemy.definition)
	current_enemy = null
	enemy_died.emit(enemy)


func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	Log.print("PRZEGRANA — gracz zginął")
	player_died.emit()
#endregion
