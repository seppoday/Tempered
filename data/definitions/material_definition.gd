class_name MaterialDefinition extends Resource

@export var id: String
@export var material_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var value: int = 1
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
