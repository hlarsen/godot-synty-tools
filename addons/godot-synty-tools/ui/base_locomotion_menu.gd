@tool
extends BaseMenu

var file_dialog: EditorFileDialog
var run_button: Button
var select_folder_button: Button
var selected_folder_label: Label
var selected_folder_path: String = ""
var status_label: Label

var processor = preload("res://addons/godot-synty-tools/processors/base_locomotion_processor.gd")

func cleanup() -> void:
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
		file_dialog = null
	selected_folder_path = ""

func build_content() -> void:
	# Instruction text
	var instruction = Label.new()
	instruction.text = "Select the Base Locomotion Animations/Polygon folder"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	container.add_child(instruction)
	
	# Select folder button (centered)
	var button_container = HBoxContainer.new()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	select_folder_button = Button.new()
	select_folder_button.text = "Select Folder"
	select_folder_button.custom_minimum_size = Vector2(150, 40)
	select_folder_button.pressed.connect(_on_select_folder)
	button_container.add_child(select_folder_button)
	container.add_child(button_container)

	# Selected folder display (below button)
	selected_folder_label = Label.new()
	selected_folder_label.text = "No directory selected"
	selected_folder_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_folder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_folder_label.clip_text = true
	selected_folder_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected_folder_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(selected_folder_label)

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
	
	# Run button
	run_button = Button.new()
	run_button.text = "Run"
	run_button.custom_minimum_size = Vector2(150, 60)
	run_button.disabled = true
	run_button.pressed.connect(_on_run_button_press)
	button_row.add_child(run_button)
	
	container.add_child(button_row)

func _on_select_folder() -> void:
	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Select Animation Folder"

	file_dialog.dir_selected.connect(func(path):
		_on_folder_selected(path)
		file_dialog.queue_free()
	)
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)

	plugin.get_editor_interface().get_base_control().add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_folder_selected(path: String) -> void:
	selected_folder_path = path
	if selected_folder_label:
		selected_folder_label.text = path
		selected_folder_label.tooltip_text = path
		selected_folder_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		selected_folder_label.text_direction = Control.TEXT_DIRECTION_RTL		
		selected_folder_label.add_theme_color_override("font_color", Color(1, 1, 1))

	print("Selected folder: ", path)
	_validate_and_enable_run_button()

	if file_dialog:
		file_dialog.queue_free()
		file_dialog = null

func _validate_and_enable_run_button() -> void:
	run_button.disabled = true

	if selected_folder_path.is_empty():
		print("Not Enabling Run Button: No folder selected")
		return

	var dir: DirAccess = DirAccess.open(selected_folder_path)
	if dir == null:
		print("Not Enabling Run Button: Cannot open dir: ", selected_folder_path)
		return

#	if not dir.file_exists("MaterialList_PolygonSciFiCity.txt"):
#		print("Not enabling run button, could not find file: MaterialList_PolygonSciFiCity.txt")
#		return

	if not selected_folder_path.get_file() == "Animations":
		print("Not Enabling Run Button: Invalid directory (Select Base Locomotion Animations folder): ", selected_folder_path)
		return

	run_button.disabled = false

func _on_run_button_press() -> void:
	print("Running Base Locomotion processing with folder: ", selected_folder_path)
	run_button.disabled = true
	select_folder_button.disabled = true
	status_label.text = "Processing started, do not interact with the editor!\nSee the Output tab for logs."
	status_label.visible = true
	selected_folder_label.visible = false

	var processor = processor.new()
	processor.plugin = plugin
	processor.set_folder(selected_folder_path)
	var results: bool = await processor.process()
	if results:
		print("Processing finished!")
	else:
		print("There was an error, please review the logs.")
	
	plugin.close_popup()
