@tool
extends EditorPlugin

const ItemOverviewDock = preload("res://addons/items_overview/item_overview_dock.gd")

var main_screen: Control

func _enter_tree() -> void:
	main_screen = ItemOverviewDock.new()
	EditorInterface.get_editor_main_screen().add_child(main_screen)
	main_screen.hide()

func _exit_tree() -> void:
	if main_screen:
		main_screen.free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if main_screen:
		main_screen.visible = visible

func _get_plugin_name() -> String:
	return "Item & Skill Overview"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("GridContainer", "EditorIcons")
