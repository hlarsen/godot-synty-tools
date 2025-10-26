@tool
extends BaseImportGenerator
class_name ScifiCityImportGenerator

var export_subdir: String = EXPORT_BASE_PATH.path_join("scifi_city")
var selected_folder_path: String = ""
var post_import_script: String = POST_IMPORT_SCRIPT_BASE_PATH.path_join("scifi_city.gd") 

const BONE_MAP: String = "res://addons/godot-synty-tools/bone_maps/scifi_city_v4.tres"
const KEEP_TEMP_DIR: bool = false
const IMPORT_WAIT_TIMEOUT: int = 60
const MODULE: String = "scifi_city"

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
	print("Using temp dir: " + temp_dir_path)
	print("Copying files from " + selected_folder_path + " to " + temp_dir_path)
	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join("FBX"), temp_dir_path.path_join("FBX"))

	# copy text textures to the project first because we reference them in the post import of the fbx files
	print("Copying files from " + selected_folder_path.path_join("Textures") + " to " + export_subdir.path_join("Textures"))
	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join("Textures"), export_subdir.path_join("Textures"))
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	if not await reimport_files(FileUtils.list_files_recursive(export_subdir.path_join("Textures")), 10):
		push_error("Failed to import textures files")
		return FAILED

#	# do we need materials processing first?
#	print("Processing materials")
#	var textures: Array[String] = FileUtils.list_files_recursive(export_subdir.path_join("Textures")).filter(func(f): return f.ends_with(".png"))
#	for tex_fn in textures:
#		var tex: Texture2D = ResourceLoader.load(tex_fn)
##		print("Loaded:", tex_fn, "Class:", tex.get_class(), "Size:", tex.get_size())

	# textures are in the project, time for the fbx files
	var imports_to_create: Array[String] = FileUtils.list_files_recursive(temp_dir_path).filter(func(f): return f.ends_with(".fbx"))
	var expected_imports: Array[String] = []
	print("Adding .import files for " + str(imports_to_create.size()) + " FBX files in " + temp_dir_path)
	for file in imports_to_create:
		if not file.ends_with(".fbx"):
			continue

		if file.ends_with("Characters.fbx"):
			var bone_map: BoneMap = ResourceLoader.load(BONE_MAP)
			if not bone_map:
				push_error("Failed to load bone map")
				return FAILED

			err = generate_character_fbx_import_file(file, temp_dir_path, bone_map)
			if not err == OK:
				push_error("Error updating character file: " + error_string(err))
				return err

			expected_imports.append(file.replace(temp_dir_path, export_subdir))
			continue

#		print("Generating import file for: " + file)
		var tmp_file_path: String = file.replace(temp_dir_path, export_subdir)
		err = generate_fbx_import_file(file, tmp_file_path)
		if not err == OK:
			push_error("Error generating import file for " + file + ": " + error_string(err))
			return err

		expected_imports.append(file.replace(temp_dir_path, export_subdir))

	print("Copy files from " + temp_dir_path + " to " + export_subdir)
	err = FileUtils.copy_directory_recursive(temp_dir_path, export_subdir)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	if not await reimport_files(expected_imports, IMPORT_WAIT_TIMEOUT):
		push_error("Failed to import fixed animation files")
		return FAILED

	print("Finished running " + MODULE + " processing with folder: ", selected_folder_path)

	return OK

func generate_fbx_import_file(src_file, tmp_file_path) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: deps > source_file and params/fbx_importer
	config.set_value("deps", "source_file", tmp_file_path)
	config.set_value("params", "import_script/path", post_import_script)
	config.set_value("params", "fbx/importer", 0)

	return config.save(src_file + ".import")

func generate_character_fbx_import_file(src_file: String, tmp_file_path: String, bone_map: BoneMap) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: deps > source_file and params/fbx_importer
	config.set_value("deps", "source_file", tmp_file_path)
	config.set_value("params", "import_script/path", post_import_script)
	config.set_value("params", "fbx/importer", 0)

	# advanced import settings - if you can't find docs for ui options, look them up in the engine:
	# https://github.com/godotengine/godot/blob/9cd297b6f2a0ee660b8f1a6b385582cccf3a9d10/editor/import/3d/resource_importer_scene.cpp#L2218
	var subresources_dict: Dictionary[String, Variant] = {
		"nodes": {
			"PATH:Skeleton3D": {
#				"unique_name_in_owner": false,
				"retarget/bone_map": bone_map,
				"retarget/bone_renamer/unique_node/make_unique": false,
			}
		}
	}

	config.set_value("params", "_subresources", subresources_dict)

	return config.save(src_file + ".import")
