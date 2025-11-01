@tool
extends BaseMenuWithSelection

func _init():
	MODULE = "Sci-Fi City"
	instruction_default = "Select the " + MODULE + " folder:"
	import_generator_path = "res://addons/godot-synty-tools/import_generators/scifi_city_import_generator.gd"
	
	selection_mode = SelectionMode.FOLDER_ONLY
	allowed_file_extensions = PackedStringArray()

func validate_folder_specific(dir: DirAccess) -> bool:
	if not dir.file_exists("MaterialList_PolygonSciFiCity.txt"):
		print("Not enabling run button, could not find file: MaterialList_PolygonSciFiCity.txt")
		return false
	return true

func get_processing_message() -> String:
	return "Processing started, see the Output tab for logs.\nMaterial errors on import are expected."
