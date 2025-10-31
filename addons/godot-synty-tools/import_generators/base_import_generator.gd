@tool
extends RefCounted
class_name BaseImportGenerator

var import_wait_timeout: int = 90
var plugin: EditorPlugin
var selected_folder_path: String = ""

const BONE_MAP_BASE_PATH: String = "res://addons/godot-synty-tools/bone_maps"
const EXPORT_BASE_PATH: String = "res://godot-synty-tools-output"
const POST_IMPORT_SCRIPT_BASE_PATH: String = "res://addons/godot-synty-tools/post_import_scripts"

# Main processing function - override this
func process() -> Error:
	return OK

func reimport_files(file_paths: Array[String], timeout_seconds: float = 10) -> bool:
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

	var efs: EditorFileSystem = plugin.get_editor_interface().get_resource_filesystem()
	efs.resources_reimported.connect(on_reimport)

	if not efs.is_scanning():
		efs.scan()

	await plugin.get_tree().process_frame
	while efs.is_scanning():
#		print("FS is scanning, waiting .2 seconds")
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

	print("%d files successfully reimported" % file_paths.size())
	return true
