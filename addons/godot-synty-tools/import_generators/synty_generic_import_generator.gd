@tool
extends BaseImportGenerator
class_name SyntyGenericImportGenerator

var default_atlas_texture: String = ""
var export_subdir: String = EXPORT_BASE_PATH.path_join("synty_generic")
var post_import_script: String = POST_IMPORT_SCRIPT_BASE_PATH.path_join("synty_generic.gd") 

var models_dir: String = "FBX"
var model_extensions_to_import: Array[String] = ["fbx"]
var textures_dir: String = "Textures"
var texture_extensions_to_import: Array[String] = ["png"]

# NOTE: most compatible?
const BONE_MAP: String = "res://addons/godot-synty-tools/bone_maps/scifi_city_v4.tres"
const KEEP_TEMP_DIR: bool = true
const MODULE: String = "synty_generic"

# TODO: debug files that don't work/are incorrect
const FILE_MAP: Dictionary[String, String] = {
}

func process() -> Error:
	print("Running " + MODULE + " processing with folder: ", selected_folder_path)

#	print("Deleting output directory before new run: " + export_subdir)
	var err: Error = FileUtils.delete_directory_recursive(export_subdir)
	if not err == OK:
		push_error("Error deleting directory: " + export_subdir)
		return err

	print("Creating temp dir: " + MODULE)
	var temp_dir_access: DirAccess = DirAccess.create_temp(MODULE, KEEP_TEMP_DIR)
	if not temp_dir_access:
		push_error("Can't create temp directory: " + error_string(temp_dir_access.get_open_error()))
		return temp_dir_access.get_open_error()

	var temp_dir: String = temp_dir_access.get_current_dir()
	var temp_dir_textures: String = temp_dir.path_join(textures_dir)
	var temp_dir_models: String = temp_dir.path_join(models_dir)
	var export_subdir_textures: String = export_subdir.path_join(textures_dir)
	var export_subdir_models: String = export_subdir.path_join(models_dir)
	print("Using temp dir: " + temp_dir)

	# copy textures to the project first because we reference them in the post import of the models
	print("Copying texture files from " + selected_folder_path.path_join(textures_dir) + " to " + temp_dir_textures)
	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join(textures_dir), temp_dir_textures, texture_extensions_to_import)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	# generate .import files for the textures so they don't re-import when we fix the meshes
	# this happens because Godot sees we want to use them for 3D and changes the import settings
	var texture_files: Array[String] = FileUtils.list_files_recursive(temp_dir_textures)
	print("Adding .import files for " + str(texture_files.size()) + " texture files in " + temp_dir_textures)
	for tex_file in texture_files:
		err = generate_texture_import_file_for_3d(tex_file)
		if err != OK:
			push_error("Failed to create .import for " + tex_file)
			return err

	print("Copying texture files from " + temp_dir_textures + " to " + export_subdir_textures)
	err = FileUtils.copy_directory_recursive(temp_dir_textures, export_subdir_textures)
	if not err == OK:
		push_error("Error copying texture files: " + error_string(err))
		return err

	if not await reimport_files(FileUtils.list_files_recursive(export_subdir_textures).filter(func(f): return !f.ends_with(".import")), import_wait_timeout):
		push_error("Failed to import textures files")
		return FAILED

	# textures are in the project, time for the models
	print("Copying model files from " + selected_folder_path + " to " + temp_dir_models)
	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join(models_dir), temp_dir_models, model_extensions_to_import)
	if not err == OK:
		push_error("Error copying model files: " + error_string(err))
		return err

	var model_files: Array[String] = FileUtils.list_files_recursive(temp_dir_models)
	var expected_imports: Array[String] = []
	print("Adding .import files for " + str(model_files.size()) + " FBX files in " + temp_dir_models)
	for file in model_files:
		if file.get_file() == "Characters.fbx":
			print("Processing Characters.fbx")
			await process_characters(file, temp_dir_models, export_subdir_models, expected_imports)
			continue

		var tmp_file_path: String = file.replace(temp_dir_models, export_subdir_models)
		err = generate_fbx_import_file(file, tmp_file_path)
		if not err == OK:
			push_error("Error generating import file for " + file + ": " + error_string(err))
			return err

