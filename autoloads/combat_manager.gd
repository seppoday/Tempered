extends Node

signal enemy_changed(enemy: EnemyInstance)
signal player_died
signal enemy_died(enemy: EnemyInstance)
signal effect_applied(skill: SkillDefinition, value: int, target: String)
signal player_attack_finished

@export var delay_between_effects: float = 0.5

# ── Stan buffów gracza (resetowany co turę / po zużyciu) ──
var current_turn_damage_bonus: float = 0.0   # +% do DAMAGE w tej turze
var next_attack_crit_multiplier: float = 1.0  # mnożnik na najbliższy DAMAGE

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


func _ready() -> void:
	PlayerData.health.died.connect(_on_player_died)
	DebugConsole.register_command("killenemy", _cmd_kill_enemy, "killenemy = zabija bieżącego wroga")

func _cmd_kill_enemy(_args: Array) -> String:
	if current_enemy == null:
		return "[color=red]Brak aktywnego wroga[/color]"
	current_enemy.health.take_damage(current_enemy.health.max_hp)
	return "[color=green]Wróg zabity[/color]"


func set_enemy(enemy: EnemyInstance) -> void:
	current_enemy = enemy
	Log.print("Następny wróg: %s" % current_enemy.definition.enemy_name)


# ── GŁÓWNA PĘTLA ATAKU ──

func resolve_player_attack(selected_results: Array[Dictionary]) -> void:
	if is_game_over:
		return

	# Reset buffów turowych na początku nowej tury gracza
	current_turn_damage_bonus = 0.0

	var target: = current_enemy

	for result in selected_results:
		if is_game_over or current_enemy == null or current_enemy != target:
			break

		var skill: SkillDefinition = result["skill"]
		var item_instance: ItemInstance = result["item"]
		var rolled_face: int = result["face"]
		var value := calculate_effect_value(skill, item_instance.definition, rolled_face)
		var hit_count := _calculate_hit_count(skill, item_instance.definition)
		Log.print("face=%d → value=%.1f" % [rolled_face, value])

		for hit in range(hit_count):
			match skill.effect_type:
				GameEnums.SkillEffect.DAMAGE:
					_apply_damage_to_enemy(skill, int(value))
				GameEnums.SkillEffect.HEAL:
					_apply_heal_to_player(skill, int(value))
				GameEnums.SkillEffect.SHIELD:
					_apply_shield_to_player(skill, int(value))
				GameEnums.SkillEffect.GOLD:
					_apply_gold_to_player(skill, int(value))
				GameEnums.SkillEffect.BUFF_CRIT:
					_apply_crit_buff(skill, value)
				GameEnums.SkillEffect.BUFF_DAMAGE:
					_apply_damage_buff(skill, value)
				GameEnums.SkillEffect.DEBUFF_ARMOR:
					_apply_armor_debuff_to_enemy(skill, int(value))
				_:
					Log.warning("CombatManager: nieobsłużony effect_type %s" % skill.effect_type)
					break

			if current_enemy == null or current_enemy != target or is_game_over:
				break

		if delay_between_effects > 0.0:
			await get_tree().create_timer(delay_between_effects).timeout

	player_attack_finished.emit()


# ── KALKULATOR WARTOŚCI ──

func calculate_effect_value(skill: SkillDefinition, item: ItemDefinition, dice_roll: int) -> float:
	var item_scaling: float = 0.0
	for scaling in skill.scalings:
		item_scaling += item.get_stat(scaling.stat) * scaling.weight

	var affinity_multiplier: float = item.get_affinity_multiplier(skill.damage_element)
	var final_value: float = skill.base_value * dice_roll * item_scaling * affinity_multiplier

	# Buffy aplikujemy TYLKO do skilli typu DAMAGE
	if skill.effect_type == GameEnums.SkillEffect.DAMAGE:
		# 1) +% do obrażeń w tej turze
		if current_turn_damage_bonus > 0.0:
			final_value *= (1.0 + current_turn_damage_bonus)
			Log.print("Buff damage: +%.0f%%" % (current_turn_damage_bonus * 100.0))

		# 2) Crit na następny atak (zużywa się po jednym trafieniu)
		if next_attack_crit_multiplier > 1.0:
			final_value *= next_attack_crit_multiplier
			Log.print("CRIT! x%.2f" % next_attack_crit_multiplier)
			next_attack_crit_multiplier = 1.0

	Log.print(
		"=== SKILL VALUE ===\n" +
		"Base: %.2f | Roll: %d | Scaling: %.2f | Affinity: %.2f | Final: %.2f" %
		[skill.base_value, dice_roll, item_scaling, affinity_multiplier, final_value]
	)
	return final_value


