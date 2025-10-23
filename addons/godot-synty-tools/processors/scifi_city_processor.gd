@tool
extends BaseProcessor
class_name SciFiCityProcessor

signal selected_folder_changed(path: String)
signal validation_changed(is_valid: bool)

var selected_folder_path: String = ""

func set_folder(path: String) -> void:
	selected_folder_path = path
	emit_signal("selected_folder_changed", path)
	_validate()

func validate_inputs() -> bool:
	if selected_folder_path.is_empty():
		return false
	
	var dir: DirAccess = DirAccess.open(selected_folder_path)
	if dir == null:
		return false
	
	# Add your specific validation logic here
	# For example, check for required files/folders

	return true

func get_validation_error() -> String:
	if selected_folder_path.is_empty():
		return "No folder selected"
	return "Invalid folder structure"

func process() -> bool:
	update_status("Processing started...")
	
	print("selected folder path: " + selected_folder_path)
	
	# Do your processing here
	await plugin.get_tree().create_timer(1.0).timeout
	update_status("Step 1 complete...")
	
	await plugin.get_tree().create_timer(1.0).timeout
	update_status("Step 2 complete...")
	
	await plugin.get_tree().create_timer(1.0).timeout
	update_status("Processing finished!")
	
	return true

func _validate() -> void:
	var is_valid: bool = validate_inputs()
	emit_signal("validation_changed", is_valid)
