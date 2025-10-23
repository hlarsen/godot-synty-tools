@tool
class_name PopupManager
extends RefCounted

var plugin: EditorPlugin
var popup_window: Window
var main_container: VBoxContainer
var button_grid: Control

func create_popup(plugin_ref: EditorPlugin, plugin_name: String) -> void:
	plugin = plugin_ref
	
	if popup_window:
		popup_window.queue_free()

	# Create main window
	popup_window = Window.new()
	popup_window.title = plugin_name
	popup_window.size = Vector2i(600, 400)
	popup_window.unresizable = false
	popup_window.borderless = false
	popup_window.transient = true
	popup_window.exclusive = false
	
	# Center the window
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var window_pos: Vector2i = (screen_size - popup_window.size) / 2
	popup_window.position = window_pos
	
	# Main container
	main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add padding
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	# Title
	var title = Label.new()
	title.text = plugin_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_container.add_child(spacer)
	
	# Button container
	button_grid = VBoxContainer.new()
	button_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button_grid.add_theme_constant_override("separation", 10)
	
	main_container.add_child(button_grid)
	margin.add_child(main_container)
	popup_window.add_child(margin)
	
	# Add to scene tree
	plugin.get_editor_interface().get_base_control().add_child(popup_window)
	popup_window.popup_centered()

func close_popup() -> void:
	if popup_window:
		popup_window.queue_free()
		popup_window = null

func update_title(new_title: String) -> void:
	if main_container:
		var title: Label = main_container.get_child(0) as Label
		if title:
			title.text = new_title

func get_button_grid() -> Control:
	return button_grid

func get_window() -> Window:
	return popup_window

func connect_close_signal(callable: Callable) -> void:
	if popup_window:
		popup_window.close_requested.connect(callable)
