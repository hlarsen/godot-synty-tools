@tool
extends BaseImportGenerator
class_name SyntyGenericImportGenerator

# these are custom options passed in via the menu
var custom_default_atlas_texture: String = ""
var custom_bone_map: String = ""
var custom_models_dir: String = ""
var custom_textures_dir: String = ""
var custom_post_import_script: String = ""

# add to custom options?
var model_extensions_to_import: Array[String] = ["fbx"]
var texture_extensions_to_import: Array[String] = ["png"]

var export_subdir: String = EXPORT_BASE_PATH.path_join("synty_generic")

const KEEP_TEMP_DIR: bool = false
const MODULE: String = "synty_generic"

# NOTE: i think the only good option would be to parse the materials file (if present)
# but if everything goes well we could just have this var (anything else?) in the specific pack scripts and pass it in
# TODO: right now this check is begins_with i think, that's not enough
const file_map: Dictionary[String, String] = {
}

func process() -> Error:
	print("Running " + MODULE + " processing with custom options:")
	print("Models Dir: " + custom_models_dir)
	print("Textures Dir: " + custom_textures_dir)
	if not custom_models_dir or not custom_textures_dir:
		push_error("Missing necessary options to run " + MODULE + " processing, exiting")
		return FAILED

	print("Post Import Script: " + custom_post_import_script)
	print("Default Atlas Texture: " + custom_default_atlas_texture)
	if not custom_default_atlas_texture or custom_default_atlas_texture == "None":
		custom_default_atlas_texture = ""
		push_warning("No default atlas texture selected")
	if not custom_post_import_script or custom_post_import_script == "None":
		custom_post_import_script = ""
		push_warning("No post import script selected")
	print("Bone Map for Characters: " + custom_bone_map)
	if not custom_bone_map or custom_bone_map == "None":
		custom_bone_map = ""
		push_warning("No bone map selected")

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
	var temp_dir_textures: String = temp_dir.path_join("Textures")
	var temp_dir_models: String = temp_dir.path_join("Models")
	var export_subdir_textures: String = export_subdir.path_join("Textures")
	var export_subdir_models: String = export_subdir.path_join("Models")
	print("Using temp dir: " + temp_dir)
	print("Using temp_dir_textures dir: " + temp_dir_textures)
	print("Using temp_dir_models dir: " + temp_dir_models)
	print("Using export_subdir_textures dir: " + export_subdir_textures)
	print("Using export_subdir_models dir: " + export_subdir_models)

	if custom_default_atlas_texture:
		print("Copying atlas texture from " + custom_default_atlas_texture + " to " + temp_dir_textures)
		err = FileUtils.copy_file(custom_default_atlas_texture, temp_dir_textures.path_join(custom_default_atlas_texture.get_file()))
		if not err == OK:
			push_error("Error copying: " + error_string(err))
			return err

	# copy textures to the project first because we reference them in the post import of the models
	print("Copying texture files from " + custom_textures_dir + " to " + temp_dir_textures)
	err = FileUtils.copy_directory_recursive(custom_textures_dir, temp_dir_textures, texture_extensions_to_import)
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
	print("Copying model files from " + custom_models_dir + " to " + temp_dir_models)
	err = FileUtils.copy_directory_recursive(custom_models_dir, temp_dir_models, model_extensions_to_import)
	if not err == OK:
		push_error("Error copying model files: " + error_string(err))
		return err

	var model_files: Array[String] = FileUtils.list_files_recursive(temp_dir_models)
	print("Adding .import files for " + str(model_files.size()) + " FBX files in " + temp_dir_models)
	for file in model_files:
		if file.get_file() == "Characters.fbx":
			print("Processing Characters.fbx")
			await process_characters(file, temp_dir_models, export_subdir_models)
			continue

		err = generate_fbx_import_file(file)
		if not err == OK:
			push_error("Error generating import file for " + file + ": " + error_string(err))
			return err

	# TODO: sometimes its not in the models dir?
	# delete Characters.fbx (we created separate char files so we don't need it)
#	err = DirAccess.remove_absolute(export_subdir_models.path_join("Characters.fbx"))
#	if not err == OK:
#		push_error("Error deleting: " + error_string(err))
#		return err
#
#	err = DirAccess.remove_absolute(temp_dir_models.path_join("Characters.fbx"))
#	if not err == OK:
#		push_error("Error deleting: " + error_string(err))
#		return err

	print("Copy files from " + temp_dir_models + " to " + export_subdir_models)
	err = FileUtils.copy_directory_recursive(temp_dir_models, export_subdir_models)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	var new_files: Array[String] = FileUtils.list_files_recursive(export_subdir_models).filter(func(f): return !f.ends_with(".import")).filter(func(f): return !f.ends_with("Characters.fbx"))
	if not await reimport_files(new_files, import_wait_timeout):
		push_error("Reimport before scene creation failed")
		return FAILED

	print("Fixing materials and creating scenes")
	err = create_scenes(new_files, export_subdir_textures)
	if err != OK:
		push_error("Failed to apply materials")
		return err

	if not await reimport_files([], import_wait_timeout):
		push_error("Final reimport failed")
		return FAILED

	print("Finished running " + MODULE + " processing with custom options")

	return OK

