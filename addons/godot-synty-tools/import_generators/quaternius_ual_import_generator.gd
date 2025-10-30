@tool
extends BaseImportGenerator
class_name QuaterniusUALImportGenerator

var export_subdir: String = EXPORT_BASE_PATH.path_join(MODULE)
var selected_folder_path: String = ""
var post_import_script: String = POST_IMPORT_SCRIPT_BASE_PATH.path_join(MODULE + ".gd") 

const ANIM_BONE_MAP: String = "res://addons/godot-synty-tools/bone_maps/quaternius_ual.tres"
const KEEP_TEMP_DIR: bool = false
const MODULE: String = "quaternius_ual"

func process() -> Error:
	print("Running " + MODULE + " processing with folder: ", selected_folder_path)

#	print("Deleting output directory before new run: " + export_subdir)
	var err: Error = FileUtils.delete_directory_recursive(export_subdir)
	if not err == OK:
		push_error("Error deleting directory: " + export_subdir)
		return err

	print("Creating temp dir: " + MODULE)
	var temp_dir: DirAccess = DirAccess.create_temp(MODULE, KEEP_TEMP_DIR)
	if not temp_dir:
		push_error("Can't create temp directory: " + error_string(temp_dir.get_open_error()))
		return temp_dir.get_open_error()

	var temp_dir_path: String = temp_dir.get_current_dir()
	var temp_dir_file_path: String = temp_dir_path.path_join(selected_folder_path.get_file())
	print("Using temp dir: " + temp_dir_path)
	print("Copying file from " + selected_folder_path + " to " + temp_dir_path)
	err = FileUtils.copy_file(selected_folder_path, temp_dir_file_path)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	generate_import_file(temp_dir_file_path, export_subdir)
#	err = FileUtils.copy_file(temp_dir_file_path, export_subdir.path_join(temp_dir_file_path.get_file()))
	err = FileUtils.copy_directory_recursive(temp_dir_path, export_subdir)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	if not await reimport_files([temp_dir_file_path.replace(temp_dir_path, export_subdir)]):
		push_error("Failed to import animation file")
		return FAILED

	# NOTE: this happens now, but we haven't generated the actual animation Resources yet - this happens in post import
#	print("Creating animation library")
#	create_animation_libraries(export_subdir, export_subdir)

#	print("Cleaning up files")
#	var cleanup_polygon: Array[String] = FileUtils.list_files_recursive(export_subdir.path_join("Polygon")).filter(func(f): return f.ends_with(".fbx"))
#	var cleanup_sidekick: Array[String] = FileUtils.list_files_recursive(export_subdir.path_join("Sidekick")).filter(func(f): return f.ends_with(".fbx"))
#	var cleanup_misc: Array[String] = [
#		export_subdir.path_join("Polygon").path_join("AC_Polygon_Feminine.controller"),
#	]

#	var files_to_delete: Array[String] = (cleanup_polygon + cleanup_sidekick + cleanup_misc)
#	for file in files_to_delete:
#		err = DirAccess.remove_absolute(file)
#		if not err == OK:
#			push_error("Error deleting: " + error_string(err))
#			return err

#	err = FileUtils.delete_directory_recursive(tmp)
#	if not err == OK:
#		push_error("Error deleting: " + error_string(err))
#		return err

	print("Finished running " + MODULE + " processing with folder: ", selected_folder_path)

	return OK

func generate_import_file(src_file: String, export_subdir: String) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: deps > source_file and params/fbx_importer
	config.set_value("deps", "source_file", export_subdir.path_join(src_file.get_file()))
	config.set_value("params", "nodes/import_as_skeleton_bones", true)
	config.set_value("params", "import_script/path", post_import_script)
	config.set_value("params", "fbx/importer", 0)

	var bone_map: BoneMap = ResourceLoader.load(ANIM_BONE_MAP)
	if not bone_map:
		push_error("Failed to load animation libraries")
		return FAILED

	# advanced import settings - if you can't find docs for ui options, look them up in the engine:
	# https://github.com/godotengine/godot/blob/9cd297b6f2a0ee660b8f1a6b385582cccf3a9d10/editor/import/3d/resource_importer_scene.cpp#L2218
	var subresources_dict: Dictionary[String, Variant] = {
		"nodes": {
			"PATH:Skeleton3D": {
				"retarget/bone_map": bone_map,
				"retarget/bone_renamer/unique_node/make_unique": false,
				"retarget/bone_renamer/unique_node/skeleton_name": "Skeleton3D",
			}
		}
	}

	config.set_value("params", "_subresources", subresources_dict)

	return config.save(src_file + ".import")

