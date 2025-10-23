@tool
extends BaseMenu

var select_folder_button: Button
var folder_label: Label
var status_label: Label
var run_button: Button
var selected_folder_path: String = ""

var SciFiCityProcessor = preload("res://addons/godot-synty-tools/processors/scifi_city_processor.gd")

func cleanup() -> void:
	selected_folder_path = ""

func build_content() -> void:
	# Instruction text
	var instruction = Label.new()
	instruction.text = "Select the Sci-Fi City folder to process"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	container.add_child(instruction)
	
	# Select folder button
	var button_container = HBoxContainer.new()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	select_folder_button = Button.new()
	select_folder_button.text = "Select Folder"
	select_folder_button.custom_minimum_size = Vector2(150, 40)
	select_folder_button.pressed.connect(_on_select_folder)
	button_container.add_child(select_folder_button)
	container.add_child(button_container)
	
	# Selected folder display
	folder_label = Label.new()
	folder_label.text = "No directory selected"
	folder_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	folder_label.clip_text = true
	folder_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	folder_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(folder_label)
	
	# Status label (hidden initially)
	status_label = Label.new()
	status_label.text = ""
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	status_label.visible = false
	container.add_child(status_label)
	
	# Run button
	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 10)
	
	run_button = Button.new()
	run_button.text = "Run"
	run_button.custom_minimum_size = Vector2(150, 60)
	run_button.disabled = true
	run_button.pressed.connect(_on_run)
	button_row.add_child(run_button)
	
	container.add_child(button_row)

func _on_select_folder() -> void:
	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Select Sci-Fi City Folder"
	
	file_dialog.dir_selected.connect(func(path):
		_set_folder(path)
		file_dialog.queue_free()
	)
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)
	
	plugin.get_editor_interface().get_base_control().add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _set_folder(path: String) -> void:
	selected_folder_path = path
	folder_label.text = path
	folder_label.tooltip_text = path
	folder_label.text_direction = Control.TEXT_DIRECTION_RTL
	folder_label.add_theme_color_override("font_color", Color(1, 1, 1))
	
	_validate_and_enable_run_button()

func _validate_and_enable_run_button() -> void:
	run_button.disabled = true
	
	if selected_folder_path.is_empty():
		return
	
	var dir: DirAccess = DirAccess.open(selected_folder_path)
	if dir == null:
		print("Not enabling run button, cannot open folder: " + selected_folder_path)
		return
	
	if not dir.file_exists("MaterialList_PolygonSciFiCity.txt"):
		print("Not enabling run button, could not find file: MaterialList_PolygonSciFiCity.txt")
		return
	
	run_button.disabled = false

func _on_run() -> void:
	print("Running Sci-Fi City processing with folder: ", selected_folder_path)
	run_button.disabled = true
	select_folder_button.disabled = true
	status_label.text = "Processing started, see Output tab for logs"
	status_label.visible = true
	folder_label.visible = false

	var processor = SciFiCityProcessor.new()
	processor.plugin = plugin
	processor.set_folder(selected_folder_path)
	await processor.process()

	print("Sci-Fi City processing finished!")
	plugin.close_popup()