func generate_fbx_import_file(src_file) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: params/fbx_importer
	if custom_post_import_script:
		config.set_value("params", "import_script/path", custom_post_import_script)
	config.set_value("params", "fbx/importer", 0)

	return config.save(src_file + ".import")

func generate_character_fbx_import_file(src_file: String, bone_map) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: params/fbx_importer
	config.set_value("params", "nodes/root_type", "CharacterBody3D")
	if custom_post_import_script:
		config.set_value("params", "import_script/path", custom_post_import_script)
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

	if bone_map == null:
		subresources_dict = {
			"nodes": {
				"PATH:Skeleton3D": {
					"retarget/bone_renamer/unique_node/make_unique": false,
					"retarget/bone_renamer/unique_node/skeleton_name": "Skeleton3D",
				}
			}
		}

	config.set_value("params", "_subresources", subresources_dict)

	return config.save(src_file + ".import")

func process_characters(file_src, tmp_dir_models, export_subdir_models) -> Error:
	var imported_src = export_subdir_models.path_join(file_src.get_file())
	var err: Error = FileUtils.copy_file(file_src, imported_src)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	if not await reimport_files([imported_src], import_wait_timeout):
		push_error("Failed to reimport Characters.fbx")
		return FAILED

	var bone_map = null
	if custom_bone_map:
		bone_map = ResourceLoader.load(custom_bone_map)
		if not bone_map:
			push_error("Failed to load bone map")
			return FAILED
	else:
		push_warning("No bone map set, not adding bone map to character")

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

	print("Found " + str(meshes.size()) + " in Characters.fbx")
	for mesh in meshes:
		var output_name: String = mesh.name
#		if mesh.name.begins_with("SM_Chr_"):
#			output_name = mesh.name.replace("SM_Chr_", "Character_")

		if mesh.name.begins_with("SM_Chr_Attach_"):
			continue

		print("Creating duplicate character file for mesh: " + mesh.name)
		var save_path = tmp_dir_models.path_join(output_name + ".fbx")
		err = FileUtils.copy_file(file_src, save_path)
		if not err == OK:
			push_error("Error saving new char file: " + error_string(err))
			return err

#		print("Generating .import for character " + save_path.get_file() + " in dir " + temp_dir_path)
		err = generate_character_fbx_import_file(save_path, bone_map)
		if not err == OK:
			push_error("Error creating .import file: " + error_string(err))
			return err

	return OK

func create_scenes(scene_paths: Array[String], export_subdir_textures: String) -> Error:
	for fbx_path in scene_paths:
		if not ResourceLoader.exists(fbx_path):
			print("Scene doesn't exist yet: " + fbx_path)
			continue

		var packed_scene: PackedScene = load(fbx_path)
		if not packed_scene:
			print("Failed to load scene: " + fbx_path)
			continue

		var scene_root: Node = packed_scene.instantiate()

		if custom_default_atlas_texture:
			fix_scene_materials(scene_root, export_subdir_textures)
		else:
			push_warning("No default atlas texture set, not fixing materials")

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

func fix_scene_materials(root: Node, export_subdir_textures: String) -> void:
#	print("Fixing materials on scene")
	if not root:
		return

	if root is MeshInstance3D:
#		print("Fixing mesh materials for: " + root.name)
		fix_mesh_materials(root, export_subdir_textures)

	# recursively process children
	for child in root.get_children():
		if child is Node:
			fix_scene_materials(child, export_subdir_textures)

# we need to do some fancy replacing with the dirs or something?
func fix_mesh_materials(mesh: MeshInstance3D, export_subdir_textures: String) -> void:
	if not mesh or not mesh.mesh:
		print("No mesh or mesh.mesh found")
		return

	mesh.mesh = mesh.mesh.duplicate(true)

	for surface_idx in range(mesh.mesh.get_surface_count()):
#		print("Processing material for mesh:", mesh.name, "Surface:", surface_idx)
		var new_mat = StandardMaterial3D.new()
		new_mat.albedo_color = Color(1,1,1)

		var file_to_use: String = custom_default_atlas_texture.get_file()
		for key in file_map.keys():
			if mesh.name.begins_with(key):
				file_to_use = file_map[key]
				break

		var tex_path: String = export_subdir_textures.path_join(file_to_use)
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
