extends CanvasLayer
# Autoload: FloatingTextManager

@export var floating_text_scene: PackedScene = preload("uid://b5e6onr0nkuv6")

const COLOR_DAMAGE := Color(1.0, 0.3, 0.3)
const COLOR_HEAL := Color(0.3, 1.0, 0.4)
const COLOR_DODGE := Color(0.6, 0.6, 0.65)
const COLOR_INFO := Color(0.8, 0.8, 0.8)

# ── NOWE: Kolory dla tarczy i statusów ──
const COLOR_SHIELD := Color(0.2, 0.6, 1.0)       # Jasnoniebieski (tarcza)
const COLOR_BURN := Color(1.0, 0.45, 0.0)        # Pomarańczowy (ogień)
const COLOR_POISON := Color(0.55, 0.15, 0.85)     # Fioletowy (trucizna)
const COLOR_BLEED := Color(0.7, 0.0, 0.0)         # Ciemnoczerwony (krwawienie)

func _ready() -> void:
	layer = 998


func spawn_world(text: String, world_position: Vector3, color: Color = Color.WHITE) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(world_position):
		return
	spawn_screen(text, camera.unproject_position(world_position), color)


func spawn_screen(text: String, screen_position: Vector2, color: Color = Color.WHITE) -> void:
	var text_node := floating_text_scene.instantiate()
	add_child(text_node)

	var random_offset := Vector2(RNG.randf_range(-6.0, 6.0), RNG.randf_range(-10.0, -4.0))
	text_node.global_position = screen_position + random_offset
	text_node.setup(text, color)


func spawn_damage(value: int, world_position: Vector3) -> void:
	var text = Utilities.format_large_number(value)
	spawn_world("-" + text, world_position, COLOR_DAMAGE)


func spawn_heal(value: int, position: Vector2) -> void:
	var text = Utilities.format_large_number(value)
	spawn_screen("+" + text, position, COLOR_HEAL)


func spawn_dodge(world_position: Vector3) -> void:
	spawn_world("DODGE!", world_position, COLOR_DODGE)


func spawn_info(value: String, world_position: Vector3) -> void:
	spawn_world(value, world_position, COLOR_INFO)


# ── NOWE METODY POMOCNICZE ──

## Spawnuje informację o nałożeniu statusu (np. "SPALENIE 🔥")
func spawn_status_applied(status_type: GameEnums.StatusType, world_position: Vector3) -> void:
	match status_type:
		GameEnums.StatusType.BURN:
			spawn_world("PODPALENIE 🔥", world_position, COLOR_BURN)
		GameEnums.StatusType.POISON:
			spawn_world("ZATRUCIE 🧪", world_position, COLOR_POISON)
		GameEnums.StatusType.BLEED:
			spawn_world("KRWAWIENIE 🩸", world_position, COLOR_BLEED)


## Spawnuje tick obrażeń DoT (np. "-4 🔥")
func spawn_status_tick(value: int, status_type: GameEnums.StatusType, world_position: Vector3) -> void:
	var text = "-" + Utilities.format_large_number(value)
	match status_type:
		GameEnums.StatusType.BURN:
			spawn_world(text + " 🔥", world_position, COLOR_BURN)
		GameEnums.StatusType.POISON:
			spawn_world(text + " 🧪", world_position, COLOR_POISON)
		GameEnums.StatusType.BLEED:
			spawn_world(text + " 🩸", world_position, COLOR_BLEED)


## Spawnuje blok tarczy (np. "-12 🛡️") w 2D (nad paskiem HP gracza) lub w 3D (nad wrogiem)
func spawn_shield_block(value: int, position: Vector2) -> void:
	var text = "-" + Utilities.format_large_number(value)
	spawn_screen(text + " 🛡️", position, COLOR_SHIELD)
