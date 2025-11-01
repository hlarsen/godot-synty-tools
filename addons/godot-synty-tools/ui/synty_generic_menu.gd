@tool
class_name SyntyGenericMenu
extends BaseMenuWithSelection

# Custom file pickers
var atlas_button: Button
var models_dir_button: Button
var textures_dir_button: Button
var atlas_label: Label
var models_label: Label
var textures_label: Label

var custom_atlas_path: String = ""
var custom_bone_map: String = ""
var custom_models_path: String = ""
var custom_textures_path: String = ""
var custom_post_import_script: String = ""

var bone_maps: Array[String] = FileUtils.list_files_recursive("res://addons/godot-synty-tools/bone_maps").filter(func(f): return f.ends_with(".tres"))
var bone_map_dropdown: OptionButton
var post_import_scripts: Array[String] = FileUtils.list_files_recursive("res://addons/godot-synty-tools/post_import_scripts").filter(func(f): return f.ends_with(".gd"))
var post_import_scripts_dropdown: OptionButton

func _init():
	MODULE = "Synty Generic"
	instruction_default = "Select the options for your " + MODULE + " import:"
	import_generator_path = "res://addons/godot-synty-tools/import_generators/synty_generic_import_generator.gd"
	
	selection_mode = SelectionMode.FOLDER_ONLY
	allowed_file_extensions = PackedStringArray()

