class_name GameEnums extends RefCounted

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC
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
	NONE,           # Efekty globalne (gold, buffy)
}

const DICE_PROGRESSION: Array[int] = [4, 6, 8, 10, 12, 16, 20]

static func get_rarity_color(rarity: Rarity) -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.7, 0.7, 0.7)
		Rarity.UNCOMMON: return Color(0.2, 0.8, 0.2)
		Rarity.RARE: return Color(0.2, 0.5, 1.0)
		Rarity.EPIC: return Color(0.7, 0.2, 0.9)
		Rarity.LEGENDARY: return Color(1.0, 0.7, 0.0)
		Rarity.MYTHIC: return Color(1.0, 0.2, 0.2)
	return Color.WHITE