#		expected_imports.append(file.replace(temp_dir, export_subdir))

	# delete Characters.fbx (we created separate char files so we don't need it)
	err = DirAccess.remove_absolute(export_subdir_models.path_join("Characters.fbx"))
	if not err == OK:
		push_error("Error deleting: " + error_string(err))
		return err

	err = DirAccess.remove_absolute(temp_dir_models.path_join("Characters.fbx"))
	if not err == OK:
		push_error("Error deleting: " + error_string(err))
		return err

	print("Copy files from " + temp_dir_models + " to " + export_subdir_models)
	err = FileUtils.copy_directory_recursive(temp_dir_models, export_subdir_models)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	if not await reimport_files(FileUtils.list_files_recursive(export_subdir_models).filter(func(f): return !f.ends_with(".import")), import_wait_timeout):
		push_error("Reimport before scene creation failed")
		return FAILED

#	# we need to fix materials here, doing it in post import triggers a re-import
#	# theoretically we could move it to post import, but a quick try was causing material errors...
#	# maybe try another time, but this is working
#	# added bonus of creating scenes
#	print("Fixing materials and creating scenes")
#	err = create_scenes(expected_imports)
#	if err != OK:
#		push_error("Failed to apply materials")
#		return err
#
#	if not await reimport_files([], import_wait_timeout):
#		push_error("Final reimport failed")
#		return FAILED

	print("Finished running " + MODULE + " processing with folder: ", selected_folder_path)

	return OK

func generate_fbx_import_file(src_file, tmp_file_path) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: deps > source_file and params/fbx_importer
#	config.set_value("deps", "source_file", tmp_file_path)
	config.set_value("params", "import_script/path", post_import_script)
	config.set_value("params", "fbx/importer", 0)

	return config.save(src_file + ".import")

func generate_character_fbx_import_file(src_file: String, tmp_file_path: String, bone_map: BoneMap) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: deps > source_file and params/fbx_importer
#	config.set_value("deps", "source_file", tmp_file_path)
	config.set_value("params", "nodes/root_type", "CharacterBody3D")
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

func process_characters(file_src, tmp_dir_models, export_subdir_models, expected_imports) -> Error:
	var imported_src = export_subdir_models.path_join(file_src.get_file())
	var err: Error = FileUtils.copy_file(file_src, imported_src)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	if not await reimport_files([imported_src], import_wait_timeout):
		push_error("Failed to reimport Characters.fbx")
		return FAILED

	var bone_map: BoneMap = ResourceLoader.load(BONE_MAP)
	if not bone_map:
		push_error("Failed to load bone map")
		return FAILED

	print("Load scene for: " + imported_src)
	var scene = load(imported_src)
	if not scene:
		push_error("Failed to load: " + imported_src)
		return ERR_CANT_OPEN

	var root = scene.instantiate()
	var meshes: Array[Variant] = []

	for child in root.get_node("Skeleton3D").get_children():
		if child is MeshInstance3D:
			meshes.append(child)

	for mesh in meshes:
#		print("Creating duplicate character file for mesh: " + mesh.name)
		var save_path = tmp_dir_models.path_join(mesh.name + ".fbx")
		err = FileUtils.copy_file(file_src, save_path)
		if not err == OK:
			push_error("Error saving new char file: " + error_string(err))
			return err

#		print("Generating .import for character " + save_path.get_file() + " in dir " + temp_dir_path)
		err = generate_character_fbx_import_file(save_path, tmp_dir_models, bone_map)
		if not err == OK:
			push_error("Error creating .import file: " + error_string(err))
			return err

		expected_imports.append(save_path.replace(tmp_dir_models, export_subdir_models))

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
		new_mat.albedo_color = Color(1.0, 1.0, 1.0)

		var file_to_use: String = default_atlas_texture
		for key in FILE_MAP.keys():
			if mesh.name.begins_with(key):
				file_to_use = FILE_MAP[key] + ".png"
				break

		var tex_path: String = EXPORT_BASE_PATH.path_join(MODULE).path_join("/" + textures_dir + "/").path_join(file_to_use)
		if not FileAccess.file_exists(tex_path):
			print("Texture not found, using default fallback:", tex_path)

		new_mat.albedo_texture = load(tex_path)
		mesh.mesh.surface_set_material(surface_idx, new_mat)
#		mesh.set_surface_override_material(surface_idx, new_mat)

#		print("Assigned texture:", tex_path)

func generate_texture_import_file_for_3d(texture_path: String) -> Error:
	var config = ConfigFile.new()

#	config.set_value("deps", "source_file", texture_path)

	# specify the differences betewen the default .import Godot generates and after its set on a 3d object
	config.set_value("params", "compress/mode", 2)
	config.set_value("params", "mipmaps/generate", true)
	config.set_value("params", "detect_3d/compress_to", 0)
	# importer is in [remap] unlike the fbx .import, we don't need to specify

	return config.save(texture_path + ".import")
