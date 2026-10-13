extends Resource
class_name SkillTrigger

@export var trigger_type: GameEnums.TriggerType = GameEnums.TriggerType.ON_HIT
@export var threshold: float = 0.0
@export var target_statuses: Array[GameEnums.StatusType] = []

@export var hp_cost: float = 0.0

@export var effect: GameEnums.TriggerEffect = GameEnums.TriggerEffect.NONE
@export var effect_value: float = 0.0
@export var scale_with_hit_value: bool = false

@export var apply_status: GameEnums.StatusType = GameEnums.StatusType.NONE
@export var status_stacks: int = 1
