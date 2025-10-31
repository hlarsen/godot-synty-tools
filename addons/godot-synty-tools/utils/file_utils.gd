@tool
class_name FileUtils

static func list_files_recursive(base_path: String) -> Array[String]:
	var files: Array[String] = []

	var dir: DirAccess = DirAccess.open(base_path)
	if not dir:
		push_error("Cannot open directory for listing: " + base_path)
		return files

	dir.include_navigational = false
	dir.include_hidden = false
	
	var dir_items: PackedStringArray = dir.get_files() + dir.get_directories()
	for dir_item in dir_items:
		var full_path: String = base_path.path_join(dir_item)
		if DirAccess.dir_exists_absolute(full_path):
			files.append_array(list_files_recursive(full_path))
		else:
			files.append(full_path)

	return files

static func copy_directory_recursive(src_path: String, dst_path: String, ext_filter: Array[String] = []) -> int:
	var root_dir: DirAccess = DirAccess.open("res://")
	if not root_dir:
		push_error("Cannot open root_dir to create directories")
		return ERR_CANT_OPEN

	var err: int = root_dir.make_dir_recursive(dst_path)
	if err != OK:
		push_error("Cannot create destination directory: " + dst_path)
		return err

	var src_dir: DirAccess = DirAccess.open(src_path)
	if not src_dir:
		push_error("Cannot open source directory: " + src_path)
		return ERR_CANT_OPEN

	src_dir.include_navigational = false
	src_dir.include_hidden = false
	
	var dir_items: PackedStringArray = src_dir.get_files() + src_dir.get_directories()
	for dir_item in dir_items:
		var src_file_path: String = src_path.path_join(dir_item)
		var dst_file_path: String = dst_path.path_join(dir_item)

		if DirAccess.dir_exists_absolute(src_file_path):
			err = copy_directory_recursive(src_file_path, dst_file_path, ext_filter)
			if err != OK:
				push_error("Cannot copy from " + src_path + " to " + dst_path)
				return FAILED
		else:
			if not ext_filter.is_empty():
				if not src_file_path.get_extension().to_lower() in ext_filter:
					push_warning("Not copying file with extension: " + src_file_path)
					continue

			err = src_dir.copy(src_file_path, dst_file_path)
			if err != OK:
				push_error("Error copying file: " + dir_item)
				return FAILED

	return OK

static func delete_directory_recursive(path: String) -> int:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return OK

	dir.include_navigational = false
	dir.include_hidden = false
	
	var dir_items: PackedStringArray = dir.get_files() + dir.get_directories()
	for dir_item in dir_items:
		var file_path: String = path.path_join(dir_item)

		if DirAccess.dir_exists_absolute(file_path):
			var err: int = delete_directory_recursive(file_path)
			if err != OK:
				push_error("Error deleting directory: " + dir_item)
				return err
		else:
			var err: int = dir.remove(dir_item)
			if err != OK:
				push_error("Error deleting file: " + dir_item)
				return err

	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func copy_file(src_file: String, dst_file: String) -> int:
	var root_dir: DirAccess = DirAccess.open("res://")
	if not root_dir:
		push_error("Cannot open root_dir to create directories")
		return ERR_CANT_OPEN

	var err: int = root_dir.make_dir_recursive(dst_file.get_base_dir())
	if err != OK:
		push_error("Cannot create destination directory for file: " + dst_file)
		return FAILED

	var src_dir: DirAccess = DirAccess.open(src_file.get_base_dir())
	if not src_dir:
		push_error("Cannot open source directory for file: " + src_file)
		return FAILED

	return src_dir.copy(src_file, dst_file)

static func verify_import_files_exist(file_paths: Array[String]) -> bool:
	var all_exist: bool = true
	var missing_files: Array[String] = []

	for file_path in file_paths:
		var import_file: String = file_path + ".import"
		if not FileAccess.file_exists(import_file):
			all_exist = false
			missing_files.append(file_path)
			push_error("Missing .import file for: " + file_path)

	if all_exist:
		return true
	else:
		push_error("Failed to verify %d .import files:" % missing_files.size())
		for file in missing_files:
			push_error(" - " + file)
		return false
