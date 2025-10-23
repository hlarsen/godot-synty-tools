@tool
extends BaseProcessor
class_name BaseLocomotionProcessor

#signal selected_folder_changed(path: String)

var selected_folder_path: String = ""

# Base Locomotion Bone Maps
const ANIM_BONE_MAP_POLYGON: String = "res://addons/godot-synty-tools/bone_maps/base_locomotion_v3_polygon.tres"
const ANIM_BONE_MAP_SIDEKICK: String = "res://addons/godot-synty-tools/bone_maps/base_locomotion_v3_sidekick.tres"
# The T-Pose animation we need to use as a RESET for the other animations
const ANIM_TPOSE_PATH_POLYGON: String = "Polygon/Neutral/Additive/TPose/A_TPose_Neut.fbx"
const ANIM_TPOSE_PATH_SIDEKICK: String = "Sidekick/Neutral/Additive/TPose/A_MOD_BL_TPose_Neut.fbx"
const DELETE_TEMP_DIR: bool = true
const EXPORT_PATH: String = "res://godot-synty-tools-output/"
# To properly track re-imports we have to listen for signals that reports each file was re-imported
# Sometimes there are issues so we give it a max timeout to wait so we're not stuck
const IMPORT_WAIT_TIMEOUT: int = 60
const RESET_ANIM_NAME: String = "RESET"
const TEMP_IMPORT_PATH_BASE: String = "res://godot-synty-tools-temp-import"

func set_folder(path: String) -> void:
	selected_folder_path = path
#	emit_signal("selected_folder_changed", path)

func process() -> bool:
	print("Clearing output directory before new run...")
	print("Deleting directory " + EXPORT_PATH)
	var err: int = FileUtils.delete_directory_recursive(EXPORT_PATH)
	if not err == OK:
		push_error("Error deleting directory: " + EXPORT_PATH)
		return false

	# use a temp folder inside the project
	# i'd rather use DirAccess.create_temp() but that lives outside the editor fs
	var temp_dir_path: String = TEMP_IMPORT_PATH_BASE + "-"+ str(Time.get_unix_time_from_system())
	var root_dir: DirAccess = DirAccess.open("res://")
	if root_dir.dir_exists(temp_dir_path):
		# shouldn't happen
		print("Clearing temp directory before new run...")
		print("Deleting directory " + temp_dir_path)
		FileUtils.delete_directory_recursive(temp_dir_path)
		print("Creating directory " + temp_dir_path)
		root_dir.make_dir_recursive(temp_dir_path)
	else:
		root_dir.make_dir_recursive(temp_dir_path)

	# selected_folder_path is the Animations folder, so copy that to our temp dir	
	var temp_animation_dir: String = temp_dir_path.path_join(selected_folder_path.get_file())
	print("Copying directory " + selected_folder_path + " to " + temp_animation_dir)
	err = FileUtils.copy_directory_recursive(selected_folder_path, temp_animation_dir)
	if not err == OK:
		push_error("Error copying files")
		return false

	# get a list of all the fbx files we copied so we can verify they imported
	var copied_files: Array[String] = FileUtils.list_files_recursive(temp_animation_dir).filter(func(f): return f.ends_with(".fbx"))
	print("Copied %d files" % copied_files.size())

	# scan and wait for the signals to check that all files were imported (350ish animations for Base Locomotion)
	var efs: EditorFileSystem = plugin.get_editor_interface().get_resource_filesystem()
	if not await scan_and_wait_for_signal(efs, copied_files):
		push_error("Failed to reimport files")
		return false
	print("Finished with initial import")

	# check that the .import files exist in case of failed imports
	if not FileUtils.verify_import_files_exist(copied_files):
		push_error("Failed to find .import files")
		return false
	print("All .import files verified")

	# ok, all files are imported - let's update the t-pose animation's .import
	print("Re-importing T-Pose animations")
	var temp_tpose_path_polygon: String = temp_animation_dir.path_join(ANIM_TPOSE_PATH_POLYGON)
	_update_tpose_import_settings(temp_tpose_path_polygon)
	var temp_tpose_path_sidekick: String = temp_animation_dir.path_join(ANIM_TPOSE_PATH_SIDEKICK)
	_update_tpose_import_settings(temp_tpose_path_sidekick)

	# re-import the file
	await plugin.get_tree().process_frame
	if not await scan_and_wait_for_signal(efs, [temp_tpose_path_polygon, temp_tpose_path_sidekick], 5):
		push_error("Failed to reimport tpose_tmp_path")
		return false

	# export the rest poses from the re-imported animation
	print("Exporting the re-imported T-Pose animations")
	var tpose_res_path_polygon: String = _export_animation_rest_pose_res_files(temp_tpose_path_polygon, temp_dir_path)
	var anim_library_polygon: AnimationLibrary = _create_tpose_animation_library(tpose_res_path_polygon, temp_dir_path)
	var tpose_res_path_sidekick: String = _export_animation_rest_pose_res_files(temp_tpose_path_sidekick, temp_dir_path)
	var anim_library_sidekick: AnimationLibrary = _create_tpose_animation_library(tpose_res_path_sidekick, temp_dir_path)
	if not anim_library_polygon or not anim_library_sidekick:
		push_error("Could not create animation library")
		return false

	# now we can re-import all of the animations to use the extracted t-pose (filtering out the t-pose animation)
	# NOTE: I'm not sure why but trying to fix/re-import the T-poses causes a timeout... maybe the re-import is failing?
	print("Updating .import files and re-importing animations to fix rest pose")
