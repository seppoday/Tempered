class_name SkillItemDefinition extends InventoryEntry

## Efekt, który ten item-skill wstrzykuje w wybrane pole kości.
@export var skill: SkillDefinition:
	set(value):
		skill = value
		_sync_from_skill()

func _sync_from_skill() -> void:
	if skill == null:
		return
	if id.is_empty():
		id = skill.id
	if name.is_empty():
		name = skill.skill_name
	if description.is_empty():
		description = skill.description
	if icon == null:
		icon = skill.icon
