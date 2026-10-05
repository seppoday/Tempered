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
	SPEED,
	LUCK,
	STATUS,
	CRIT
}

enum DamageElement {
	PHYSICAL, 
	FIRE, 
	ICE, 
	POISON, 
	NONE
}

enum SkillEffect {
	DAMAGE,         # Obrażenia na celu
	HEAL,           # Leczenie castera
	GOLD,           # Złoto dla gracza
	SHIELD,         # Tarcza na castera
	BUFF_CRIT,      # Mnożnik crit do następnego ataku
	BUFF_DAMAGE,    # +% do obrażeń wszystkich skilli w tej turze
	DEBUFF_ARMOR,   # Zmniejszenie pancerza wroga
}

enum SkillTarget {
	SELF,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	NONE, # Efekty globalne (gold, buffy)
}

enum StatusType {
	BURN,
	POISON,
	BLEED,
}

enum TriggerType {
	NONE,           # Brak triggera — skill działa normalnie
	ON_HIT,         # Przy każdym trafieniu
	ON_HIGH_ROLL,   # Gdy rzut >= 75% max ścianki (top 25%)
	ON_MAX_ROLL,    # Gdy rzut == max ścianki (naturalne max)
	ON_LOW_HP,      # Gdy HP castera < próg (dla healów)
	EXECUTE,        # Gdy HP celu < próg (dla ataków)
}

enum SkillTag {
	ATTACK,
	ELEMENTAL,
	FIRE,
	ICE,
	POISON,
	PHYSICAL,
	HEALING,
	MULTI_HIT,
	EXECUTE,
	DEFENSIVE,
	DOT,
}

const DICE_PROGRESSION: Array[int] = [4, 6, 8, 10, 12, 16, 20]

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
	return enum_name(Rarity, rarity, "RARITY")

static func get_stat_name(stat: Stat) -> String:
	return enum_name(Stat, stat, "STAT")

static func get_element_name(element: DamageElement) -> String:
	return enum_name(DamageElement, element, "ELEMENT")

static func get_status_name(status: StatusType) -> String:
	return enum_name(StatusType, status, "STATUS_TYPE")

static func get_skill_effect_name(effect: SkillEffect) -> String:
	return enum_name(SkillEffect, effect, "SKILL_EFFECT")

static func get_skill_target_name(target: SkillTarget) -> String:
	return enum_name(SkillTarget, target, "SKILL_TARGET")

static func get_trigger_name(trigger: TriggerType) -> String:
	return enum_name(TriggerType, trigger, "TRIGGER")

static func get_skill_tag_name(tag: SkillTag) -> String:
	return enum_name(SkillTag, tag, "SKILL_TAG")
