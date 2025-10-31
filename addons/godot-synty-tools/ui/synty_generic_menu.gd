@tool
extends BaseMenuWithSelection

# Declare custom options BEFORE _init()
var custom_option_checkbox: CheckBox
var custom_dropdown: OptionButton
var custom_value: bool = false
var custom_selection: int = 0

func _init():
	MODULE = "Synty Generic"
	instruction_default = "Select the " + MODULE + " folder"
	import_generator_path = "res://addons/godot-synty-tools/import_generators/synty_generic_import_generator.gd"
	
	selection_mode = SelectionMode.FOLDER_ONLY
	allowed_file_extensions = PackedStringArray()

func build_content() -> void:
	# First, build all the base content
	super.build_content()

	# needs to be taller
	if plugin and plugin.popup_manager and plugin.popup_manager.popup_window:
		plugin.popup_manager.popup_window.size = Vector2i(475, 650)	

	# look for where we want to add the options
	var status_index: int = -1
	for i in range(container.get_child_count()):
		if container.get_child(i) == status_label:
			status_index = i
			break

	# add them
	var checkbox_container = HBoxContainer.new()
	checkbox_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	checkbox_container.alignment = BoxContainer.ALIGNMENT_CENTER
	checkbox_container.add_theme_constant_override("separation", 10)
	
	var checkbox_label = Label.new()
	checkbox_label.text = "Custom Option:"
	checkbox_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	checkbox_container.add_child(checkbox_label)
	
	custom_option_checkbox = CheckBox.new()
	custom_option_checkbox.set_pressed_no_signal(custom_value)  # Use this instead
	custom_option_checkbox.toggled.connect(_on_custom_option_toggled)
	checkbox_container.add_child(custom_option_checkbox)
	
	if status_index >= 0:
		container.add_child(checkbox_container)
		container.move_child(checkbox_container, status_index)
	
	var dropdown_container = HBoxContainer.new()
	dropdown_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dropdown_container.alignment = BoxContainer.ALIGNMENT_CENTER
	dropdown_container.add_theme_constant_override("separation", 10)
	
	var dropdown_label = Label.new()
	dropdown_label.text = "Import Mode:"
	dropdown_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	dropdown_container.add_child(dropdown_label)
	
	custom_dropdown = OptionButton.new()
	custom_dropdown.add_item("Standard", 0)
	custom_dropdown.add_item("Advanced", 1)
	custom_dropdown.add_item("Minimal", 2)
	custom_dropdown.select(custom_selection)  # Use select() instead
	custom_dropdown.custom_minimum_size = Vector2(120, 30)
	custom_dropdown.item_selected.connect(_on_custom_dropdown_selected)
	dropdown_container.add_child(custom_dropdown)
	
	if status_index >= 0:
		container.add_child(dropdown_container)
		container.move_child(dropdown_container, status_index)

func _on_custom_option_toggled(pressed: bool) -> void:
	custom_value = pressed
	print("Custom option: ", custom_value)

func _on_custom_dropdown_selected(index: int) -> void:
	custom_selection = index
	print("Selected mode: ", custom_dropdown.get_item_text(index))

func _on_run_button_press() -> void:
	# Hide custom options when running
	if custom_option_checkbox:
		custom_option_checkbox.get_parent().visible = false
	if custom_dropdown:
		custom_dropdown.get_parent().visible = false
	
	# Call parent implementation
	super._on_run_button_press()

func validate_folder_specific(dir: DirAccess) -> bool:
	return true

func get_processing_message() -> String:
	return "Processing started, see the Output tab for logs.\nMaterial errors on import are expected."