func build_content() -> void:
	super.build_content()
	plugin.popup_manager.popup_window.size = Vector2i(500, 700)	
	plugin.popup_manager.popup_window.move_to_center()

	select_folder_button.get_parent().visible = false
	selected_folder_label.visible = false

	var status_index: int = -1
	for i in range(container.get_child_count()):
		if container.get_child(i) == status_label:
			status_index = i
			break

	# models dir
	var models_container = HBoxContainer.new()
	models_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	models_container.alignment = BoxContainer.ALIGNMENT_CENTER
	models_container.add_theme_constant_override("separation", 10)
	
	var models_label_text = Label.new()
	models_label_text.text = "Models Folder:"
	models_label_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	models_container.add_child(models_label_text)
	
	models_dir_button = Button.new()
	models_dir_button.text = "Select Folder"
	models_dir_button.custom_minimum_size = Vector2(120, 30)
	models_dir_button.pressed.connect(_on_select_models_dir)
	models_container.add_child(models_dir_button)
	
	if status_index >= 0:
		container.add_child(models_container)
		container.move_child(models_container, status_index)
	
	models_label = Label.new()
	models_label.text = "No Models folder selected (Probably FBX)"
	models_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	models_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	models_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if status_index >= 0:
		container.add_child(models_label)
		container.move_child(models_label, status_index + 1)

	# textures dir
	var textures_container = HBoxContainer.new()
	textures_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	textures_container.alignment = BoxContainer.ALIGNMENT_CENTER
	textures_container.add_theme_constant_override("separation", 10)
	
	var textures_label_text = Label.new()
	textures_label_text.text = "Textures Folder:"
	textures_label_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	textures_container.add_child(textures_label_text)
	
	textures_dir_button = Button.new()
	textures_dir_button.text = "Select Folder"
	textures_dir_button.custom_minimum_size = Vector2(120, 30)
	textures_dir_button.pressed.connect(_on_select_textures_dir)
	textures_container.add_child(textures_dir_button)
	
	if status_index >= 0:
		container.add_child(textures_container)
		container.move_child(textures_container, status_index + 2)
	
	textures_label = Label.new()
	textures_label.text = "No Textures folder selected (Probably Textures)"
	textures_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textures_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	textures_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if status_index >= 0:
		container.add_child(textures_label)
		container.move_child(textures_label, status_index + 3)

	# atlas texture
	var atlas_container = HBoxContainer.new()
	atlas_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	atlas_container.alignment = BoxContainer.ALIGNMENT_CENTER
	atlas_container.add_theme_constant_override("separation", 10)
	
	var atlas_label_text = Label.new()
	atlas_label_text.text = "Default Texture Atlas:"
	atlas_label_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	atlas_container.add_child(atlas_label_text)
	
	atlas_button = Button.new()
	atlas_button.text = "Select File"
	atlas_button.custom_minimum_size = Vector2(120, 30)
	atlas_button.pressed.connect(_on_select_atlas)
	atlas_container.add_child(atlas_button)
	
	if status_index >= 0:
		container.add_child(atlas_container)
		container.move_child(atlas_container, status_index + 4)
	
	atlas_label = Label.new()
	atlas_label.text = "No Atlas file selected (Probably ..01_A.png)"
	atlas_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	atlas_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atlas_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if status_index >= 0:
		container.add_child(atlas_label)
		container.move_child(atlas_label, status_index + 5)

	# post import script
	var post_import_script_container = HBoxContainer.new()
	post_import_script_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	post_import_script_container.alignment = BoxContainer.ALIGNMENT_CENTER
	post_import_script_container.add_theme_constant_override("separation", 10)
	
	var post_import_script_label = Label.new()
	post_import_script_label.text = "Post Import Script:"
	post_import_script_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	post_import_script_container.add_child(post_import_script_label)
	
	post_import_scripts_dropdown = OptionButton.new()
	add_dropdown_options(post_import_scripts_dropdown, post_import_scripts)
	post_import_scripts_dropdown.custom_minimum_size = Vector2(120, 30)
	var default_script_id: int = post_import_scripts.find(post_import_scripts.filter(func(f): return f.get_file() == "synty_generic.gd")[0])
	for i in post_import_scripts_dropdown.item_count:
		if post_import_scripts_dropdown.get_item_id(i) == default_script_id + 1:
			post_import_scripts_dropdown.select(i)
			custom_post_import_script = post_import_scripts[default_script_id]
			break
	post_import_scripts_dropdown.item_selected.connect(_on_post_import_script_dropdown_selected)
	post_import_script_container.add_child(post_import_scripts_dropdown)
	
	if status_index >= 0:
		container.add_child(post_import_script_container)
		container.move_child(post_import_script_container, status_index + 6)

	# bone map
	var bone_map_container = HBoxContainer.new()
	bone_map_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bone_map_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bone_map_container.add_theme_constant_override("separation", 10)
	
	var bone_map_label = Label.new()
	bone_map_label.text = "Bone Map for Characters:"
	bone_map_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	bone_map_container.add_child(bone_map_label)
	
	bone_map_dropdown = OptionButton.new()
	add_dropdown_options(bone_map_dropdown, bone_maps)
	bone_map_dropdown.custom_minimum_size = Vector2(120, 30)
	var default_bone_map_id: int = bone_maps.find(bone_maps.filter(func(f): return f.get_file() == "synty_generic.tres")[0])
	for i in bone_map_dropdown.item_count:
		if bone_map_dropdown.get_item_id(i) == default_bone_map_id + 1:
			bone_map_dropdown.select(i)
			custom_bone_map = bone_maps[default_bone_map_id]
			break
	bone_map_dropdown.item_selected.connect(_on_bonemap_dropdown_selected)
	bone_map_container.add_child(bone_map_dropdown)
	
	if status_index >= 0:
		container.add_child(bone_map_container)
		container.move_child(bone_map_container, status_index + 7)

