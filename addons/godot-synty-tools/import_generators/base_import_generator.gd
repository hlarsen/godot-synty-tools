@tool
extends RefCounted
class_name BaseImportGenerator

var plugin: EditorPlugin

const EXPORT_BASE_PATH: String = "res://godot-synty-tools-output"
const POST_IMPORT_SCRIPT_BASE_PATH: String = "res://addons/godot-synty-tools/post_import_scripts"
const TEMP_IMPORT_PATH_BASE: String = "res://godot-synty-tools-temp-import"

# Main processing function - override this
func process() -> Error:
	return OK
