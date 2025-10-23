@tool
extends RefCounted
class_name BaseProcessor

var plugin: EditorPlugin

#signal processing_started
#signal processing_finished(success: bool)
#signal status_updated(message: String)

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
