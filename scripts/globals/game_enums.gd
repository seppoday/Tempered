class_name GameEnums extends RefCounted

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC
}

enum Stat { 
	DMG,
	MAGIC,
	DEF,
	VIT,
	LUCK,
	STATUS,
	CRIT
}

enum DamageElement {
	NONE,
	PHYSICAL, 
	FIRE, 
	ICE, 
	POISON, 
}

enum SkillEffect {
	DAMAGE,         # Obrażenia na celu
	HEAL,           # Leczenie castera
	GOLD,           # Złoto dla gracza
	SHIELD,         # Tarcza na castera
	CLEANSE,
	#BUFF_CRIT,      # Mnożnik crit do następnego ataku
	#BUFF_DAMAGE,    # +% do obrażeń wszystkich skilli w tej turze
	#DEBUFF_ARMOR,   # Zmniejszenie pancerza wroga
}

enum SkillTarget {
	SELF,
	ENEMY,
	NONE, # Efekty globalne (gold, buffy)
}

enum StatusType {
	NONE,
	BURN,
	POISON,
	BLEED,
}

enum TriggerType {
	ON_HIT,            # zawsze przy trafieniu
	ON_ROLL_AT_LEAST,  # rolled_face >= threshold
	ON_ROLL_AT_MOST,   # rolled_face <= threshold
	ON_MAX_ROLL,       # wypadł max wynik na kości
	ON_LOW_ROLL,       # wypadło 1
	ON_KILL,           # ten hit zabił wroga
	ON_TARGET_STATUS,  # cel ma jeden ze statusów z target_statuses
}

enum TriggerEffect {
	NONE,                  # brak dodatkowego efektu (użyj gdy chcesz TYLKO apply_status)
	BONUS_DAMAGE,          # dodatkowe, płaskie obrażenia na celu
	GAIN_SHIELD,           # gracz zyskuje tarczę
	GAIN_HP,               # gracz leczy się
	GAIN_GOLD,             # gracz zyskuje złoto
	DAMAGE_MULTIPLIER,     # mnoży już wyliczoną wartość trafienia (3.0 = "crit" x300%)
	SET_TO_MAX_VALUE,      # przelicza wartość tak, jakby wypadł max na kości
	IGNORE_TARGET_SHIELD,  # to trafienie ignoruje tarczę wroga
	PERMANENT_DAMAGE_BUFF, # trwały bonus do obrażeń do końca walki
	REDUCE_NEXT_PICKS,     # przy następnym rzucie gracz wybiera o effect_value mniej kości
}

const DICE_PROGRESSION: Array[int] = [6, 8, 10, 12, 16, 20]

static func get_rarity_color(rarity: Rarity) -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.7, 0.7, 0.7)
		Rarity.UNCOMMON: return Color(0.2, 0.8, 0.2)
		Rarity.RARE: return Color(0.2, 0.5, 1.0)
		Rarity.EPIC: return Color(0.742, 0.0, 0.219, 1.0)
		Rarity.LEGENDARY: return Color(0.8, 0.307, 0.0, 1.0)
		Rarity.MYTHIC: return Color(0.491, 0.003, 0.85, 1.0)
		
	return Color.WHITE
	
static func enum_name(enum_dict: Dictionary, value: int, prefix: String) -> String:
	return TranslationServer.translate("%s_%s" % [prefix, enum_dict.find_key(value)])

static func get_rarity_name(rarity: Rarity) -> String:
	return Utilities.translate_enum(Rarity, rarity, "RARITY")

static func get_stat_name(stat: Stat) -> String:
	return Utilities.translate_enum(Stat, stat, "STAT")

static func get_element_name(element: DamageElement) -> String:
	return Utilities.translate_enum(DamageElement, element, "ELEMENT")

static func get_status_name(status: StatusType) -> String:
	return Utilities.translate_enum(StatusType, status, "STATUS_TYPE")

static func get_skill_effect_name(effect: SkillEffect) -> String:
	return Utilities.translate_enum(SkillEffect, effect, "SKILL_EFFECT")

static func get_skill_target_name(target: SkillTarget) -> String:
	return Utilities.translate_enum(SkillTarget, target, "SKILL_TARGET")

static func get_trigger_name(trigger: TriggerType) -> String:
	return Utilities.translate_enum(TriggerType, trigger, "TRIGGER")
