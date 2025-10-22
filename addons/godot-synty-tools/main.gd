@tool
extends EditorPlugin

var popup_window: Window
var main_container: VBoxContainer
var button_grid: Control
var current_menu_stack: Array = []
var menu_builders: Dictionary = {}

var plugin_name: String = "Godot Synty Tools"

# Submenus
var base_locomotion_export_menu

func _ready():
	# register menu builders - these are wrappers that handle the details
	menu_builders["main"] = func(): _show_main_menu()
	menu_builders["base_locomotion"] = func(): _show_base_locomotion_submenu()
	# add additional menus here

func _show_submenu(menu_key: String):
	current_menu_stack.append(menu_key)
	if menu_builders.has(menu_key):
		menu_builders[menu_key].call()

func _enter_tree():
	add_tool_menu_item(plugin_name, _show_popup)
	
	# Initialize submenus
	base_locomotion_export_menu = preload("res://addons/godot-synty-tools/base_locomotion_export_menu.gd").new()
	base_locomotion_export_menu.plugin = self

func _exit_tree():
	remove_tool_menu_item(plugin_name)
	if popup_window:
		popup_window.queue_free()
	if base_locomotion_export_menu:
		base_locomotion_export_menu.cleanup()

func _show_popup():
	if popup_window:
		popup_window.queue_free()

#	current_menu_stack.clear()
#	current_menu_stack.append("main")

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
	title.text = "Main Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_container.add_child(spacer)
	
	# Button container (VBox instead of Grid)
	button_grid = VBoxContainer.new()
	button_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button_grid.add_theme_constant_override("separation", 10)
	
	# Add main menu buttons
	_show_main_menu()
	
	main_container.add_child(button_grid)
	margin.add_child(main_container)
	popup_window.add_child(margin)
	
	# Connect close signal
	popup_window.close_requested.connect(_close_popup)

	# Add to scene tree
	get_editor_interface().get_base_control().add_child(popup_window)
	popup_window.popup_centered()

func _close_popup():
	if popup_window:
		popup_window.queue_free()
		popup_window = null
	current_menu_stack.clear()

	if base_locomotion_export_menu:
		base_locomotion_export_menu.cleanup()

func _show_base_locomotion_submenu():
	base_locomotion_export_menu.show_menu(button_grid, popup_window)
	_update_title("Base Locomotion Export")

func _show_main_menu():
	# Only recreate if button_grid already exists and has a parent
	if button_grid and button_grid.get_parent():
		var parent: Node = button_grid.get_parent()
		button_grid.queue_free()
		
		button_grid = VBoxContainer.new()
		button_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button_grid.add_theme_constant_override("separation", 10)
		parent.add_child(button_grid)
	
	_update_title("Main Menu")
	
	# Clear existing children if we're reusing the container
	for child in button_grid.get_children():
		child.queue_free()
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button_grid.add_child(spacer)
	
	# Button row
	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 10)
	
	# Base Locomotion Export button
	var base_loco_btn = Button.new()
	base_loco_btn.text = "Base Locomotion Export"
	base_loco_btn.custom_minimum_size = Vector2(200, 60)
	base_loco_btn.pressed.connect(func(): _show_submenu("base_locomotion"))
	button_row.add_child(base_loco_btn)
	
	button_grid.add_child(button_row)
	
	# Another spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button_grid.add_child(spacer2)
	
	# Exit button at bottom
	var exit_row = HBoxContainer.new()
	exit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var exit_btn = Button.new()
	exit_btn.text = "Exit"
	exit_btn.custom_minimum_size = Vector2(150, 60)
	exit_btn.pressed.connect(_on_exit)
	exit_row.add_child(exit_btn)
	
	button_grid.add_child(exit_row)

func _go_back():
	if current_menu_stack.size() > 0:
		current_menu_stack.pop_back()

	# show the previous menu in the stack, or main if empty
	if current_menu_stack.size() > 0:
		var previous_menu = current_menu_stack[current_menu_stack.size() - 1]
		menu_builders[previous_menu].call()
	else:
		_show_main_menu()

func _on_exit():
	_close_popup()

func _update_title(new_title: String):
	var title: Label = main_container.get_child(0) as Label
	if title:
		title.text = new_title

# Public API for submenus
func go_back():
	_go_back()

func close_popup():
	_close_popup()
