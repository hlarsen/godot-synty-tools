@tool
extends BaseMenuWithSelection

func _init():
	MODULE = "Quaternius UAL"
	instruction_default = "Select the " + MODULE + " .glb file:"
	import_generator_path = "res://addons/godot-synty-tools/import_generators/quaternius_ual_import_generator.gd"
	
	selection_mode = SelectionMode.FILE_ONLY
	allowed_file_extensions = PackedStringArray(["glb"])

func validate_folder_specific(dir: DirAccess) -> bool:
	return true
