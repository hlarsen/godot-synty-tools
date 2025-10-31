@tool
class_name BaseMenuWithSelection
extends BaseMenu

var file_dialog: EditorFileDialog
var back_button: Button
var exit_button: Button
var import_wait_timeout: int = 90
var instruction_default: String = ""
var run_button: Button
var select_folder_button: Button
var selected_folder_label: Label
var selected_folder_path: String = ""
var status_label: Label
var timeout_label: Label
var timeout_input: LineEdit

# Configuration for what to allow - set in child classes
enum SelectionMode { FOLDER_ONLY, FILE_ONLY, FOLDER_OR_FILE }
var selection_mode: SelectionMode = SelectionMode.FOLDER_OR_FILE
var allowed_file_extensions: PackedStringArray = PackedStringArray()

# Override these in child classes
var MODULE: String = "Module"
var import_generator_path: String = ""

func cleanup() -> void:
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
		file_dialog = null
	selected_folder_path = ""

func validate_and_enable_run_button() -> void:
	run_button.disabled = true

	if selected_folder_path.is_empty():
		print("Not Enabling Run Button: No folder/file selected")
		return

	var is_dir: bool = DirAccess.dir_exists_absolute(selected_folder_path)
	var is_file: bool = FileAccess.file_exists(selected_folder_path)
	
	# Check if selection matches the allowed mode
	if selection_mode == SelectionMode.FOLDER_ONLY and not is_dir:
		print("Not Enabling Run Button: Must select a folder")
		return
	
	if selection_mode == SelectionMode.FILE_ONLY and not is_file:
		print("Not Enabling Run Button: Must select a file")
		return
	
	if selection_mode == SelectionMode.FOLDER_OR_FILE and not (is_dir or is_file):
		print("Not Enabling Run Button: Invalid selection")
		return
	
	# If it's a file, validate extension
	if is_file:
		var ext: String = selected_folder_path.get_extension().to_lower()
		if not allowed_file_extensions.is_empty() and not ext in allowed_file_extensions:
			print("Not Enabling Run Button: Invalid file extension. Allowed: ", allowed_file_extensions)
			return
	
	# If it's a directory, perform folder-specific validation
	if is_dir:
		var dir: DirAccess = DirAccess.open(selected_folder_path)
		if dir == null:
			print("Not Enabling Run Button: Cannot open dir: ", selected_folder_path)
			return
		
		# Call child class validation
		if not validate_folder_specific(dir):
			return

	run_button.disabled = false

# Override in child classes for folder-specific validation
func validate_folder_specific(dir: DirAccess) -> bool:
	return true