#func create_animation_libraries(target_dir: String, export_dir: String) -> Error:
#	var dir := DirAccess.open(target_dir)
#	if not dir:
#		push_error("Can't open target directory: " + target_dir)
#		return FAILED
#
#	dir.include_navigational = false
#	dir.include_hidden = false
#	dir.list_dir_begin()
#
#	# Detect base type (Polygon or Sidekick)
#	var base_name := target_dir.get_file()
#	if base_name == "":
#		base_name = target_dir.get_base_dir().get_file()
#	if base_name == "":
#		base_name = "Unknown"
#
#	var masc_lib: AnimationLibrary = null
#	var fem_lib: AnimationLibrary = null
#
#	while true:
#		var folder_name := dir.get_next()
#		if folder_name == "":
#			break
#		if folder_name in [".", "..", TPOSE_WORKING_DIR]:
#			continue
#
#		var top_level_path := target_dir.path_join(folder_name)
#		if not dir.current_is_dir():
#			continue
#
#		if "Masculine" in folder_name:
#			masc_lib = AnimationLibrary.new()
#			masc_lib.set_name("%s-Masculine" % base_name)
#			add_animations_recursive(top_level_path, masc_lib, "")
#		elif "Feminine" in folder_name:
#			fem_lib = AnimationLibrary.new()
#			fem_lib.set_name("%s-Feminine" % base_name)
#			add_animations_recursive(top_level_path, fem_lib, "")
#		elif "Neutral" in folder_name:
#			if masc_lib:
#				add_animations_recursive(top_level_path, masc_lib, "")
#			if fem_lib:
#				add_animations_recursive(top_level_path, fem_lib, "")
#
#	# Save libraries if they exist
#	if masc_lib and masc_lib.get_animation_list().size() > 0:
#		var masc_path := export_dir.path_join(masc_lib.get_name() + ".tres")
#		ResourceSaver.save(masc_lib, masc_path)
#	if fem_lib and fem_lib.get_animation_list().size() > 0:
#		var fem_path := export_dir.path_join(fem_lib.get_name() + ".tres")
#		ResourceSaver.save(fem_lib, fem_path)
#
#	dir.list_dir_end()
#	return OK
#
#
#func add_animations_recursive(current_path: String, lib: AnimationLibrary, relative_prefix: String) -> void:
#	var dir: DirAccess = DirAccess.open(current_path)
#	if not dir:
#		push_error("Cannot open folder: " + current_path)
#		return
#
#	dir.include_navigational = false
#	dir.include_hidden = false
#	dir.list_dir_begin()
#
#	while true:
#		var file_name := dir.get_next()
#		if file_name == "":
#			break
#		if file_name in [".", ".."]:
#			continue
#
#		var file_path := current_path.path_join(file_name)
#		if dir.current_is_dir():
#			var new_prefix := relative_prefix
#			if new_prefix != "":
#				new_prefix += " - "
#			new_prefix += file_name
#			add_animations_recursive(file_path, lib, new_prefix)
#		elif file_name.ends_with(".res"):
#			if "RootMotion" in file_path:
#				continue
#
#			# transition animations (we're currently letting Godot blend between animations)
#			if "_To" in file_path:
#				continue
#
#			var anim: Resource = ResourceLoader.load(file_path)
#			if anim:
#				var anim_name := relative_prefix
#				if anim_name != "":
#					anim_name += " - "
#				anim_name += file_name.get_basename()
#
#				# cleanup
#				anim_name = file_name.get_basename()
#				lib.add_animation(anim_name, anim)
#
#	dir.list_dir_end()
