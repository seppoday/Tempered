class_name SkillDefinition extends Resource

enum EffectType {DAMAGE, HEAL, BLOCK, DODGE, STATUS}
enum DamageElement {PHYSICAL, FIRE, ICE, POISON}

@export var id: String
@export var skill_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_category("Effect")
@export var effect_type: EffectType = EffectType.DAMAGE
@export var damage_element: DamageElement = DamageElement.PHYSICAL
@export var base_value: float = 1.0
