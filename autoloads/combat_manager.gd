extends Node

signal enemy_changed(enemy: EnemyInstance)
signal player_died
signal enemy_died(enemy: EnemyInstance)
signal effect_applied(skill: SkillDefinition, value: int, target: String)
signal player_attack_finished

@export var delay_between_effects: float = 0.5

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
		return "[color=red]Brak aktywnego wroga[/red]"
	
	current_enemy.health.take_damage(current_enemy.health.max_hp)
	return "[color=green]Wróg zabity[/color]"


func set_enemy(enemy: EnemyInstance) -> void:
	current_enemy = enemy


func resolve_player_attack(selected_results: Array[Dictionary]) -> void:
	if is_game_over:
		return

	var target: = current_enemy

	for result in selected_results:
		# Sprawdź czy wróg nie zmienił się w trakcie lub nie zginął lub gra się nie skończyła, aby nie przechodził atak na kolejnego enemy
		if is_game_over or current_enemy == null or current_enemy != target:
			break
			
		var skill: SkillDefinition = result["skill"]
		#var dice_level_on_item: int = result["dice_level_on_item"]
		var item_instance: ItemInstance = result["item"]
		var rolled_face: int = result["face"]
		var value := calculate_effect_value(skill, item_instance.definition, rolled_face)
		var hit_count := _calculate_hit_count(skill, item_instance.definition)
		Log.print("face=%d → value=%.1f" % [rolled_face, value])

		for hit in range(hit_count):
			match skill.effect_type:
				GameEnums.SkillEffect.DAMAGE:
					_apply_damage_to_enemy(skill, value)
				GameEnums.SkillEffect.HEAL:
					_apply_heal_to_player(skill, value)
				_:
					Log.warning("CombatManager: nieobsłużony effect_type %s dla skilla '%s'" % [skill.effect_type, skill.skill_name])
					break

			if current_enemy == null or current_enemy != target or is_game_over:
				break
		
		
		if delay_between_effects > 0.0:
			await get_tree().create_timer(delay_between_effects).timeout

	player_attack_finished.emit()
	
func calculate_effect_value(skill: SkillDefinition, item: ItemDefinition, dice_roll: int) -> float:
	var item_scaling: float = 0.0
	for scaling in skill.scalings:
		item_scaling += item.get_stat(scaling.stat) * scaling.weight

	var affinity_multiplier: float = item.get_affinity_multiplier(skill.damage_element)

	return skill.base_value * dice_roll * item_scaling * affinity_multiplier

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


func _apply_damage_to_enemy(skill: SkillDefinition, value: int) -> void:
	if current_enemy == null:
		Log.warning("CombatManager: brak current_enemy, pomijam %d obrażeń ze skilla '%s'" % [value, skill.skill_name])
		return
	current_enemy.health.take_damage(value)
	effect_applied.emit(skill, value, "enemy")


func _apply_heal_to_player(skill: SkillDefinition, value: int) -> void:
	PlayerData.health.heal(value)
	effect_applied.emit(skill, value, "player")


func _on_current_enemy_died(enemy: EnemyInstance) -> void:
	Log.print("Wróg pokonany: %s" % enemy.definition.enemy_name)
	current_enemy = null
	enemy_died.emit(enemy)


func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	Log.print("PRZEGRANA — gracz zginął")
	player_died.emit()
