extends Label

func _ready() -> void:
	# Podłączamy się pod sygnał zmiany złota z Autoloada
	PlayerData.gold_changed.connect(_update_gold_display)
	_update_gold_display(PlayerData.gold)

func _update_gold_display(new_amount: int) -> void:
	text = "Gold: %d$" % new_amount
	_pop_animation()

# Efekt soczystego "podskoczenia" napisu przy zdobyciu złota
func _pop_animation() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)