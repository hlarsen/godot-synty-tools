@tool
extends BaseImportGenerator
class_name ScifiCityImportGenerator

var default_atlas_texture: String = "PolygonScifi_01_A.png"
var export_subdir: String = EXPORT_BASE_PATH.path_join("scifi_city")
var post_import_script: String = POST_IMPORT_SCRIPT_BASE_PATH.path_join("scifi_city.gd") 

const BONE_MAP: String = "res://addons/godot-synty-tools/bone_maps/scifi_city_v4.tres"
const KEEP_TEMP_DIR: bool = false
const MODULE: String = "scifi_city"

# TODO: debug files that don't work/are incorrect
# TODO: right now this check is begins_with i think, that's not enough
const file_map: Dictionary[String, String] = {
	"SM_Bld_Background_": "PolygonScifi_Background_Building_Emissive.png", # no albedo texture
#	"_Glass": "Glass_01_A.png",	# no albedo texture (match Glass?)
#	"Glass_": "Glass_01_A.png",	# no albedo texture (match Glass?)
#	"SM_HologramPods_": "PolygonScifi_Hologram_Outline", # no albedo texture
	"SkyDome": "SimpleSky.png", # uses custom shader
	"SM_Env_Graffiti_": "Billboards.png",
	"SM_Env_Planet_Plane_01": "Planet_Material_01.png",
	"SM_Env_Planet_Plane_02": "Planet_Material_02.png",
	"SM_Env_Road": "PolygonSciFi_Road_01.png", # uses custom shader
#	"SM_Prop_Hologram_Bottle_": "PolygonScifi_Hologram_Base.png",	# uses custom shader - matching issue?
#	"SM_Prop_Bottle_": "PolygonScifi_Hologram_Outline.png",	# no albedo texture - matching issue?
#	"SM_Prop_Hologram_": "PolygonScifi_Hologram_Base.png",	# uses custom shader - matching issue?
#	"SM_Prop_LargeSign_": "PolygonScifi_Hologram_Outline.png",	# no albedo texture - matching issue?
#	"SM_Prop_Jar": "Glass_01_Jar.png", # no albedo texture (match Jar?)
	"SM_Prop_Posters_": "Billboards.png",
	"SM_Sign_Ad_": "Signs.png",
	"SM_Sign_Billboard_Large_": "Billboards.png",
#	"SM_Sign_Neon_": "PolygonScifi_NeonSigns.png", # uses custom shader
#	"SM_Sign_Neon_Flat_": "PolygonScifi_NeonSigns.png", # uses custom shader
}

func process() -> Error:
	print("Running " + MODULE + " processing with folder: ", selected_folder_path)

