extends Node2D

func _ready() -> void:
	move_coin_along_curve($Control, Vector2(0, 0), Vector2(1500, 300), Vector2(100, 800))

func quadratic_bezier(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	t: float
) -> Vector2:
	var a := p0.lerp(p1, t)
	var b := p1.lerp(p2, t)
	return a.lerp(b, t)

func move_coin_along_curve(
	coin: Control,
	start: Vector2,
	control: Vector2,
	target: Vector2
):
	var tween := coin.create_tween()

	tween.tween_method(
		func(t):
			coin.global_position = quadratic_bezier(
				start,
				control,
				target,
				t
			),
		0.0,
		1.0,
		0.6
	)
