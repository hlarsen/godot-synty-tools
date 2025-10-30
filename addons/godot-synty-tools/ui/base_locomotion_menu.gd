@tool
extends BaseMenuWithSelection

func _init():
	MODULE = "Base Locomotion"
	instruction_default = "Select the " + MODULE + " Animations folder"
	import_generator_path = "res://addons/godot-synty-tools/import_generators/base_locomotion_import_generator.gd"
	
	selection_mode = SelectionMode.FOLDER_ONLY
	allowed_file_extensions = PackedStringArray()

func validate_folder_specific(dir: DirAccess) -> bool:
	if not selected_folder_path.get_file() == "Animations":
		print("Not Enabling Run Button: Invalid directory (Select Base Locomotion Animations folder): ", selected_folder_path)
		return false
	return true