func _on_select_atlas() -> void:
	custom_atlas_path = ""
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	dialog.title = "Select Atlas Texture"
	dialog.add_filter("*.png", "PNG Files")

	dialog.file_selected.connect(func(path):
		custom_atlas_path = path
		atlas_label.text = path.get_file()
		atlas_label.tooltip_text = path
		atlas_label.add_theme_color_override("font_color", Color(1, 1, 1))
		dialog.queue_free()
		validate_and_enable_run_button()	
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	
	plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_select_models_dir() -> void:
	custom_models_path = ""
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	dialog.title = "Select Models Directory"
	
	dialog.dir_selected.connect(func(path):
		custom_models_path = path
		models_label.text = path.get_file()
		models_label.tooltip_text = path
		models_label.add_theme_color_override("font_color", Color(1, 1, 1))
		dialog.queue_free()
		validate_and_enable_run_button()	
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	
	plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_select_textures_dir() -> void:
	custom_textures_path = ""
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	dialog.title = "Select Textures Directory"
	
	dialog.dir_selected.connect(func(path):
		custom_textures_path = path
		textures_label.text = path.get_file()
		textures_label.tooltip_text = path
		textures_label.add_theme_color_override("font_color", Color(1, 1, 1))
		dialog.queue_free()
		validate_and_enable_run_button()	
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	
	plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_bonemap_dropdown_selected(index: int) -> void:
	var id: int = bone_map_dropdown.get_item_id(index)
	if id == 9999:  # Check for 9999 instead of -1
		custom_bone_map = ""
	else:
		custom_bone_map = bone_maps[id - 1]
	validate_and_enable_run_button()

func _on_post_import_script_dropdown_selected(index: int) -> void:
	var id: int = post_import_scripts_dropdown.get_item_id(index)
	if id == 9999:  # Check for 9999 instead of -1
		custom_post_import_script = ""
	else:
		custom_post_import_script = post_import_scripts[id - 1]
	validate_and_enable_run_button()

func _on_run_button_press() -> void:
	# Hide custom UI elements
	if atlas_button: atlas_button.get_parent().visible = false
	if atlas_label: atlas_label.visible = false
	if models_dir_button: models_dir_button.get_parent().visible = false
	if models_label: models_label.visible = false
	if textures_dir_button: textures_dir_button.get_parent().visible = false
	if textures_label: textures_label.visible = false
	if bone_map_dropdown: bone_map_dropdown.get_parent().visible = false
	if post_import_scripts_dropdown: post_import_scripts_dropdown.get_parent().visible = false
	
	back_button.visible = false
	exit_button.visible = true
	run_button.disabled = true
	select_folder_button.disabled = true
	status_label.text = get_processing_message()
	status_label.visible = true
	selected_folder_label.visible = false
	timeout_label.visible = false
	timeout_input.visible = false

	if import_generator_path.is_empty():
		print("Error: import_generator_path not set in child class")
		return
	
	var generator_script = load(import_generator_path)
	if generator_script == null:
		print("Error: Could not load import generator at: ", import_generator_path)
		return
	
	var generator = generator_script.new()
	generator.plugin = plugin
#	generator.selected_folder_path = selected_folder_path
	generator.import_wait_timeout = import_wait_timeout
	generator.custom_default_atlas_texture = custom_atlas_path
	generator.custom_bone_map = custom_bone_map
	generator.custom_models_dir = custom_models_path
	generator.custom_textures_dir = custom_textures_path
	generator.custom_post_import_script = custom_post_import_script
	var err: Error = await generator.process()
	if not err == OK:
		print("Please review the logs, there was an error: " + error_string(err))

	await plugin.get_tree().create_timer(5).timeout

	plugin.close_popup()

func get_processing_message() -> String:
	return "Processing started, see the Output tab for logs.\nMaterial errors on import are expected."

func add_dropdown_options(dropdown: OptionButton, options: Array[String]) -> void:
	dropdown.add_item("None", 9999)  # Use 9999 instead of -1
	for i in options.size():
		dropdown.add_item(options[i].get_file(), i + 1)

func validate_and_enable_run_button() -> void:
	run_button.disabled = true

	if custom_models_path == "":
		print("Not Enabling Run Button: No Models folder selected")
		return

	if custom_textures_path == "":
		print("Not Enabling Run Button: No Textures folder selected")
		return

	run_button.disabled = false
