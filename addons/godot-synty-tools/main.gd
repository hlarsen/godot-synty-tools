@tool
extends EditorPlugin

var current_menu_stack: Array = []
var menu_builders: Dictionary = {}
var plugin_name: String = "Godot Synty Tools"
var popup_manager: RefCounted  # Will be PopupManager instance

# Submenus
var main_menu: BaseMenu
var base_locomotion_menu: BaseMenu
var scifi_city_menu: BaseMenu

func _ready():
	# Register menu builders
	menu_builders["main"] = func(): _show_submenu_helper(main_menu, "Godot Synty Tools")
	menu_builders["base_locomotion"] = func(): _show_submenu_helper(base_locomotion_menu, "Base Locomotion")
	menu_builders["scifi_city"] = func(): _show_submenu_helper(scifi_city_menu, "Sci-Fi City")

func _show_submenu(menu_key: String):
	if menu_builders.has(menu_key):
		current_menu_stack.append(menu_key)
		menu_builders[menu_key].call()

func _enter_tree():
	add_tool_menu_item(plugin_name, _show_popup)
	
	# Initialize popup manager
	var PopupManager: PopupManager = preload("res://addons/godot-synty-tools/ui/popup_manager.gd")
	popup_manager = PopupManager.new()
	
	# Initialize main menu
	main_menu = preload("res://addons/godot-synty-tools/ui/main_menu.gd").new()
	main_menu.plugin = self
	
	# Initialize submenus
	base_locomotion_menu = preload("res://addons/godot-synty-tools/ui/base_locomotion_menu.gd").new()
	base_locomotion_menu.plugin = self
	
	scifi_city_menu = preload("res://addons/godot-synty-tools/ui/scifi_city_menu.gd").new()
	scifi_city_menu.plugin = self

func _exit_tree():
	remove_tool_menu_item(plugin_name)
	if popup_manager:
		popup_manager.close_popup()
	
	# Cleanup all menus
	for menu in [main_menu, base_locomotion_menu, scifi_city_menu]:
		if menu:
			menu.cleanup()

func _show_popup():
	popup_manager.create_popup(self, plugin_name)
	popup_manager.connect_close_signal(_close_popup)
	_show_main_menu()

func _close_popup():
	popup_manager.close_popup()
	current_menu_stack.clear()

	# Cleanup all menus
	for menu in [main_menu, base_locomotion_menu, scifi_city_menu]:
		if menu:
			menu.cleanup()

func _show_submenu_helper(menu: BaseMenu, title: String):
	menu.show_menu(popup_manager.get_button_grid(), popup_manager.get_window())
	popup_manager.update_title(title)

func _show_main_menu():
	main_menu.show_menu(popup_manager.get_button_grid(), popup_manager.get_window())

func _go_back():
	if current_menu_stack.size() > 0:
		current_menu_stack.pop_back()

	# Show the previous menu in the stack, or main if empty
	if current_menu_stack.size() > 0:
		var previous_menu = current_menu_stack[current_menu_stack.size() - 1]
		menu_builders[previous_menu].call()
	else:
		_show_main_menu()

func _on_exit():
	_close_popup()

# Public API for submenus
func go_back():
	_go_back()

func close_popup():
	_close_popup()

func update_title(new_title: String):
	if popup_manager:
		popup_manager.update_title(new_title)