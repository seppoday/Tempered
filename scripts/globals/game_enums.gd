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
