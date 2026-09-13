extends Node2D

@onready var cards_container: BoxContainer = %CardsContainer

class DicePair:
	var dice: Node
	var item: ItemInstance

	func _init(dice: Node, item: ItemInstance) -> void:
		self.dice = dice
		self.item = item

	func roll_face() -> Dictionary:
		var result := item.roll_skill()
		dice.roll_to(result["face"])
		return result

const DICE_SCENES := {
	4: preload("res://test/dice_d4.tscn"),
	6: preload("res://test/dice_d6.tscn"),
	8: preload("res://test/dice_d8.tscn"),
	10: preload("res://test/dice_d10.tscn"),
	12: preload("res://test/dice_d12.tscn"),
	16: preload("res://test/dice_d16.tscn"),
	20: preload("res://test/dice_d20.tscn"),
}

var dice_pairs: Array[DicePair] = []

func _ready() -> void:
	PlayerData.item_equipped.connect(_on_item_equipped)
	await get_tree().create_timer(2.0).timeout

func _on_item_equipped(_slot_type: EquipmentSlot.Type, _item_instance: ItemInstance) -> void:
	_generate_dice()

func _generate_dice() -> void:
	_clear_dice()
	
	for item in PlayerData.equipped_items.values():
		if item == null:
			continue

		var dice_size: int = GameEnums.DICE_PROGRESSION[item.dice_level]
		var dice_scene: PackedScene = DICE_SCENES.get(dice_size)

		if dice_scene == null:
			continue

		var dice_instance := dice_scene.instantiate()
		dice_instance.global_position = Vector2(RNG.randi_range(200, 800), RNG.randi_range(300, 900))
		add_child(dice_instance)
		

		dice_pairs.append(DicePair.new(dice_instance, item))


func _clear_dice() -> void:
	for pair in dice_pairs:
		pair.dice.queue_free()

	dice_pairs.clear()

func _roll_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for pair in dice_pairs:
		var rolled_skill := pair.roll_face()

		results.append({
			"item": pair.item,
			"skill": rolled_skill["skill"],
			"multiplier": rolled_skill["multiplier"],
		})

	return results

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var results := _roll_all()
		cards_container.display_results(results)
