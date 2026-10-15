## Baza dla triggerów, których efekt to LICZBA (dmg, shield, heal, gold, permanent buff).
## Dodaje opcję skalowania tej liczby wartością trafienia zamiast stałej wartości z pola podklasy.
class_name AmountTriggerBase
extends SkillTriggerBase

@export_group("Amount")
## Jeśli true — ignoruje get_base_amount() i używa wartości trafienia (hit_data["value"]).
@export var scale_with_hit_value: bool = false

## Nadpisz w podklasie: zwraca stałą wartość z własnego pola (np. flat_damage, shield_amount).
func get_base_amount() -> float:
	return 0.0

func get_amount(hit_value: float) -> float:
	return hit_value if scale_with_hit_value else get_base_amount()

## Domyślny opis dla efektów liczbowych — podklasy mogą nadpisać czymś bardziej opisowym
## (np. z nazwą efektu "Dmg"/"Shield"/"HP"), ale to zapewnia sensowny fallback.
func get_effect_description() -> String:
	if scale_with_hit_value:
		return "+Hit Value"
	return "+%s" % format_amount(get_base_amount())