#	var anim_files_fixed_polygon: Array[String] = copied_files.filter(func(f): return "Polygon" in f)
	var anim_files_fixed_polygon: Array[String] = copied_files.filter(func(f): return "Polygon" in f and not f.ends_with("A_TPose_Neut.fbx"))
	await _reimport_animations_with_tpose(anim_files_fixed_polygon, anim_library_polygon, ANIM_BONE_MAP_POLYGON)
	var anim_files_fixed_sidekick: Array[String] = copied_files.filter(func(f): return "Sidekick" in f and not f.ends_with("A_MOD_BL_TPose_Neut.fbx"))
	await _reimport_animations_with_tpose(anim_files_fixed_sidekick, anim_library_sidekick, ANIM_BONE_MAP_SIDEKICK)
	await plugin.get_tree().process_frame
	if not await scan_and_wait_for_signal(efs, anim_files_fixed_polygon + anim_files_fixed_sidekick):
		push_error("Failed to reimport fixed animation files")
		return false

	# we are done, let's write some files (we already deleted the export path)
	# create the res files
	print("Exporting fixed animations...")
	var export_subdir: String = EXPORT_PATH.path_join("base_locomotion_animations")
	print("Export Subdir: " + export_subdir)
	_export_animation_res_files(anim_files_fixed_polygon, export_subdir, temp_dir_path)
	_export_animation_res_files(anim_files_fixed_sidekick, export_subdir, temp_dir_path)
	var export_subdir_polygon: String = export_subdir.path_join("Polygon")
	var export_subdir_sidekick: String = export_subdir.path_join("Sidekick")
	_create_animation_libraries(export_subdir_polygon)
	_create_animation_libraries(export_subdir_sidekick)

	# let's get rid of our temp directory
	if DELETE_TEMP_DIR:
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

	return true

func _export_animation_rest_pose_res_files(src_animation, dst_dir) -> String:
#	print("Exporting animations for file " + src_animation + " to dir " + dst_dir)
	var scene: PackedScene = ResourceLoader.load(src_animation)
	var root: Node = scene.instantiate()

	var src_base_name = src_animation.get_file().get_basename()

	var anim_path: String = ""
	for node in root.get_children():
		if node is AnimationPlayer:
			if node.has_animation(RESET_ANIM_NAME):
				var anim: Animation = node.get_animation(RESET_ANIM_NAME)
				anim_path = dst_dir.path_join(src_base_name + "-" + RESET_ANIM_NAME + ".res")
				ResourceSaver.save(anim, anim_path)

	root.queue_free()

	return anim_path

func _export_animation_res_files(animation_files, dst_dir, temp_dir_path) -> void:
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
					var anim: Animation = node.get_animation(StringName(str(anim_name)))
					if anim:
						# compute subdir relative to res://
						var subdir = src_animation.replace(temp_dir_path, "").get_base_dir()
						var full_dst_dir = dst_dir.path_join(subdir).replace("/Animations/", "/")
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
	var err: int = anim_library.add_animation(RESET_ANIM_NAME, reset_anim)
	if err != OK:
		return null	

	var src_base_name = tpose_rest_res_path.get_file().get_basename()

	# Save the library to a temporary location
	var library_path: String = temp_dir_path.path_join(src_base_name + "-tpose_library.res")
	err = ResourceSaver.save(anim_library, library_path)
	if err != OK:
		return null

	return anim_library

func _update_animation_import_settings(fbx_path: String, anim_library: AnimationLibrary, bone_map_path: String) -> int:
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
	var subresources_dict: Dictionary[String, Variant] = {
		"nodes": {
			"PATH:Skeleton3D": {
				"rest_pose/load_pose": 2,
				"rest_pose/external_animation_library": anim_library,
				"rest_pose/selected_animation": RESET_ANIM_NAME,
			}
		}
	}

	# Load the (known-good) bone map for base locomotion
	if bone_map_path != "":
		var bone_map: BoneMap = ResourceLoader.load(bone_map_path)
		if bone_map == null:
			push_error("Failed to load bone map from: " + bone_map_path)
			return FAILED

		# apply the bone map and specify the reset animation we extracted
		subresources_dict = {
			"nodes": {
				"PATH:Skeleton3D": {
					"rest_pose/load_pose": 2,
					"rest_pose/external_animation_library": anim_library,
					"rest_pose/selected_animation": RESET_ANIM_NAME,
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

func _reimport_animations_with_tpose(copied_files: Array[String], anim_library: AnimationLibrary, bone_map: String) -> void:
	for fbx_file in copied_files:
		_update_animation_import_settings(fbx_file, anim_library, bone_map)

func _create_animation_libraries(root_export_dir: String) -> void:
	var dir: DirAccess = DirAccess.open(root_export_dir)
	if not dir:
		push_error("Can't open root export directory: " + root_export_dir)
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
#			print("Creating AnimationLibrary for top-level folder: " + subfolder_path)
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
					var polygon_replacements: Dictionary[String, String] = {
						" - A_": " - ",
						"_Femn": "",
						"_Masc": "",
						"_Neut": "",
						"_": ""
					}
					
					var sidekick_replacements: Dictionary[String, String] = {
						"MODBL": "",
					}

					for old in polygon_replacements.keys():
						anim_name = anim_name.replace(old, polygon_replacements[old])

					for old in sidekick_replacements.keys():
						anim_name = anim_name.replace(old, sidekick_replacements[old])

					lib.add_animation(anim_name, anim)
		file_name = dir.get_next()
	dir.list_dir_end()
