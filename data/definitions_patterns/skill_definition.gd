extends Resource
class_name SkillDefinition

@export var id: String = ""
@export var skill_name: String = ""
@export var icon: Texture2D
@export_multiline var description: String = ""

@export var effect_type: GameEnums.SkillEffect = GameEnums.SkillEffect.DAMAGE
@export var target_type: GameEnums.SkillTarget = GameEnums.SkillTarget.ENEMY

@export var scalings: Array[SkillScaling] = []

@export var damage_element: GameEnums.DamageElement = GameEnums.DamageElement.NONE
@export_range(0.0, 50.0, 0.1) var element_synergy_bonus: float = 0.0

@export var duration_rounds: int = 0
@export var bonus_hits_per_stat: SkillScaling

@export var triggers: Array[SkillTriggerBase] = []
