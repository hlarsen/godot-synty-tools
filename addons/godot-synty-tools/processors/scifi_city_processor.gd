@tool
extends BaseProcessor
class_name SciFiCityProcessor

#signal selected_folder_changed(path: String)

var export_subdir: String = EXPORT_BASE_PATH.path_join("scifi_city")
var selected_folder_path: String = ""

const IMPORT_WAIT_TIMEOUT: int = 60

func set_folder(path: String) -> void:
	selected_folder_path = path
#	emit_signal("selected_folder_changed", path)

func process() -> bool:
	print("Clearing output directory before new run...")
	print("Deleting directory " + export_subdir)
	var err: Error = FileUtils.delete_directory_recursive(export_subdir)
	if not err == OK:
		push_error("Error deleting directory: " + export_subdir)
		return false

	# use a temp folder inside the project
	var temp_dir_path: String = TEMP_IMPORT_PATH_BASE + "-"+ str(Time.get_unix_time_from_system())
	var temp_dir: DirAccess = DirAccess.open(temp_dir_path)
	if not temp_dir:
		DirAccess.make_dir_recursive_absolute(temp_dir_path)
		temp_dir = DirAccess.open(temp_dir_path)
		if not temp_dir:
			push_error("Unable to create temp directory: " + str(DirAccess.get_open_error()))
			return false
	else:
		err = FileUtils.delete_directory_recursive(temp_dir_path)
		if not err == OK:
			push_error("Error deleting directory: " + export_subdir)
			return false
		DirAccess.make_dir_recursive_absolute(temp_dir_path)

	# copy files into the temp directory	
	var temp_fbx_path: String = temp_dir_path.path_join("FBX")
	var temp_png_path: String = temp_dir_path.path_join("Textures")
	print("Copying directory " + selected_folder_path + " to " + temp_dir_path)
	# maybe getting a file list would be faster? going to explore an EditorImportPlugin first
#	var file_list: Array[String] = FileUtils.list_files_recursive(selected_folder_path)
#	for file in file_list:
#		err = DirAccess.copy_absolute(file, temp_dir_path)
#	
#	err = FileUtils.copy_directory_recursive(selected_folder_path, temp_dir_path)
#	if not err == OK:
#		push_error("Error copying files")
#		return false

	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join("FBX"), temp_fbx_path)
	if not err == OK:
		push_error("Error copying files")
		return false

	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join("Textures"), temp_png_path)
	if not err == OK:
		push_error("Error copying files")
		return false

	var copied_fbx: Array[String] = FileUtils.list_files_recursive(temp_fbx_path).filter(func(f): return f.ends_with(".fbx"))
	var copied_png: Array[String] = FileUtils.list_files_recursive(temp_png_path).filter(func(f): return f.ends_with(".png"))

	# scan and wait for the signals to check that all files were imported (350ish animations for Base Locomotion)
	var efs: EditorFileSystem = plugin.get_editor_interface().get_resource_filesystem()
	if not await scan_and_wait_for_signal(efs, copied_fbx + copied_png, IMPORT_WAIT_TIMEOUT):
		push_error("Failed to reimport files")
		return false

	print("Finished with initial import")
	return true
