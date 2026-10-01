@tool
extends EditorScript

## Uruchom: File → Run (Ctrl+Shift+X)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://definitions/skills")

	_generate_all()
	print("✅ Nowe skille wygenerowane w res://definitions/skills/")


func _generate_all() -> void:
	# 1. Fortify (SHIELD, skaluje się z DEF)
	_save("fortify", _create(
		"fortify", "Fortify",
		GameEnums.SkillEffect.SHIELD,
		GameEnums.SkillTarget.SELF,
		1.5,
		GameEnums.DamageElement.NONE,
		[_make_scaling(GameEnums.Stat.DEF, 1.0)],
		[GameEnums.SkillTag.DEFENSIVE],
		[]
	))

	# 2. Molten Ward (SHIELD, DEF + MAGIC)
	_save("molten_ward", _create(
		"molten_ward", "Molten Ward",
		GameEnums.SkillEffect.SHIELD,
		GameEnums.SkillTarget.SELF,
		1.0,
		GameEnums.DamageElement.NONE,
		[
			_make_scaling(GameEnums.Stat.DEF, 0.5),
			_make_scaling(GameEnums.Stat.MAGIC, 0.5),
		],
		[GameEnums.SkillTag.DEFENSIVE, GameEnums.SkillTag.ELEMENTAL, GameEnums.SkillTag.FIRE],
		[]
	))

	# 3. Swift Strike (DAMAGE, SPEED jako źródło)
	_save("swift_strike", _create(
		"swift_strike", "Swift Strike",
		GameEnums.SkillEffect.DAMAGE,
		GameEnums.SkillTarget.SINGLE_ENEMY,
		0.5,
		GameEnums.DamageElement.PHYSICAL,
		[_make_scaling(GameEnums.Stat.SPEED, 0.8)],
		[GameEnums.SkillTag.ATTACK, GameEnums.SkillTag.PHYSICAL],
		[]
	))

	# 4. Loot (GOLD, LUCK)
	_save("loot", _create(
		"loot", "Loot",
		GameEnums.SkillEffect.GOLD,
		GameEnums.SkillTarget.NONE,
		2.0,
		GameEnums.DamageElement.NONE,
		[_make_scaling(GameEnums.Stat.LUCK, 1.0)],
		[],
		[]
	))

	# 5. Rekindle (HEAL, VIT + MAGIC)
	_save("rekindle", _create(
		"rekindle", "Rekindle",
		GameEnums.SkillEffect.HEAL,
		GameEnums.SkillTarget.SELF,
		0.6,
		GameEnums.DamageElement.NONE,
		[
			_make_scaling(GameEnums.Stat.VIT, 0.5),
			_make_scaling(GameEnums.Stat.MAGIC, 0.5),
		],
		[GameEnums.SkillTag.HEALING],
		[]
	))

	# 6. Headbutt (DAMAGE, DMG + DEF)
	_save("headbutt", _create(
		"headbutt", "Headbutt",
		GameEnums.SkillEffect.DAMAGE,
		GameEnums.SkillTarget.SINGLE_ENEMY,
		0.6,
		GameEnums.DamageElement.PHYSICAL,
		[
			_make_scaling(GameEnums.Stat.DMG, 0.5),
			_make_scaling(GameEnums.Stat.DEF, 0.3),
		],
		[GameEnums.SkillTag.ATTACK, GameEnums.SkillTag.PHYSICAL, GameEnums.SkillTag.DEFENSIVE],
		[]
	))

	# 7. Arcane Burst (DAMAGE, czysta MAGIC — alternatywa do Frost Bolt bez elementu)
	_save("arcane_burst", _create(
		"arcane_burst", "Arcane Burst",
		GameEnums.SkillEffect.DAMAGE,
		GameEnums.SkillTarget.SINGLE_ENEMY,
		1.0,
		GameEnums.DamageElement.NONE,
		[_make_scaling(GameEnums.Stat.MAGIC, 1.0)],
		[GameEnums.SkillTag.ATTACK, GameEnums.SkillTag.ELEMENTAL],
		[]
	))

	# 8. Rage (BUFF_DAMAGE, +15% podstawy, skaluje z LUCK)
	_save("rage", _create(
		"rage", "Rage",
		GameEnums.SkillEffect.BUFF_DAMAGE,
		GameEnums.SkillTarget.SELF,
		0.15,
		GameEnums.DamageElement.NONE,
		[_make_scaling(GameEnums.Stat.LUCK, 0.02)],
		[],
		[]
	))

	# 9. Pinpoint (BUFF_CRIT, mnożnik 1.5× skaluje się z CRIT)
	_save("pinpoint", _create(
		"pinpoint", "Pinpoint",
		GameEnums.SkillEffect.BUFF_CRIT,
		GameEnums.SkillTarget.SELF,
		1.5,
		GameEnums.DamageElement.NONE,
		[_make_scaling(GameEnums.Stat.CRIT, 0.05)],
		[],
		[]
	))

	# 10. Pickpocket (GOLD, LUCK ×1.5 — słabszy niż Loot, bo rękawice)
	_save("pickpocket", _create(
		"pickpocket", "Pickpocket",
		GameEnums.SkillEffect.GOLD,
		GameEnums.SkillTarget.NONE,
		1.0,
		GameEnums.DamageElement.NONE,
		[_make_scaling(GameEnums.Stat.LUCK, 1.5)],
		[],
		[]
	))

	# 11. Bleeding Cut (DAMAGE + ON_HIT → Bleed)
	_save("bleeding_cut", _create(
		"bleeding_cut", "Bleeding Cut",
		GameEnums.SkillEffect.DAMAGE,
		GameEnums.SkillTarget.SINGLE_ENEMY,
		0.5,
		GameEnums.DamageElement.PHYSICAL,
		[_make_scaling(GameEnums.Stat.DMG, 0.6)],
		[GameEnums.SkillTag.ATTACK, GameEnums.SkillTag.PHYSICAL, GameEnums.SkillTag.DOT],
		[_make_trigger(GameEnums.TriggerType.ON_HIT, 0.0, GameEnums.StatusType.BLEED, 1, 0.0)]
	))

	# 12. Rust (DEBUFF_ARMOR, MAGIC)
	_save("rust", _create(
		"rust", "Rust",
		GameEnums.SkillEffect.DEBUFF_ARMOR,
		GameEnums.SkillTarget.SINGLE_ENEMY,
		1.0,
		GameEnums.DamageElement.NONE,
		[_make_scaling(GameEnums.Stat.MAGIC, 0.5)],
		[],
		[]
	))


