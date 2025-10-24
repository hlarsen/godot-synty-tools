@tool
extends RefCounted
class_name BaseProcessor

var plugin: EditorPlugin

#signal processing_started
#signal processing_finished(success: bool)
#signal status_updated(message: String)

const EXPORT_BASE_PATH: String = "res://godot-synty-tools-output"
const POST_IMPORT_SCRIPT_BASE_PATH: String = "res://addons/godot-synty-tools/post_import_scripts"
const TEMP_IMPORT_PATH_BASE: String = "res://godot-synty-tools-temp-import"

# Main processing function - override this
func process() -> bool:
	return true

# Helper to run async processing
func run_async() -> void:
#	emit_signal("processing_started")
	var success: bool = await _do_process()
#	emit_signal("processing_finished", success)

func _do_process() -> bool:
	return await process()

# Helper for status updates
#func update_status(message: String) -> void:
#	print(message)
#	emit_signal("status_updated", message)

# Cleanup
func cleanup() -> void:
	pass

# NOTE: Using this for reimport as well since can't get reimport_files() to work properly without the editor
# complaining if I alt tab about an import already running... doesn't seem like you can check if one is running
func scan_and_wait_for_signal(efs: EditorFileSystem, file_paths: Array[String], timeout_seconds: float = 10) -> bool:
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
