extends Node

@onready var inventory_section = %InventorySection

func _ready() -> void:
	var test = CharacterDatabase.get_all()
	AudioManager.play_music(AudioLibrary.get_music(AudioKeys.MUSIC_TEST), -10.0)
	print(test)

func hide_panel(node) -> void:
	var tween := create_tween()
	
	tween.tween_property(node, "offset_transform_position", Vector2(3000.0, 0), 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).as_relative()
	
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		PlayerData.health.take_damage(15)
