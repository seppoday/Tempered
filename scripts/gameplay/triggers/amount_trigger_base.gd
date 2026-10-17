## Baza dla triggerów, których efekt to LICZBA (dmg, shield, heal, gold, permanent buff).
## Wynik = (stała z podklasy LUB ratio × wartość trafienia) + skalowanie statami castera.
class_name AmountTriggerBase
extends SkillTriggerBase

@export_group("Amount")
## > 0: zamiast stałej wartości z podklasy używa (ratio × wartość trafienia). 1.0 = 100%, 0.5 = 50%. 0 = stała wartość.
@export_range(0.0, 5.0, 0.05, "or_greater") var hit_value_ratio: float = 0.0
## Opcjonalnie: każdy wpis dodaje (stat castera × weight) do wyniku. Caster = gracz albo wróg.
@export var stat_scalings: Array[SkillScaling] = []

## Nadpisz w podklasie: zwraca stałą wartość z własnego pola (np. flat_damage, shield_amount).
func get_base_amount() -> float:
	return 0.0

func get_amount(combat_manager, hit_data: Dictionary) -> float:
	var amount: float = get_base_amount()
	if hit_value_ratio > 0.0:
		amount = float(hit_data["value"]) * hit_value_ratio
	if not stat_scalings.is_empty():
		var stats := _get_caster_stats(hit_data)
		for scaling in stat_scalings:
			if scaling != null:
				amount += combat_manager._get_player_stat(stats, scaling.stat) * scaling.weight
	return amount

func _get_caster_stats(hit_data: Dictionary) -> Dictionary:
	if hit_data.get("target") == "player":
		var enemy: EnemyInstance = hit_data.get("enemy")
		if enemy != null:
			return enemy.definition.get_total_stats()
	return PlayerData.get_total_stats()

## Opis ilości do UI: "+10 Dmg", "+50% Hit Dmg", z dopiskiem "(+0.5×DMG)" przy skalowaniu statami.
func describe_amount(unit: String) -> String:
	var text: String
	if hit_value_ratio > 0.0:
		text = "+%s%% Hit %s" % [format_amount(hit_value_ratio * 100.0), unit]
	else:
		text = "+%s %s" % [format_amount(get_base_amount()), unit]
	if not stat_scalings.is_empty():
		var parts: Array[String] = []
		for scaling in stat_scalings:
			if scaling != null:
				parts.append("%s×%s" % [format_amount(scaling.weight), GameEnums.Stat.keys()[scaling.stat]])
		if not parts.is_empty():
			text += " (+%s)" % " + ".join(parts)
	return text

func get_effect_description() -> String:
	return describe_amount("").strip_edges()