# ── FUNKCJE POMOCNICZE ──

func _create(
	id_key: String,
	skill_name: String,
	effect: GameEnums.SkillEffect,
	target: GameEnums.SkillTarget,
	base: float,
	element: GameEnums.DamageElement,
	scalings: Array,
	tags: Array,
	triggers: Array
) -> SkillDefinition:
	var s := SkillDefinition.new()
	s.id = id_key
	s.skill_name = skill_name
	s.description = ""
	s.effect_type = effect
	s.target_type = target
	s.base_value = base
	s.damage_element = element
	s.duration_rounds = 1

	var typed_scalings: Array[SkillScaling] = []
	for sc in scalings:
		typed_scalings.append(sc as SkillScaling)
	s.scalings = typed_scalings

	var typed_tags: Array[GameEnums.SkillTag] = []
	for tg in tags:
		typed_tags.append(tg as GameEnums.SkillTag)
	s.tags = typed_tags

	var typed_triggers: Array[SkillTrigger] = []
	for tr in triggers:
		typed_triggers.append(tr as SkillTrigger)
	s.triggers = typed_triggers

	return s


func _make_scaling(stat: GameEnums.Stat, weight: float) -> SkillScaling:
	var s := SkillScaling.new()
	s.stat = stat
	s.weight = weight
	return s


func _make_trigger(
	type: GameEnums.TriggerType,
	tr_threshold: float,
	status: GameEnums.StatusType,
	stacks: int,
	base_override: float
) -> SkillTrigger:
	var t := SkillTrigger.new()
	t.trigger_type = type
	t.threshold = tr_threshold
	t.apply_status = status
	t.status_stacks = stacks
	t.base_value_override = base_override
	return t


func _save(filename: String, resource: SkillDefinition) -> void:
	var path := "res://definitions/skills/%s.tres" % filename
	var err := ResourceSaver.save(resource, path)
	if err == OK:
		print("  ✔ %s" % path)
	else:
		push_error("  ✘ Błąd zapisu %s: %d" % [path, err])
