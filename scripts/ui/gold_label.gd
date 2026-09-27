extends Label

func _ready() -> void:
	PlayerData.gold_changed.connect(_update_gold_display)
	_update_gold_display(PlayerData.gold)

func _update_gold_display(new_amount: int) -> void:
	text = "Gold: %d$" % new_amount
	_pop_animation()

func _pop_animation() -> void:
	Utilities.center_pivot(self)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "offset_transform_scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(self, "offset_transform_scale", Vector2.ONE, 0.15)
