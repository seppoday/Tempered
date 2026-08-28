class_name RecipeDefinition extends Resource

@export var id: String
@export var ingredients: Array[RecipeIngredient] = []
@export var result_item_id: String
@export var result_item_amount: int = 1