#	print("Deleting output directory before new run: " + export_subdir)
	var err: Error = FileUtils.delete_directory_recursive(export_subdir)
	if not err == OK:
		push_error("Error deleting directory: " + export_subdir)
		return err

	print("Creating temp dir: " + MODULE)
	var temp_dir: DirAccess = DirAccess.create_temp(MODULE, KEEP_TEMP_DIR)
	if not temp_dir:
		push_error("Can't create temp directory: " + error_string(temp_dir.get_open_error()))
		return temp_dir.get_open_error()

	var temp_dir_path: String = temp_dir.get_current_dir()
	print("Using temp dir: " + temp_dir_path)

	# copy textures to the project first because we reference them in the post import of the fbx files
	# NOTE: we're just copying them directly to export_subdir and generating .import files before forcing a scan
	# we should copy to temp_dir first. generate, then copy to export_subdir like we do for everything else
	print("Copying files from " + selected_folder_path.path_join("Textures") + " to " + export_subdir.path_join("Textures"))
	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join("Textures"), export_subdir.path_join("Textures"))
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	# generate .import files for the textures so they don't re-import when we fix the meshes
	var texture_files: Array[String] = FileUtils.list_files_recursive(export_subdir.path_join("Textures"))
	print("Adding .import files for " + str(texture_files.size()) + " PNG files in " + export_subdir.path_join("Textures"))
	for tex_file in texture_files:
		if not tex_file.ends_with(".png"):
			continue

		err = generate_texture_import_file_for_3d(tex_file)
		if err != OK:
			push_error("Failed to create .import for " + tex_file)
			return err

	if not await reimport_files(texture_files, import_wait_timeout):
		push_error("Failed to import textures files")
		return FAILED

	print("Copying files from " + selected_folder_path + " to " + temp_dir_path)
	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join("FBX"), temp_dir_path.path_join("FBX"))
	if not err == OK:
		push_error("Error copying files: " + error_string(err))
		return err

	# textures are in the project, time for the fbx files
	var imports_to_create: Array[String] = FileUtils.list_files_recursive(temp_dir_path).filter(func(f): return f.ends_with(".fbx"))
	var expected_imports: Array[String] = []
	print("Adding .import files for " + str(imports_to_create.size()) + " FBX files in " + temp_dir_path)
	for file in imports_to_create:
		if not file.ends_with(".fbx"):
			continue

		if file.ends_with("Characters.fbx"):
			print("Processing Characters.fbx")
			await process_characters(file, temp_dir_path, export_subdir, expected_imports)
			continue

		var tmp_file_path: String = file.replace(temp_dir_path, export_subdir)
		err = generate_fbx_import_file(file, tmp_file_path)
		if not err == OK:
			push_error("Error generating import file for " + file + ": " + error_string(err))
			return err

		expected_imports.append(file.replace(temp_dir_path, export_subdir))

	# delete Characters.fbx (we created separate char files so we don't need it)
	err = DirAccess.remove_absolute(export_subdir.path_join("FBX").path_join("Characters.fbx"))
	if not err == OK:
		push_error("Error deleting: " + error_string(err))
		return err

	err = DirAccess.remove_absolute(temp_dir_path.path_join("FBX").path_join("Characters.fbx"))
	if not err == OK:
		push_error("Error deleting: " + error_string(err))
		return err

	print("Copy files from " + temp_dir_path + " to " + export_subdir)
	err = FileUtils.copy_directory_recursive(temp_dir_path, export_subdir)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	if not await reimport_files(expected_imports, import_wait_timeout):
		push_error("Reimport before scene creation failed")
		return FAILED

	print("Fixing materials and creating scenes")
	err = create_scenes(expected_imports)
	if err != OK:
		push_error("Failed to apply materials")
		return err

	if not await reimport_files([], import_wait_timeout):
		push_error("Final reimport failed")
		return FAILED

	print("Finished running " + MODULE + " processing with folder: ", selected_folder_path)

	return OK

func generate_fbx_import_file(src_file, tmp_file_path) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: params/fbx_importer
	config.set_value("deps", "source_file", tmp_file_path)
	config.set_value("params", "import_script/path", post_import_script)
	config.set_value("params", "fbx/importer", 0)

	return config.save(src_file + ".import")

func generate_character_fbx_import_file(src_file: String, tmp_file_path: String, bone_map: BoneMap) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: params/fbx_importer
	config.set_value("deps", "source_file", tmp_file_path)
	config.set_value("params", "nodes/root_type", "CharacterBody3D")	# 
	config.set_value("params", "import_script/path", post_import_script)
	config.set_value("params", "fbx/importer", 0)

	# advanced import settings - if you can't find docs for ui options, look them up in the engine:
	# https://github.com/godotengine/godot/blob/9cd297b6f2a0ee660b8f1a6b385582cccf3a9d10/editor/import/3d/resource_importer_scene.cpp#L2218
	var subresources_dict: Dictionary[String, Variant] = {
		"nodes": {
			"PATH:Skeleton3D": {
				"retarget/bone_map": bone_map,
				"retarget/bone_renamer/unique_node/make_unique": false,
				"retarget/bone_renamer/unique_node/skeleton_name": "Skeleton3D",
			}
		}
	}

	config.set_value("params", "_subresources", subresources_dict)

	return config.save(src_file + ".import")

func process_characters(file_src, temp_dir_path, export_subdir, expected_imports) -> Error:
	var original_char = export_subdir.path_join("FBX").path_join(file_src.get_file())
	var err: Error = FileUtils.copy_file(file_src, original_char)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	if not await reimport_files([original_char], import_wait_timeout):
		push_error("Failed to reimport Characters.fbx")
		return FAILED

	var bone_map: BoneMap = ResourceLoader.load(BONE_MAP)
	if not bone_map:
		push_error("Failed to load bone map")
		return FAILED

	print("Load scene for: " + original_char)
	var scene = load(original_char)
	if not scene:
		push_error("Failed to load: " + original_char)
		return ERR_CANT_OPEN

	var root = scene.instantiate()
	var meshes: Array[Variant] = []

	for child in root.get_node("Skeleton3D").get_children():
		if child is MeshInstance3D:
			meshes.append(child)

	for mesh in meshes:
