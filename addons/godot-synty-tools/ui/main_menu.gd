@tool
extends BaseMenu

# Configure how many buttons per row
const BUTTONS_PER_ROW: int = 2

func build_content() -> void:
	# Create a centering container
	var center_container = CenterContainer.new()
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create a GridContainer for auto-flowing buttons
	var button_grid = GridContainer.new()
	button_grid.columns = BUTTONS_PER_ROW
	button_grid.add_theme_constant_override("h_separation", 10)
	button_grid.add_theme_constant_override("v_separation", 10)
	
	# Add all your buttons to the grid
	# Base Locomotion button
	var base_loco_btn = Button.new()
	base_loco_btn.text = "Base Locomotion"
	base_loco_btn.custom_minimum_size = Vector2(200, 60)
	base_loco_btn.pressed.connect(func(): plugin._show_submenu("base_locomotion"))
	button_grid.add_child(base_loco_btn)
	
	# Sci-Fi City button
	var scifi_city_btn = Button.new()
	scifi_city_btn.text = "Sci-Fi City\n(Work in Progress)"
	scifi_city_btn.custom_minimum_size = Vector2(200, 60)
	scifi_city_btn.pressed.connect(func(): plugin._show_submenu("scifi_city"))
	button_grid.add_child(scifi_city_btn)

	# Quaternius UAL button
	var quaternius_uap_btn = Button.new()
	quaternius_uap_btn.text = "Quaternius UAL"
	quaternius_uap_btn.custom_minimum_size = Vector2(200, 60)
	quaternius_uap_btn.pressed.connect(func(): plugin._show_submenu("quaternius_ual"))
#	button_grid.add_child(quaternius_uap_btn)
	
	# Add more buttons here - they'll automatically flow to new rows!
	# Example:
	# var new_module_btn = Button.new()
	# new_module_btn.text = "New Module"
	# new_module_btn.custom_minimum_size = Vector2(200, 60)
	# new_module_btn.pressed.connect(func(): plugin._show_submenu("new_module"))
	# button_grid.add_child(new_module_btn)

	center_container.add_child(button_grid)
	container.add_child(center_container)

func show_menu(button_grid: Control, popup_window: Window) -> void:
	container = button_grid
	window = popup_window
	
	# Clear existing children
	for child in container.get_children():
		child.queue_free()
	
	# Update title
	plugin.update_title("Godot Synty Tools")
	
	# Build content
	build_content()
	
	# Bottom spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)
	
	# Exit button at bottom (instead of Back)
	var exit_row = HBoxContainer.new()
	exit_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var exit_btn = Button.new()
	exit_btn.text = "Exit"
	exit_btn.custom_minimum_size = Vector2(150, 60)
	exit_btn.pressed.connect(plugin._on_exit)
	exit_row.add_child(exit_btn)

	container.add_child(exit_row)
