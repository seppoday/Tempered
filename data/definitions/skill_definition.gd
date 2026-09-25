class_name SkillDefinition extends Resource

@export var id: String
@export var skill_name: String
@export var icon: Texture2D
@export_multiline var description: String

@export_category("Effect")
@export var effect_type: GameEnums.SkillEffect = GameEnums.SkillEffect.DAMAGE
@export var target_type: GameEnums.SkillTarget = GameEnums.SkillTarget.SINGLE_ENEMY
@export var base_value: float = 1.0
@export var scalings: Array[SkillScaling] = []
@export var damage_element: GameEnums.DamageElement = GameEnums.DamageElement.PHYSICAL
@export var duration_rounds: int = 1
@export var bonus_hits_per_stat: SkillScaling  # null = zawsze 1 trafienie
