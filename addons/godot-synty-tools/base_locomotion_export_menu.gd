@tool
extends RefCounted

# TODO: pretty sure there's still a race condition/reimport check issue around _reimport_animations_with_tpose
# TODO: is there a way to make the Output tab active so the long are present?

var plugin: EditorPlugin
var file_dialog: EditorFileDialog
var select_folder_label: Label
var status_label: Label
var selected_folder_path: String = ""
var select_folder_button: Button
var run_button: Button

# Base Locomotion Bone Map
const ANIM_BONE_MAP_PATH: String = "res://addons/godot-synty-tools/bone_maps/base_locomotion_v3.tres"
# The T-Pose animation we need to use as a RESET for the other animations
const ANIM_TPOSE_PATH: String = "Neutral/Additive/TPose/A_TPose_Neut.fbx"
const DEFAULT_IMPORT_PATH: String = "res://temp_import"
const EXPORT_PATH: String = "res://godot-synty-tools-output/"
# To properly track re-imports we have to listen for signals that reports each file was re-imported
# Sometimes there are issues so we give it a max timeout to wait so we're not stuck
const IMPORT_WAIT_TIMEOUT: int = 30

func show_menu(button_grid: Control, popup_window: Window):
	# Replace grid with VBox for this menu
	var parent = button_grid.get_parent()
	button_grid.queue_free()
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	parent.add_child(vbox)
	
	# Update plugin reference
	plugin.button_grid = vbox
	
	# Instruction text
	var instruction = Label.new()
	instruction.text = "Select the Base Locomotion Animations/Polygon folder"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(instruction)
	
	# Select folder button (centered)
	var button_container = HBoxContainer.new()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	select_folder_button = Button.new()
	select_folder_button.text = "Select Folder"
	select_folder_button.custom_minimum_size = Vector2(150, 40)
	select_folder_button.pressed.connect(_on_select_folder.bind(popup_window))
	button_container.add_child(select_folder_button)
	vbox.add_child(button_container)

	# Selected folder display (below button)
	select_folder_label = Label.new()
	select_folder_label.text = "No directory selected"
	select_folder_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_folder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_folder_label.clip_text = true
	select_folder_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	select_folder_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(select_folder_label)

	# Status label (hidden by default)
	status_label = Label.new()
	status_label.text = ""
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))  # Orange/yellow color
	status_label.visible = false
	vbox.add_child(status_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
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
	
	# Back button
	var back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(150, 60)
	back_button.pressed.connect(plugin.go_back)
	button_row.add_child(back_button)
	
	vbox.add_child(button_row)

func _on_select_folder(popup_window: Window) -> void:
	# Create EditorFileDialog
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Select Animation Folder"

	# Connect signals
	file_dialog.dir_selected.connect(_on_folder_selected.bind(popup_window))
	file_dialog.canceled.connect(_on_folder_dialog_canceled)

	# Add to scene and show
	plugin.get_editor_interface().get_base_control().add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_folder_selected(path: String, popup_window: Window) -> void:
	selected_folder_path = path
	if select_folder_label:
		select_folder_label.text = path  # Just set the full path
		select_folder_label.tooltip_text = path  # Show full path on hover
		select_folder_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		select_folder_label.text_direction = Control.TEXT_DIRECTION_RTL		
		select_folder_label.add_theme_color_override("font_color", Color(1, 1, 1))

	print("Selected folder: ", path)

	_validate_and_enable_run_button()

	if file_dialog:
		file_dialog.queue_free()
		file_dialog = null

func _on_folder_dialog_canceled() -> void:
	if file_dialog:
		file_dialog.queue_free()
		file_dialog = null

# called from main.gd - need to refactor
func cleanup() -> void:
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
		file_dialog = null
	selected_folder_path = ""

func _validate_and_enable_run_button() -> void:
	run_button.disabled = true

	if selected_folder_path.is_empty():
		print("Not Enabling Run Button: No folder selected")
		return

	var dir: DirAccess = DirAccess.open(selected_folder_path)
	if dir == null:
		print("Not Enabling Run Button: Cannot open dir: ", selected_folder_path)
		return

	if not selected_folder_path.get_file() == "Polygon":
		print("Not Enabling Run Button: Invalid directory (Select Base Locomotion Animations/Polygon folder): ", selected_folder_path)
		return

	# verify the t-pose is where we expect it to be
	if not dir.file_exists(ANIM_TPOSE_PATH):
		print("Not Enabling Run Button: Could not find T-Pose fbx")
		return

	run_button.disabled = false

func _on_run_button_press() -> void:
	print("Running BaseLocomotionExport with folder: ", selected_folder_path)
	run_button.disabled = true
	select_folder_button.disabled = true
	status_label.text = "Export started, see Output tab for logs"
	status_label.visible = true

	print("Clearing output directory before new run...")
	print("Deleting directory " + EXPORT_PATH)
	var err: int = FileUtils.delete_directory_recursive(EXPORT_PATH)
	if not err == OK:
		push_error("Error deleting directory: " + EXPORT_PATH)
		return

	# use a temp folder inside the project
	# i'd rather use DirAccess.create_temp() but that lives outside the editor fs
	var temp_dir_path: String = DEFAULT_IMPORT_PATH
	var root_dir: DirAccess = DirAccess.open("res://")
	if root_dir.dir_exists(temp_dir_path):
		print("Clearing temp directory before new run...")
		print("Deleting directory " + temp_dir_path)
		FileUtils.delete_directory_recursive(temp_dir_path)
		print("Creating directory " + temp_dir_path)
		root_dir.make_dir_recursive(temp_dir_path)
	else:
		root_dir.make_dir_recursive(temp_dir_path)

	# selected_folder_path is the Polygon folder, so copy that to our temp dir	
	var temp_animation_dir: String = temp_dir_path.path_join(selected_folder_path.get_file())
	print("Copying directory " + selected_folder_path + " to " + temp_animation_dir)
	err = FileUtils.copy_directory_recursive(selected_folder_path, temp_animation_dir)
	if not err == OK:
		push_error("Error copying files")
		return

	# get a list of all the fbx files we copied so we can verify they imported
	var copied_files: Array[String] = FileUtils.list_files_recursive(temp_animation_dir).filter(func(f): return f.ends_with(".fbx"))
	print("Copied %d files" % copied_files.size())

	# scan and wait for the signals to check that all files were imported (350ish animations for Base Locomotion)
	var efs: EditorFileSystem = plugin.get_editor_interface().get_resource_filesystem()
	if not await scan_and_wait_for_signal(efs, copied_files):
		push_error("Failed to reimport files")
		plugin.close_popup()
		return
	print("Finished with initial import")

	# check that the .import files exist in case of failed imports
	if not FileUtils.verify_import_files_exist(copied_files):
		push_error("Failed to find .import files")
		plugin.close_popup()
		return
	print("All .import files verified")

	# ok, all files are imported - let's update the t-pose animation's .import
	var tpose_tmp_path: String = temp_animation_dir.path_join(ANIM_TPOSE_PATH)
	_update_tpose_import_settings(tpose_tmp_path)

	# re-import the file
	await plugin.get_tree().process_frame
	if not await scan_and_wait_for_signal(efs, [tpose_tmp_path], 5):
		push_error("Failed to reimport tpose_tmp_path")
		plugin.close_popup()
		return

	# export the rest pose from the re-imported animation
	var tpose_rest_res_path: String = _export_animation_rest_pose_res_files(tpose_tmp_path, temp_dir_path)
	var anim_library: AnimationLibrary = _create_tpose_animation_library(tpose_rest_res_path, temp_dir_path)
	if not anim_library:
		push_error("Could not create animation library")
		plugin.close_popup()
		return

	# now we can re-import all of the animations to use the extracted t-pose
	print("Updating .import and re-importing animations")
	var anim_files_with_tpose: Array[String] = copied_files.filter(func(f): return not f.ends_with("A_TPose_Neut.fbx"))
	await _reimport_animations_with_tpose(anim_files_with_tpose, anim_library)
	await plugin.get_tree().process_frame
	if not await scan_and_wait_for_signal(efs, anim_files_with_tpose):
		push_error("Failed to reimport fixed tpose files")
		plugin.close_popup()
		return

	# we are done, let's write some files (we already deleted the export path)
	# create the res files
	print("Exporting fixed animations...")
	var export_subdir: String = EXPORT_PATH.path_join("base_locomotion_animations")
	root_dir.make_dir_recursive(export_subdir)
	_export_animation_res_files(anim_files_with_tpose, export_subdir)
	_create_animation_libraries(export_subdir.path_join("Polygon"))

	# let's get rid of our temp directory
	print("Deleting temp directory " + temp_dir_path)
	FileUtils.delete_directory_recursive(temp_dir_path)

	# one last scan so the filesystem explorer is updated
	if not efs.is_scanning():
		efs.scan()

	await plugin.get_tree().process_frame
	while efs.is_scanning():
		print("FS is scanning, waiting .2 seconds")
		await plugin.get_tree().create_timer(.2).timeout
	print("FS is finished scanning")

	print("BaseLocomotionExport Finished!")
	plugin.close_popup()

func _export_animation_rest_pose_res_files(src_animation, dst_dir) -> String:
	print("Exporting animations for file " + src_animation + " to dir " + dst_dir)
	var scene: PackedScene = ResourceLoader.load(src_animation)
	var root: Node = scene.instantiate()
	
	var anim_path: String = ""
	for node in root.get_children():
		if node is AnimationPlayer:
			if node.has_animation("RESET"):
				var anim: Animation = node.get_animation("RESET")
				anim_path = dst_dir.path_join("RESET.res")
				ResourceSaver.save(anim, anim_path)

	root.queue_free()

	return anim_path

func _export_animation_res_files(animation_files, dst_dir) -> void:
	var dir: DirAccess = DirAccess.open("res://")

	for src_animation in animation_files:
		var scene: PackedScene = ResourceLoader.load(src_animation)
		var root: Node = scene.instantiate()
		for node in root.get_children():
			if node is AnimationPlayer:
				if node.get_animation_list().size() != 1:
					push_error("More than one animation found for " + src_animation)
					continue
					
				for anim_name in node.get_animation_list():
					var anim: Animation = node.get_animation(anim_name)
					if anim:
						# compute subdir relative to res://
						var subdir = src_animation.replace(DEFAULT_IMPORT_PATH, "").get_base_dir()
						var full_dst_dir = dst_dir.path_join(subdir)
						dir.make_dir_recursive(full_dst_dir)
						
						var anim_path = full_dst_dir.path_join("%s.res" % anim_name)
#						print("Saving animation " + src_animation + " to " + anim_path)
						ResourceSaver.save(anim, anim_path)
	
		root.queue_free()

func _update_tpose_import_settings(fbx_path: String) -> int:
#	print("Modifying .import config file for: ", fbx_path)

	var import_file: String = fbx_path + ".import"
	if not FileAccess.file_exists(import_file):
		push_error("Import file was not auto-created by Godot: " + import_file)
		return ERR_CANT_OPEN

	var config = ConfigFile.new()
	var err = config.load(import_file)
	if err != OK:
		push_error("Failed to load import config: " + import_file)
		return err

	# advanced import settings
	config.set_value("params", "nodes/import_as_skeleton_bones", true)
	config.set_value("params", "animation/remove_immutable_tracks", false)
	config.set_value("params", "animation/import_rest_as_RESET", true)

	err = config.save(import_file)
	if err != OK:
		push_error("Failed to save import config: " + import_file)
		return err

	return OK

func _create_tpose_animation_library(tpose_rest_res_path: String, temp_dir_path: String) -> AnimationLibrary:
	# Load the RESET animation and create an AnimationLibrary
	var reset_anim: Animation = ResourceLoader.load(tpose_rest_res_path)
	if reset_anim == null:
		push_error("Failed to load RESET animation from: " + tpose_rest_res_path)
		return null

	# Create an AnimationLibrary and add the RESET animation
	var anim_library = AnimationLibrary.new()
	var err: int = anim_library.add_animation("RESET", reset_anim)
	if err != OK:
		return null	

	# Save the library to a temporary location
	var library_path: String = temp_dir_path.path_join("tpose_library.res")
	err = ResourceSaver.save(anim_library, library_path)
	if err != OK:
		return null

	return anim_library

func _update_animation_import_settings(fbx_path: String, anim_library: AnimationLibrary) -> int:
#	print("Modifying .import config file for :", fbx_path)

	var import_file: String = fbx_path + ".import"
	if not FileAccess.file_exists(import_file):
		push_error("Import file was not auto-created by Godot: " + import_file)
		return FAILED

	var config = ConfigFile.new()
	var err = config.load(import_file)
	if err != OK:
		push_error("Failed to load import config: " + import_file)
		return err

	# advanced import settings - if you can't find docs for ui options, look them up in the engine:
	# https://github.com/godotengine/godot/blob/9cd297b6f2a0ee660b8f1a6b385582cccf3a9d10/editor/import/3d/resource_importer_scene.cpp#L2218

	# Load the (known-good) bone map for base locomotion
	var bone_map: BoneMap = ResourceLoader.load(ANIM_BONE_MAP_PATH)
	if bone_map == null:
		push_error("Failed to load bone map from: " + ANIM_BONE_MAP_PATH)
		return FAILED

	# apply the bone map and specify the reset animation we extracted
	var subresources_dict: Dictionary[String, Variant] = {
		"nodes": {
			"PATH:Skeleton3D": {
				"rest_pose/load_pose": 2,
				"rest_pose/external_animation_library": anim_library,
				"rest_pose/selected_animation": "RESET",
				"retarget/bone_map": bone_map,
			}
		}
	}

	config.set_value("params", "_subresources", subresources_dict)

	err = config.save(import_file)
	if err != OK:
		push_error("Failed to save import config: " + import_file)
		return err

	return OK

# NOTE: Using this for reimport as well since can't get reimport_files() to work properly without the editor
# complaining if I alt tab about an import already running... doesn't seem like you can check if one is running
func scan_and_wait_for_signal(efs: EditorFileSystem, file_paths: Array[String], timeout_seconds: float = IMPORT_WAIT_TIMEOUT) -> bool:
	print("Waiting up to " + str(timeout_seconds) + " seconds for reimport of %d files" % file_paths.size())

	var files_to_wait: Array = file_paths.duplicate()
	var start_time: int = Time.get_ticks_msec()

	# connect signal handler BEFORE triggering reimport
	var on_reimport = func(resources: PackedStringArray):
#		print_debug("Resources reimported signal received with %d files" % resources.size())

		# check for reimported files
		for i in range(files_to_wait.size() - 1, -1, -1):  # Iterate backwards so we can remove
			if files_to_wait[i] in resources:
#				print_debug("Reimported: " + files_to_wait[i])
				files_to_wait.remove_at(i)

	efs.resources_reimported.connect(on_reimport)

	if not efs.is_scanning():
		efs.scan()

	await plugin.get_tree().process_frame
	while efs.is_scanning():
		print("FS is scanning, waiting .2 seconds")
		await plugin.get_tree().create_timer(.2).timeout
	print("FS is finished scanning, waiting for import to finish...")

	# wait until all files are reimported or timeout
	while files_to_wait.size() > 0:
		var elapsed: float = (Time.get_ticks_msec() - start_time) / 1000.0

		if elapsed > timeout_seconds:
			push_error("Reimport timeout after %.1f seconds. Still waiting for:" % elapsed)
			for file in files_to_wait:
				push_error("  - " + file)
			efs.resources_reimported.disconnect(on_reimport)
			return false

#		print("Still waiting for %d files (%.1fs elapsed)" % [files_to_wait.size(), elapsed])
		await plugin.get_tree().create_timer(0.2).timeout

	# disconnect from the signal
	efs.resources_reimported.disconnect(on_reimport)

	print("All files successfully reimported")
	return true

func _reimport_animations_with_tpose(copied_files: Array[String], anim_library: AnimationLibrary) -> void:
	for fbx_file in copied_files:
		_update_animation_import_settings(fbx_file, anim_library)

func _create_animation_libraries(root_export_dir: String) -> void:
	var dir: DirAccess = DirAccess.open(root_export_dir)
	if not dir:
		push_error("Cannot open root export directory: " + root_export_dir)
		return
	
	dir.include_navigational = false
	dir.include_hidden = false
	dir.list_dir_begin()
	var folder_name: String = dir.get_next()
	while folder_name != "":
		if folder_name in [".", ".."]:
			folder_name = dir.get_next()
			continue

		var subfolder_path: String = root_export_dir.path_join(folder_name)
		if dir.current_is_dir():
			print("Creating AnimationLibrary for top-level folder: " + subfolder_path)
			_create_anim_library_for_top_level_folder(subfolder_path, root_export_dir)
		folder_name = dir.get_next()
	dir.list_dir_end()


func _create_anim_library_for_top_level_folder(folder_path: String, root_export_dir: String) -> void:
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.set_name(folder_path.get_file())

	_add_animations_recursive(folder_path, lib, "")

	if lib.get_animation_list().size() > 0:
		var lib_path: String = root_export_dir.path_join(folder_path.get_file() + ".tres")
		ResourceSaver.save(lib, lib_path)
#		print("Saved AnimationLibrary: " + lib_path)


func _add_animations_recursive(current_path: String, lib: AnimationLibrary, relative_prefix: String) -> void:
	var dir: DirAccess = DirAccess.open(current_path)
	if not dir:
		push_error("Cannot open folder: " + current_path)
		return

	dir.include_navigational = false
	dir.include_hidden = false
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name in [".", ".."]:
			file_name = dir.get_next()
			continue

		var file_path: String = current_path.path_join(file_name)
		if dir.current_is_dir():
			var new_prefix: String = relative_prefix
			if new_prefix != "":
				new_prefix += " - "
			new_prefix += file_name
			_add_animations_recursive(file_path, lib, new_prefix)
		else:
			if file_name.ends_with(".res"):
				var anim: Resource = ResourceLoader.load(file_path)
				if anim:
					var anim_name: String = relative_prefix
					if anim_name != "":
						anim_name += " - "
					anim_name += file_name.get_basename()

					# clean up the names a bit
					var patterns: Dictionary[String, String] = {
						" - A_": " - ",
						"_Femn": "",
						"_Masc": "",
						"_Neut": "",
						"_": ""
					}

					for old in patterns.keys():
						anim_name = anim_name.replace(old, patterns[old])

					lib.add_animation(anim_name, anim)
		file_name = dir.get_next()
	dir.list_dir_end()
