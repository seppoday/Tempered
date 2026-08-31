extends PanelContainer

@onready var alchemy_grid: GridContainer = %AlchemyGrid
@onready var result_grid: GridContainer = %AlchemyGridResults

var slot_content: Dictionary = {}

const SLOT_COUNT: int = 4
const SLOT_GAP: int = 12
const GRID_COLUMNS: int = 6

# Jedyna linijka potrzebna do tworzenia slotów:
const SlotScene: PackedScene = preload("res://scenes/slot.tscn")

func _ready() -> void:
	%CraftButton.pressed.connect(_on_craft_button_pressed)
	%CraftButton.disabled = true
	_setup_grid()
	_create_slots()

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
	
	var result_grid_slot: Panel = SlotScene.instantiate()
	result_grid.add_child(result_grid_slot)

func _on_slot_changed(slot: Panel) -> void:
	if slot.item_data:
		print("[ALCHEMY] Slot: ", slot.item_data.definition.name, " x", slot.item_data.quantity)
	else:
		print("[ALCHEMY] Slot cleared")
	
	_collect_slot_contents()
	print("Pasujący przepis: ", find_matching_recipe())

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

	print(slot_content)

func find_matching_recipe() -> RecipeDefinition:
	var all_recipes := RecipeDatabase.get_all_recipes()

	for recipe in all_recipes:
		if _recipe_matches(recipe):
			%CraftButton.disabled = false
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

func _on_craft_button_pressed() -> void:
	var recipe = find_matching_recipe()
	_consume_ingredients(recipe)
	%CraftButton.disabled = true

func _consume_ingredients(recipe: RecipeDefinition) -> bool:
	for ingredient in recipe.ingredients:
		var remaining: int = ingredient.amount
		for slot in alchemy_grid.get_children():
			if remaining <= 0:
				break
			if not slot.is_empty() and slot.item_data.definition.id == ingredient.material_id:
				var have: int = slot.item_data.quantity
				if have <= remaining:
					remaining -= have
					slot.clear()
				else:
					slot.item_data.quantity -= remaining
					slot._update_visual()
					remaining = 0
		if remaining > 0:
			return false

	return true
