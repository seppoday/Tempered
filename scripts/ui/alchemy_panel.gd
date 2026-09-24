extends PanelContainer

@onready var alchemy_grid: GridContainer = %AlchemyGrid
@onready var result_grid: GridContainer = %AlchemyGridResults
@onready var craft_button: Button = %CraftButton
@onready var result_slot: Panel

var slot_content: Dictionary = {}

const SLOT_COUNT: int = 3
const SLOT_GAP: int = 2
const GRID_COLUMNS: int = 3

# Jedyna linijka potrzebna do tworzenia slotów:
const SlotScene: PackedScene = preload("res://scenes/slot.tscn")

func _ready() -> void:
	craft_button.pressed.connect(_on_craft_button_pressed)
	_setup_grid()
	_create_slots()
	_update_craft_button_state()

func _setup_grid() -> void:
	alchemy_grid.columns = GRID_COLUMNS
	alchemy_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	alchemy_grid.add_theme_constant_override("v_separation", SLOT_GAP)
	
	result_grid.columns = 1
	result_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	result_grid.add_theme_constant_override("v_separation", SLOT_GAP)


func _create_slots() -> void:
	for i in range(SLOT_COUNT):
		var slot: Panel = SlotScene.instantiate()
		slot.slot_changed.connect(_on_slot_changed)
		alchemy_grid.add_child(slot)
	
	result_slot = SlotScene.instantiate()
	result_slot.slot_changed.connect(_on_slot_changed)
	result_grid.add_child(result_slot)


func _on_slot_changed(slot: Panel) -> void:
	if slot.item_data:
		Log.print("[ALCHEMY] Slot: ", slot.item_data.definition.name, " x", slot.item_data.quantity)
	else:
		Log.print("[ALCHEMY] Slot cleared")
	
	_collect_slot_contents()
	_update_craft_button_state()
	Log.print("Pasujący przepis: ", find_matching_recipe())


func _on_craft_button_pressed() -> void:
	var recipe = find_matching_recipe()
	if recipe == null:
		return
	
	var consume = _consume_ingredients(recipe)
	if consume == false:
		Log.print("[ALCHEMY] Not enough ingredients to craft.")
		return
	
	var final_result = ItemDatabase.get_item_definition(recipe.result_item_id)
	if final_result == null:
		Log.print("[ALCHEMY] Result item not found in database.")
	else:
		result_slot.set_item(ItemInstance.new(final_result, recipe.result_item_amount))
		_update_craft_button_state()



func _update_craft_button_state() -> void:
	var has_matching_recipe := find_matching_recipe() != null
	var result_slot_empty = result_slot.is_empty()
	craft_button.disabled = not has_matching_recipe or not result_slot_empty


func _collect_slot_contents():
	slot_content.clear()

	for slot in alchemy_grid.get_children():
		if slot.is_empty():
			continue
		else:
			if slot_content.has(slot.item_data.definition.id):
				slot_content[slot.item_data.definition.id] += slot.item_data.quantity
			else:
				slot_content[slot.item_data.definition.id] = slot.item_data.quantity

	Log.print(slot_content)

func find_matching_recipe() -> RecipeDefinition:
	var all_recipes := RecipeDatabase.get_all()

	for recipe in all_recipes:
		if _recipe_matches(recipe):
			return recipe

	return null

func _recipe_matches(recipe: RecipeDefinition) -> bool:
	for ingredient in recipe.ingredients:
		if slot_content.get(ingredient.material_id, 0) < ingredient.amount:
			return false
	
	for material_id in slot_content.keys():
		var found_in_recipe := false
		for igredient in recipe.ingredients:
			if igredient.material_id == material_id:
				found_in_recipe = true
				break
		if not found_in_recipe:
			return false

	return true


func _consume_ingredients(recipe: RecipeDefinition) -> bool:
	for ingredient in recipe.ingredients:
		var remaining: int = ingredient.amount
		for slot in alchemy_grid.get_children():
			if remaining <= 0:
				break
			if not slot.is_empty() and slot.item_data.definition.id == ingredient.material_id:
				var mow_much_in_slot: int = slot.item_data.quantity
				if mow_much_in_slot <= remaining:
					remaining -= mow_much_in_slot
					slot.clear()
				else:
					slot.item_data.quantity -= remaining
					slot._update_visual()
					remaining = 0
		if remaining > 0:
			return false

	return true
