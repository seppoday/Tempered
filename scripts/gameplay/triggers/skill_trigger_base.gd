class_name SkillTriggerBase
extends Resource

## === WARUNEK: kiedy trigger się odpala ===
@export_group("Condition")
@export var trigger_type: GameEnums.TriggerType = GameEnums.TriggerType.ON_HIT
@export var threshold: float = 0.0
## Trigger odpala się, jeśli CEL ma jeden z tych statusów (dotyczy tylko trigger_type = ON_TARGET_STATUS).
@export var required_target_statuses: Array[GameEnums.StatusType] = []

## === KOSZT: cena za odpalenie triggera ===
@export_group("Cost")
@export var hp_cost: float = 0.0

## === EFEKT UBOCZNY: dodatkowy status nakładany NA CEL, niezależnie od głównego efektu ===
@export_group("Status Effect")
## Status nakładany na cel przy odpaleniu triggera (niezależnie od apply()). NONE = brak.
@export var apply_status: GameEnums.StatusType = GameEnums.StatusType.NONE
@export var status_stacks: int = 1

## === KONTRAKT hit_data (bez zmian) ===
## Zawsze: "skill", "context", "value".
## PRE-HIT: + "item_def", "ignore_shield".
## POST-HIT enemy: + "item_def", "enemy_died", "target" = "enemy".
## POST-HIT player: + "enemy", "player_died", "target" = "player".

func is_pre_hit() -> bool:
	return false

## Ostatnia bramka przed odpaleniem: wołana PO sprawdzeniu warunku, a PRZED kosztem HP,
## apply() i nałożeniem statusu. Zwrócenie false pomija cały trigger. Nadpisz np. dla losowości.
func should_fire(_hit_data: Dictionary) -> bool:
	return true

func apply(combat_manager, hit_data: Dictionary) -> void:
	pass

## Krótki, czytelny opis efektu do UI (podgląd karty, tooltipy). Nadpisz w podklasie.
## Pusty string = brak własnego efektu (np. trigger użyty wyłącznie pod apply_status).
func get_effect_description() -> String:
	return ""

## Formatuje liczbę: 1.0 → "1", 0.25 → "0.25". Współdzielony helper dla opisów w podklasach.
static func format_amount(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(value)
	return "%.2f" % value

## Zwraca true, jeśli ten trigger może być użyty na skillu RZUCANYM PRZEZ WROGA na gracza.
## Domyślnie false — większość efektów (gold, picks, player-side buffs) ma sens tylko
## gdy castuje je gracz. Nadpisz w podklasach, które mają sens po obu stronach (np. BonusDamageTrigger).
func is_valid_for_enemy_cast() -> bool:
	return false
