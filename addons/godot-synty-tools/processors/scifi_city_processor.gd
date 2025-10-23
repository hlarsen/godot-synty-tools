@tool
extends BaseProcessor
class_name SciFiCityProcessor

#signal selected_folder_changed(path: String)

var selected_folder_path: String = ""

func set_folder(path: String) -> void:
	selected_folder_path = path
#	emit_signal("selected_folder_changed", path)

func process() -> bool:
	await plugin.get_tree().create_timer(1.0).timeout
	print("Step 1 complete...")
	
	await plugin.get_tree().create_timer(1.0).timeout
	print("Step 2 complete...")
	
	return true
