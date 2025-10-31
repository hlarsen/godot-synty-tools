@tool
extends BaseImportGenerator
class_name QuaterniusUALImportGenerator

var export_subdir: String = EXPORT_BASE_PATH.path_join(MODULE)
var post_import_script: String = POST_IMPORT_SCRIPT_BASE_PATH.path_join(MODULE + ".gd") 

const BONE_MAP: String = "res://addons/godot-synty-tools/bone_maps/quaternius_ual.tres"
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
	err = FileUtils.copy_directory_recursive(temp_dir_path, export_subdir)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	if not await reimport_files([temp_dir_file_path.replace(temp_dir_path, export_subdir)], import_wait_timeout):
		push_error("Failed to import animation file")
		return FAILED

	print("Finished running " + MODULE + " processing with folder: ", selected_folder_path)

	return OK

func generate_import_file(src_file: String, export_subdir: String) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: deps > source_file and params/fbx_importer
	config.set_value("deps", "source_file", export_subdir.path_join(src_file.get_file()))
	config.set_value("params", "nodes/import_as_skeleton_bones", true)
	config.set_value("params", "import_script/path", post_import_script)
	config.set_value("params", "fbx/importer", 0)

	var bone_map: BoneMap = ResourceLoader.load(BONE_MAP)
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
