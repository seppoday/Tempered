extends CanvasLayer

@onready var processing_layer: ColorRect = $ProcessingLayer

# Zmienna przechowująca referencję do aktualnego tweena (zapobiega konfliktom)
var blur_tween: Tween

func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	
	# Upewniamy się, że na starcie blur jest wyłączony
	var mat = processing_layer.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("blur_enabled", false)
		mat.set_shader_parameter("blur_strength", 0.0)

func _on_state_changed(new_state: GameManager.State) -> void:
	var mat = processing_layer.material as ShaderMaterial
	if not mat:
		return

	if blur_tween and blur_tween.is_running():
		blur_tween.kill()

	var should_blur: bool = (
		new_state == GameManager.State.GAME_OVER or 
		new_state == GameManager.State.WEAPON_SELECT or
		new_state == GameManager.State.META_PROGRESSION
	)

	blur_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	if should_blur:
		mat.set_shader_parameter("blur_enabled", true)
		blur_tween.tween_property(mat, "shader_parameter/blur_strength", 10.0, 0.5)
	else:
		blur_tween.tween_property(mat, "shader_parameter/blur_strength", 0.0, 0.5)
		blur_tween.tween_callback(func(): mat.set_shader_parameter("blur_enabled", false))