#		print("Creating separate character for mesh: " + mesh.name)
		var save_path = temp_dir_path.path_join("FBX").path_join(mesh.name + ".fbx")
		err = FileUtils.copy_file(file_src, save_path)
		if not err == OK:
			push_error("Error saving new char file: " + error_string(err))
			return err

#		print("Generating .import for character " + save_path.get_file() + " in dir " + temp_dir_path)
		err = generate_character_fbx_import_file(save_path, temp_dir_path, bone_map)
		if not err == OK:
			push_error("Error creating .import file: " + error_string(err))
			return err

		expected_imports.append(save_path.replace(temp_dir_path, export_subdir))
		
	return OK

func create_scenes(scene_paths: Array[String]) -> Error:
	for fbx_path in scene_paths:
		if not ResourceLoader.exists(fbx_path):
			print("Scene doesn't exist yet: " + fbx_path)
			continue

		var packed_scene: PackedScene = load(fbx_path)
		if not packed_scene:
			print("Failed to load scene: " + fbx_path)
			continue

		var scene_root: Node = packed_scene.instantiate()
		fix_scene_materials(scene_root)

		var save_path: String = fbx_path.replace(".fbx", ".tscn")
		var new_packed = PackedScene.new()
		var pack_result = new_packed.pack(scene_root)
		if pack_result != OK:
			push_error("Failed to pack scene: " + fbx_path)
			scene_root.queue_free()
			continue

		var save_result: int = ResourceSaver.save(new_packed, save_path)
		if save_result != OK:
			push_error("Failed to save scene: " + save_path)

		scene_root.queue_free()

		# might as well clean up here
		var err: Error = DirAccess.remove_absolute(fbx_path)
		if not err == OK:
			push_error("Could not delete fbx :" + fbx_path)
			return err

	return OK

func fix_scene_materials(root: Node) -> void:
#	print("Fixing materials on scene")
	if not root:
		return

	if root is MeshInstance3D:
#		print("Fixing mesh materials for: " + root.name)
		fix_mesh_materials(root)

	# recursively process children
	for child in root.get_children():
		if child is Node:
			fix_scene_materials(child)


func fix_mesh_materials(mesh: MeshInstance3D) -> void:
	if not mesh or not mesh.mesh:
		print("No mesh or mesh.mesh found")
		return

	mesh.mesh = mesh.mesh.duplicate(true)

	for surface_idx in range(mesh.mesh.get_surface_count()):
#		print("Processing material for mesh:", mesh.name, "Surface:", surface_idx)
		var new_mat = StandardMaterial3D.new()
		new_mat.albedo_color = Color(1,1,1)

		var file_to_use: String = default_atlas_texture
		for key in file_map.keys():
			if key in mesh.name:
				file_to_use = file_map[key]
				break

		var tex_path: String = EXPORT_BASE_PATH.path_join(MODULE).path_join("/Textures/").path_join(file_to_use)
		if not FileAccess.file_exists(tex_path):
			print("Texture not found, using default fallback:", tex_path)

		new_mat.albedo_texture = load(tex_path)
		mesh.mesh.surface_set_material(surface_idx, new_mat)
#		mesh.set_surface_override_material(surface_idx, new_mat)

#		print("Assigned texture:", tex_path)

func generate_texture_import_file_for_3d(texture_path: String) -> Error:
	var config = ConfigFile.new()

	config.set_value("deps", "source_file", texture_path)

	# specify the differences betewen the default .import Godot generates and after its set on a 3d object
	config.set_value("params", "compress/mode", 2)
	config.set_value("params", "mipmaps/generate", true)
	config.set_value("params", "detect_3d/compress_to", 0)
	# importer is in [remap] unlike the fbx .import, we don't need to specify

	return config.save(texture_path + ".import")
