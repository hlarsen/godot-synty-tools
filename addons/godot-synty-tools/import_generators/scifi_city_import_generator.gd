@tool
extends BaseImportGenerator
class_name ScifiCityImportGenerator

var export_subdir: String = EXPORT_BASE_PATH.path_join("scifi_city")
var selected_folder_path: String = ""
var post_import_script: String = POST_IMPORT_SCRIPT_BASE_PATH.path_join("scifi_city.gd") 

const DELETE_TEMP_DIR: bool = true

func process() -> Error:
#	print("Deleting output directory before new run: " + export_subdir)
	var err: Error = FileUtils.delete_directory_recursive(export_subdir)
	if not err == OK:
		push_error("Error deleting directory: " + export_subdir)
		return err

	print("Creating temp dir")
	var temp_dir: DirAccess = DirAccess.create_temp("scifi_import", DELETE_TEMP_DIR)
	if not temp_dir:
		push_error("Can't create temp directory: " + error_string(temp_dir.get_open_error()))
		return temp_dir.get_open_error()

	var temp_dir_path: String = temp_dir.get_current_dir()
	print("Using temp dir: " + temp_dir_path)
	print("Copying files from " + selected_folder_path + " to " + temp_dir_path)
	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join("FBX"), temp_dir_path.path_join("FBX"))
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join("Textures"), temp_dir_path.path_join("Textures"))
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	var imports_to_create: Array[String] = FileUtils.list_files_recursive(temp_dir_path).filter(func(f): return f.ends_with(".fbx"))
	print("Adding .import files for " + str(imports_to_create.size()) + " FBX files in " + temp_dir_path)
	for file in imports_to_create:
		if not file.ends_with(".fbx"):
			continue

		print("Generating import file for: " + file)
		var tmp_file_path: String = file.replace(temp_dir_path, export_subdir)
		err = generate_fbx_import_file(file, tmp_file_path)
		if not err == OK:
			push_error("Error generating import file for " + file + ": " + error_string(err))
			return err

	print("Copy files from " + temp_dir_path + " to " + export_subdir)
	err = FileUtils.copy_directory_recursive(temp_dir_path, export_subdir)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	# kick off a scan in case one is not started by the file copeis
	var efs: EditorFileSystem = plugin.get_editor_interface().get_resource_filesystem()
	if not efs.is_scanning():
		efs.scan()

	return OK

func generate_fbx_import_file(src_file, tmp_file_path) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: deps > source_file and params/fbx_importer
	config.set_value("deps", "source_file", tmp_file_path)
	config.set_value("params", "import_script/path", post_import_script)
	config.set_value("params", "fbx/importer", 0)

	return config.save(src_file + ".import")
