@tool
class_name FileUtils

static func list_files_recursive(base_path: String) -> Array[String]:
#	print("\nProcessing directory list for: " + base_path)

	var files: Array[String] = []
	var dir := DirAccess.open(base_path)
	if not dir:
		push_error("Cannot open directory for listing: " + base_path)
		return files

	dir.include_navigational = false
	dir.include_hidden = false
	dir.list_dir_begin()
	var dir_item: String = dir.get_next()
	while dir_item != "":
		var full_path := base_path.path_join(dir_item)
		if dir.current_is_dir():
			files.append_array(list_files_recursive(full_path))
		else:
			files.append(full_path)
		dir_item = dir.get_next()
	dir.list_dir_end()

	return files

static func copy_directory_recursive(src_path: String, dst_path: String) -> int:
#	print("\nProcessing directory copy for: " + src_path + " to " + dst_path)

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
	src_dir.list_dir_begin()
	var dir_item: String = src_dir.get_next()
	while dir_item != "":
		var src_file_path: String = src_path.path_join(dir_item)
		var dst_file_path: String = dst_path.path_join(dir_item)

		if src_dir.current_is_dir():
#			print_debug("Recursively copying directory " + src_file_path)
			err = copy_directory_recursive(src_file_path, dst_file_path)
			if err != OK:
				push_error("Cannot copy from " + src_path + " to " + dst_path)
				return FAILED
		else:
#			print_debug("Copying file " + src_file_path + " to " + dst_file_path)
			err = src_dir.copy(src_file_path, dst_file_path)
			if err != OK:
				push_error("Error copying file: " + dir_item)
				return FAILED

		dir_item = src_dir.get_next()

	src_dir.list_dir_end()
#	print_debug("Finished copying directory " + src_path + " → " + dst_path)

	return OK

static func delete_directory_recursive(path: String) -> int:
#	print("\nProcessing directory for deletion " + path)
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return OK

	dir.include_navigational = false
	dir.include_hidden = false
	dir.list_dir_begin()
	var dir_item: String = dir.get_next()
	while dir_item != "":
		var file_path: String = path.path_join(dir_item)

		if dir.current_is_dir():
#			print_debug("Recursively deleting directory " + file_path)
			var err: int = delete_directory_recursive(file_path)
			if err != OK:
				push_error("Error deleting directory: " + dir_item)
				return err
		else:
#			print_debug("Deleting File " + file_path)
			var err: int = dir.remove(dir_item)
			if err != OK:
				push_error("Error deleting file: " + dir_item)
				return err
		
		dir_item = dir.get_next()

	dir.list_dir_end()

#	print_debug("Recursive directory deletion ending with " + path)
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func copy_file(src_file: String, dst_file: String) -> int:
#	print("\nCopying file " + src_file + " to " + dst_file)

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

#	print_debug("File copied from " + src_file + " to " + dst_file)

	return src_dir.copy(src_file, dst_file)

static func verify_import_files_exist(file_paths: Array[String]) -> bool:
#	print("Verifying .import files exist for %d files" % file_paths.size())

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
			push_error("  - " + file)
		return false
