extends Node2D

@onready var inventory_section = %InventorySection

func hide_panel(node) -> void:
	var tween := create_tween()
	
	tween.tween_property(
		node,
		"offset_transform_position",
		Vector2(3000.0, 0),
		2.5
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).as_relative()
	
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
