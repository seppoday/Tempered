extends Node2D

@onready var dice: Node2D = $Dice

var test_weapon: ItemInstance

func _ready() -> void:
	var weapon_def := ItemDatabase.get_item_definition("knight_armor")  # albo jakikolwiek masz z dice_level > 0
	test_weapon = ItemInstance.new(weapon_def)
	dice.roll_done.connect(_on_roll_done)
	var fire_skill := SkillDatabase.get_skill_definition("fire_attack")
	test_weapon.slot_assignments[3] = fire_skill

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		var result := test_weapon.roll_skill()
		print("Rzut: ścianka ", result["face"], " → skill: ", result["skill"])
		dice.roll_to(result["face"])

func _on_roll_done(value: int) -> void:
	print("Animacja zakończona na wartości: ", value)
