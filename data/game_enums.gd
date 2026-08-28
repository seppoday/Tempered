class_name GameEnums extends RefCounted

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC
}

static func get_rarity_color(rarity: Rarity) -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.7, 0.7, 0.7)
		Rarity.UNCOMMON: return Color(0.2, 0.8, 0.2)
		Rarity.RARE: return Color(0.2, 0.5, 1.0)
		Rarity.EPIC: return Color(0.7, 0.2, 0.9)
		Rarity.LEGENDARY: return Color(1.0, 0.7, 0.0)
		Rarity.MYTHIC: return Color(1.0, 0.2, 0.2)
	return Color.WHITE