func build_content() -> void:
	# Instruction text
	var instruction = Label.new()
	instruction.text = instruction_default
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	container.add_child(instruction)
	
	# Select folder/file button (centered)
	var button_container = HBoxContainer.new()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	select_folder_button = Button.new()
	match selection_mode:
		SelectionMode.FOLDER_ONLY:
			select_folder_button.text = "Select Folder"
		SelectionMode.FILE_ONLY:
			select_folder_button.text = "Select File"
		SelectionMode.FOLDER_OR_FILE:
			select_folder_button.text = "Select Folder or File"
	
	select_folder_button.custom_minimum_size = Vector2(150, 40)
	select_folder_button.pressed.connect(_on_select_folder)
	button_container.add_child(select_folder_button)
	container.add_child(button_container)
	
	# Selected folder/file display (below button)
	selected_folder_label = Label.new()
	selected_folder_label.text = "No selection made"
	selected_folder_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_folder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_folder_label.clip_text = true
	selected_folder_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected_folder_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(selected_folder_label)

	# Import timeout setting
	var timeout_container = HBoxContainer.new()
	timeout_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	timeout_container.alignment = BoxContainer.ALIGNMENT_CENTER
	timeout_container.add_theme_constant_override("separation", 10)

	timeout_label = Label.new()
	timeout_label.text = "Import Timeout (seconds):"
	timeout_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	timeout_container.add_child(timeout_label)
	
	timeout_input = LineEdit.new()
	timeout_input.text = str(import_wait_timeout)
	timeout_input.custom_minimum_size = Vector2(80, 30)
	timeout_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	timeout_input.text_changed.connect(_on_timeout_changed)
	timeout_container.add_child(timeout_input)
	
	container.add_child(timeout_container)

	var spacer_before_buttons = Control.new()
	spacer_before_buttons.custom_minimum_size = Vector2(0, 20)
	container.add_child(spacer_before_buttons)

	# Status label (hidden by default)
	status_label = Label.new()
	status_label.text = ""
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	status_label.visible = false
	container.add_child(status_label)
	
	# Button row
	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 10)

	run_button = Button.new()
	run_button.text = "Run"
	run_button.custom_minimum_size = Vector2(150, 60)
	run_button.disabled = true
	run_button.pressed.connect(_on_run_button_press)
	button_row.add_child(run_button)

	container.add_child(button_row)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

	var exit_row = HBoxContainer.new()
	exit_row.alignment = BoxContainer.ALIGNMENT_CENTER

	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(150, 60)
	back_button.pressed.connect(plugin.go_back)
	exit_row.add_child(back_button)

	exit_button = Button.new()
	exit_button.visible = false
	exit_button.text = "Exit"
	exit_button.custom_minimum_size = Vector2(150, 60)
	exit_button.pressed.connect(plugin._on_exit)
	exit_row.add_child(exit_button)

	container.add_child(exit_row)

func _on_select_folder() -> void:
	var new_file_dialog = EditorFileDialog.new()
	
	# Configure dialog based on selection mode
	match selection_mode:
		SelectionMode.FOLDER_ONLY:
			new_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
		SelectionMode.FILE_ONLY:
			new_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		SelectionMode.FOLDER_OR_FILE:
			new_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_ANY
	
	new_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	new_file_dialog.title = "Select " + MODULE
	
	# Add file filters if applicable
	if selection_mode != SelectionMode.FOLDER_ONLY and not allowed_file_extensions.is_empty():
		for ext in allowed_file_extensions:
			new_file_dialog.add_filter("*." + ext, ext.to_upper() + " Files")
	
	# Connect appropriate signals
	new_file_dialog.dir_selected.connect(func(path):
		_on_folder_selected(path)
		new_file_dialog.queue_free()
	)
	new_file_dialog.file_selected.connect(func(path):
		_on_folder_selected(path)
		new_file_dialog.queue_free()
	)
	new_file_dialog.canceled.connect(func():
		new_file_dialog.queue_free()
	)
	
	plugin.get_editor_interface().get_base_control().add_child(new_file_dialog)
	new_file_dialog.popup_centered(Vector2i(800, 600))

func _on_folder_selected(path: String) -> void:
	selected_folder_path = path
	if selected_folder_label:
		var is_dir: bool = DirAccess.dir_exists_absolute(path)
		var selection_type: String = " (Folder)" if is_dir else " (File)"
		
		selected_folder_label.text = path + selection_type
		selected_folder_label.tooltip_text = path
		selected_folder_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		selected_folder_label.text_direction = Control.TEXT_DIRECTION_RTL		
		selected_folder_label.add_theme_color_override("font_color", Color(1, 1, 1))

	print("Selected: ", path)
	validate_and_enable_run_button()

	if file_dialog:
		file_dialog.queue_free()
		file_dialog = null

func _on_timeout_changed(new_text: String) -> void:
	if new_text.is_valid_int():
		import_wait_timeout = new_text.to_int()

func _on_run_button_press() -> void:
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
	generator.selected_folder_path = selected_folder_path
	generator.import_wait_timeout = import_wait_timeout
	var err: Error = await generator.process()
	if not err == OK:
		print("Please review the logs, there was an error: " + error_string(err))

	await plugin.get_tree().create_timer(5).timeout

	plugin.close_popup()

# Override in child classes to customize processing message
func get_processing_message() -> String:
	return "Processing started, see the Output tab for logs."