func _calculate_hit_count(skill: SkillDefinition, item: ItemDefinition) -> int:
	if skill.bonus_hits_per_stat == null:
		return 1
	var bonus: float = item.get_stat(skill.bonus_hits_per_stat.stat) * skill.bonus_hits_per_stat.weight
	return 1 + int(floor(bonus))


func enemy_take_turn() -> void:
	if is_game_over:
		return
	if current_enemy == null:
		Log.warning("CombatManager: brak current_enemy, pomijam turę wroga")
		return
	current_enemy.take_turn()


# ── APLIKACJA EFEKTÓW ──

func _apply_damage_to_enemy(skill: SkillDefinition, value: int) -> void:
	if current_enemy == null:
		Log.warning("CombatManager: brak wroga, pomijam %d dmg" % value)
		return

	# Uwzględniamy pancerz wroga (po debuffach)
	var effective_armor: float = current_enemy.get_effective_armor()
	var reduction: float = effective_armor / (effective_armor + 100.0)
	var final_damage: int = int(round(value * (1.0 - reduction)))

	if reduction > 0.0:
		Log.print("Pancerz wroga: %.0f → redukcja %.1f%% → dmg %d → %d" %
			[effective_armor, reduction * 100.0, value, final_damage])

	current_enemy.health.take_damage(final_damage)
	effect_applied.emit(skill, final_damage, "enemy")


func _apply_heal_to_player(skill: SkillDefinition, value: int) -> void:
	PlayerData.health.heal(value)
	effect_applied.emit(skill, value, "player")


func _apply_shield_to_player(skill: SkillDefinition, value: int) -> void:
	# PlayerData ma add_block() → pending_block jest zużywany w take_damage()
	PlayerData.add_block(float(value))
	effect_applied.emit(skill, value, "player")
	Log.print("Gracz zyskał %d block (tarczy)" % value)


func _apply_gold_to_player(skill: SkillDefinition, value: int) -> void:
	PlayerData.add_gold(value)
	effect_applied.emit(skill, value, "player")
	Log.print("Gracz zyskał %d złota" % value)


func _apply_crit_buff(skill: SkillDefinition, value: float) -> void:
	# value = mnożnik (np. 1.5 = 150% obrażeń, 2.0 = podwójne)
	next_attack_crit_multiplier = max(next_attack_crit_multiplier, value)
	effect_applied.emit(skill, int(value * 100), "player")
	Log.print("Crit buff: x%.2f do następnego ataku" % value)


func _apply_damage_buff(skill: SkillDefinition, value: float) -> void:
	# value = ułamek (np. 0.25 = +25%)
	current_turn_damage_bonus += value
	effect_applied.emit(skill, int(value * 100), "player")
	Log.print("Damage buff: +%.0f%% na tę turę" % (value * 100.0))


func _apply_armor_debuff_to_enemy(skill: SkillDefinition, value: int) -> void:
	if current_enemy == null:
		return
	current_enemy.armor_debuff += float(value)
	effect_applied.emit(skill, value, "enemy")
	Log.print("Armor debuff: -%d pancerza wroga (łącznie -%.0f)" %
		[value, current_enemy.armor_debuff])


# ── NAGRODY / KONIEC GRY ──

func _on_current_enemy_died(enemy: EnemyInstance) -> void:
	Log.print("Wróg pokonany: %s" % enemy.definition.enemy_name)
	_grant_rewards(enemy.definition)
	current_enemy = null
	enemy_died.emit(enemy)


func _grant_rewards(definition: EnemyDefinition) -> void:
	var loot_table: LootTable = definition.loot_table
	if loot_table == null:
		return

	if loot_table.gold_max > 0:
		var gold_amount: int = RNG.randi_range(loot_table.gold_min, loot_table.gold_max)
		if gold_amount > 0:
			PlayerData.add_gold(gold_amount)

	var dropped: LootEntry = loot_table.roll_entry()
	if dropped == null or dropped.entry == null:
		return

	var inventory := get_tree().get_first_node_in_group("inventory")
	if inventory == null:
		Log.warning("CombatManager: brak plecaka, pomijam drop '%s'" % dropped.entry.name)
		return

	inventory.add_item(ItemInstance.new(dropped.entry))


func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	Log.print("PRZEGRANA — gracz zginął")
	player_died.emit()
