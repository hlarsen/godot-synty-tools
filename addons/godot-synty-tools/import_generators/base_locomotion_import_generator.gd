@tool
extends BaseImportGenerator
# TODO: do we need to process both Polygon and Sidekick if we're eventually just using Godot to map via Skeletons?
class_name BaseLocomotionImportGenerator

var export_subdir: String = EXPORT_BASE_PATH.path_join(MODULE)
var selected_folder_path: String = ""
var post_import_script: String = POST_IMPORT_SCRIPT_BASE_PATH.path_join(MODULE + ".gd") 

# Base Locomotion Bone Maps
const ANIM_BONE_MAP_POLYGON: String = "res://addons/godot-synty-tools/bone_maps/base_locomotion_v3_polygon.tres"
const ANIM_BONE_MAP_SIDEKICK: String = "res://addons/godot-synty-tools/bone_maps/base_locomotion_v3_sidekick.tres"
# The T-Pose animation we need to use as a RESET for the other animations
const ANIM_TPOSE_PATH_POLYGON: String = "Polygon/Neutral/Additive/TPose/A_TPose_Neut.fbx"
const ANIM_TPOSE_PATH_SIDEKICK: String = "Sidekick/Neutral/Additive/TPose/A_MOD_BL_TPose_Neut.fbx"
const IMPORT_WAIT_TIMEOUT: int = 60
const KEEP_TEMP_DIR: bool = false
const MODULE: String = "base_locomotion"
const RESET_ANIM_NAME: String = "RESET"
const TPOSE_WORKING_DIR: String = "tpose_files_interim"

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
	print("Copying files from " + selected_folder_path + " to " + temp_dir_path)
	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join("Polygon"), temp_dir_path.path_join("Polygon"))
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	err = FileUtils.copy_directory_recursive(selected_folder_path.path_join("Sidekick"), temp_dir_path.path_join("Sidekick"))
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	print("Re-importing T-Pose animations")
	var temp_tpose_path_polygon: String = temp_dir_path.path_join(ANIM_TPOSE_PATH_POLYGON)
	var temp_tpose_path_sidekick: String = temp_dir_path.path_join(ANIM_TPOSE_PATH_SIDEKICK)
	var export_subdir_tpose_path_polygon: String = temp_dir_path.path_join(ANIM_TPOSE_PATH_POLYGON)
	var export_subdir_tpose_path_sidekick: String = temp_dir_path.path_join(ANIM_TPOSE_PATH_SIDEKICK)
	generate_tpose_anim_import_file(temp_tpose_path_polygon, export_subdir_tpose_path_polygon)
	generate_tpose_anim_import_file(temp_tpose_path_sidekick, export_subdir_tpose_path_sidekick)

	print("Copy and import fixed T-Pose animations")
	var fixed_tpose_files: Array[String] = [temp_tpose_path_polygon, temp_tpose_path_sidekick, temp_tpose_path_polygon + ".import", temp_tpose_path_sidekick + ".import"] 
	for file in fixed_tpose_files:
		err = FileUtils.copy_file(file, export_subdir.path_join(TPOSE_WORKING_DIR).path_join(file.get_file()))
		if not err == OK:
			push_error("Error copying: " + error_string(err))
			return err

	var export_subdir_tpose_fixed: String = export_subdir.path_join(TPOSE_WORKING_DIR)
	var subdir_fixed_tpose_polygon: String = export_subdir_tpose_fixed.path_join(temp_tpose_path_polygon.get_file())
	var subdir_fixed_tpose_sidekick: String = export_subdir_tpose_fixed.path_join(temp_tpose_path_sidekick.get_file())
	if not await reimport_files([subdir_fixed_tpose_polygon, subdir_fixed_tpose_sidekick]):
		push_error("Failed to import T-Pose animation files")
		return FAILED

	print("Exporting the re-imported T-Pose animations")
	var tpose_res_path_polygon: String = export_animation_rest_pose_resource(subdir_fixed_tpose_polygon, export_subdir_tpose_fixed)
	var tpose_res_path_sidekick: String = export_animation_rest_pose_resource(subdir_fixed_tpose_sidekick, export_subdir_tpose_fixed)
	if not (tpose_res_path_polygon or tpose_res_path_sidekick):
		push_error("Could not create fixed T-Pose resources")
		return FAILED

	print("Creating T-Pose animation libraries")
	var anim_lib_res_path_polygon: String = create_tpose_animation_library(tpose_res_path_polygon, export_subdir_tpose_fixed)
	var anim_lib_res_path_sidekick: String = create_tpose_animation_library(tpose_res_path_sidekick, export_subdir_tpose_fixed)
	if not (anim_lib_res_path_polygon or anim_lib_res_path_sidekick):
		push_error("Could not create animation libraries")
		return FAILED

#	if not await reimport_files([tpose_res_path_polygon, tpose_res_path_sidekick, anim_library_polygon, anim_library_sidekick]):
#		push_error("Failed to import interim tpose files")
#		return FAILED

	print("Loading T-Pose animation libraries and bone maps")
	var polygon_anim_lib: AnimationLibrary = ResourceLoader.load(anim_lib_res_path_polygon)
	var sidekick_anim_lib: AnimationLibrary = ResourceLoader.load(anim_lib_res_path_sidekick)
	if not (polygon_anim_lib or sidekick_anim_lib):
		push_error("Failed to load animation libraries")
		return FAILED
		
	var polygon_bone_map: BoneMap = ResourceLoader.load(ANIM_BONE_MAP_POLYGON)
	var sidekick_bone_map: BoneMap = ResourceLoader.load(ANIM_BONE_MAP_SIDEKICK)
	if not (polygon_bone_map or sidekick_bone_map):
		push_error("Failed to load bone maps")
		return FAILED

	var imports_to_create: Array[String] = FileUtils.list_files_recursive(temp_dir_path).filter(func(f): return f.ends_with(".fbx"))
	var expected_imports: Array[String] = []
	for src_file in imports_to_create:
		expected_imports.append(src_file.replace(temp_dir_path, export_subdir))
		if "/Polygon/" in src_file:
			generate_animation_fbx_import_file(src_file, export_subdir, polygon_anim_lib, polygon_bone_map)
		elif "/Sidekick/" in src_file:
			generate_animation_fbx_import_file(src_file, export_subdir, sidekick_anim_lib, sidekick_bone_map)
		else:
			push_error("Could not identify Polygon vs Sidekick for file: " + src_file)
			return FAILED

	err = FileUtils.copy_directory_recursive(temp_dir_path, export_subdir)
	if not err == OK:
		push_error("Error copying: " + error_string(err))
		return err

	if not await reimport_files(expected_imports, IMPORT_WAIT_TIMEOUT):
		push_error("Failed to import fixed animation files")
		return FAILED

	# NOTE: this happens now, but we haven't generated the actual animation Resources yet - this happens in post import
	print("Creating final animation libraries")
	create_animation_libraries(export_subdir.path_join("Polygon"), export_subdir)
	create_animation_libraries(export_subdir.path_join("Sidekick"), export_subdir)

	print("Cleaning up files")
	var cleanup_polygon: Array[String] = FileUtils.list_files_recursive(export_subdir.path_join("Polygon")).filter(func(f): return f.ends_with(".fbx"))
	var cleanup_sidekick: Array[String] = FileUtils.list_files_recursive(export_subdir.path_join("Sidekick")).filter(func(f): return f.ends_with(".fbx"))
	var cleanup_misc: Array[String] = [
		export_subdir.path_join("Polygon").path_join("AC_Polygon_Feminine.controller"),
		export_subdir.path_join("Polygon").path_join("AC_Polygon_Masculine.controller"),
		export_subdir.path_join("Sidekick").path_join("AC_Sidekick_Feminine.controller"),
		export_subdir.path_join("Sidekick").path_join("AC_Sidekick_Masculine.controller"),
	]

	var files_to_delete: Array[String] = (cleanup_polygon + cleanup_sidekick + cleanup_misc)
	for file in files_to_delete:
		err = DirAccess.remove_absolute(file)
		if not err == OK:
			push_error("Error deleting: " + error_string(err))
			return err

	err = FileUtils.delete_directory_recursive(export_subdir_tpose_fixed)
	if not err == OK:
		push_error("Error deleting: " + error_string(err))
		return err

	print("Finished running " + MODULE + " processing with folder: ", selected_folder_path)

	return OK

func generate_tpose_anim_import_file(src_file: String, tmp_file_path: String) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: deps > source_file and params/fbx_importer
	config.set_value("deps", "source_file", tmp_file_path)
#	config.set_value("params", "import_script/path", post_import_script)
	config.set_value("params", "nodes/import_as_skeleton_bones", true)
	config.set_value("params", "animation/remove_immutable_tracks", false)
	config.set_value("params", "animation/import_rest_as_RESET", true)
	config.set_value("params", "fbx/importer", 0)

	return config.save(src_file + ".import")

func generate_animation_fbx_import_file(src_file: String, tmp_file_path: String, anim_library: AnimationLibrary, bone_map: BoneMap) -> Error:
	var config = ConfigFile.new()

	# NOTE: minimum requirements for importing an FBX appear to be: deps > source_file and params/fbx_importer
	config.set_value("deps", "source_file", tmp_file_path)
	config.set_value("params", "import_script/path", post_import_script)
	config.set_value("params", "fbx/importer", 0)

	# advanced import settings - if you can't find docs for ui options, look them up in the engine:
	# https://github.com/godotengine/godot/blob/9cd297b6f2a0ee660b8f1a6b385582cccf3a9d10/editor/import/3d/resource_importer_scene.cpp#L2218
	var subresources_dict: Dictionary[String, Variant] = {
		"nodes": {
			"PATH:Skeleton3D": {
				"rest_pose/load_pose": 2,
				"rest_pose/external_animation_library": anim_library,
				"rest_pose/selected_animation": RESET_ANIM_NAME,
				"retarget/bone_map": bone_map,
				"retarget/bone_renamer/unique_node/make_unique": false,
				"retarget/bone_renamer/unique_node/skeleton_name": "Skeleton3D",
			}
		}
	}

	# the additive animations are in a t-pose so i think the fix would break them (but they still need a bone map)
	if "/Additive/" in src_file:
		subresources_dict = {
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

func export_animation_rest_pose_resource(src_animation: String, dst_dir: String) -> String:
	print("Exporting animations for file " + src_animation + " to dir " + dst_dir)
	var scene: PackedScene = ResourceLoader.load(src_animation)
	var root: Node = scene.instantiate()

	var src_base_name: String = src_animation.get_file().get_basename()

	var anim_path: String = ""
	for node in root.get_children():
		if node is AnimationPlayer:
			if node.has_animation(RESET_ANIM_NAME):
				var anim: Animation = node.get_animation(RESET_ANIM_NAME)
				anim_path = dst_dir.path_join(src_base_name + "-" + RESET_ANIM_NAME + ".res")
				ResourceSaver.save(anim, anim_path)

	root.queue_free()

	return anim_path

func create_tpose_animation_library(tpose_rest_res_path: String, temp_dir_path: String) -> String:
	# Load the RESET animation and create an AnimationLibrary
	var reset_anim: Animation = ResourceLoader.load(tpose_rest_res_path)
	if not reset_anim:
		push_error("Failed to load RESET animation from: " + tpose_rest_res_path)
		return ""

	# Create an AnimationLibrary and add the RESET animation
	var anim_library = AnimationLibrary.new()
	var err: int = anim_library.add_animation(RESET_ANIM_NAME, reset_anim)
	if err != OK:
		return ""	

	var src_base_name: String = tpose_rest_res_path.get_file().get_basename()

	# Save the library to a temporary location
	var library_path: String = temp_dir_path.path_join(src_base_name + "-tpose_library.res")
	err = ResourceSaver.save(anim_library, library_path)
	if err != OK:
		return ""

	return library_path

func create_animation_libraries(target_dir: String, export_dir: String) -> Error:
	var dir := DirAccess.open(target_dir)
	if not dir:
		push_error("Can't open target directory: " + target_dir)
		return FAILED

	dir.include_navigational = false
	dir.include_hidden = false
	dir.list_dir_begin()

	# Detect base type (Polygon or Sidekick)
	var base_name := target_dir.get_file()
	if base_name == "":
		base_name = target_dir.get_base_dir().get_file()
	if base_name == "":
		base_name = "Unknown"

	var masc_lib: AnimationLibrary = null
	var fem_lib: AnimationLibrary = null

	while true:
		var folder_name := dir.get_next()
		if folder_name == "":
			break
		if folder_name in [".", "..", TPOSE_WORKING_DIR]:
			continue

		var top_level_path := target_dir.path_join(folder_name)
		if not dir.current_is_dir():
			continue

		if "Masculine" in folder_name:
			masc_lib = AnimationLibrary.new()
			masc_lib.set_name("%s-Masculine" % base_name)
			add_animations_recursive(top_level_path, masc_lib, "")
		elif "Feminine" in folder_name:
			fem_lib = AnimationLibrary.new()
			fem_lib.set_name("%s-Feminine" % base_name)
			add_animations_recursive(top_level_path, fem_lib, "")
		elif "Neutral" in folder_name:
			if masc_lib:
				add_animations_recursive(top_level_path, masc_lib, "")
			if fem_lib:
				add_animations_recursive(top_level_path, fem_lib, "")

	# Save libraries if they exist
	if masc_lib and masc_lib.get_animation_list().size() > 0:
		var masc_path := export_dir.path_join(masc_lib.get_name() + ".tres")
		ResourceSaver.save(masc_lib, masc_path)
	if fem_lib and fem_lib.get_animation_list().size() > 0:
		var fem_path := export_dir.path_join(fem_lib.get_name() + ".tres")
		ResourceSaver.save(fem_lib, fem_path)

	dir.list_dir_end()
	return OK


func add_animations_recursive(current_path: String, lib: AnimationLibrary, relative_prefix: String) -> void:
	var dir: DirAccess = DirAccess.open(current_path)
	if not dir:
		push_error("Cannot open folder: " + current_path)
		return

	dir.include_navigational = false
	dir.include_hidden = false
	dir.list_dir_begin()

	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if file_name in [".", ".."]:
			continue

		var file_path := current_path.path_join(file_name)
		if dir.current_is_dir():
			var new_prefix := relative_prefix
			if new_prefix != "":
				new_prefix += " - "
			new_prefix += file_name
			add_animations_recursive(file_path, lib, new_prefix)
		elif file_name.ends_with(".res"):
			if "RootMotion" in file_path:
				continue

			# transition animations (we're currently letting Godot blend between animations)
			if "_To" in file_path:
				continue

			var anim: Resource = ResourceLoader.load(file_path)
			if anim:
				var anim_name := relative_prefix
				if anim_name != "":
					anim_name += " - "
				anim_name += file_name.get_basename()

				# cleanup
#				anim_name = file_name.get_basename()
				anim_name = clean_animation_name(file_name)
				lib.add_animation(anim_name, anim)

	dir.list_dir_end()

func clean_animation_name(final: String) -> String:
	var fix = {
#		"90L_": "_90 Left_",
#		"90R_": "_90 Right_",
#		"180L_": "_180 Left_",
#		"180R_": "_180 Right_",
#		"25F_": "_25 Forward_",
#		"LFoot_": "_Left Foot_",
#		"RFoot_": "_Right Foot_",
#	
#		"feFL_": "fe Forward Left_",
#		"feFR_": "fe Forward Right_",
#		"feBL_": "fe Back Left_",
#		"feBR_": "fe Back Right_",
#		"feF_": "fe Forward_",
#		"feB_": "fe Backward_",
#		"feL_": "fe Left_",
#		"feR_": "fe Right_",
#	
#		"FwdStrafe": "ForwardStrafe",
#		"BckStrafe": "BackStrafe",
#	
#		"IdleHard": "Idle Hard",
#		"IdleMedium": "Idle Medium",
#		"IdleSoft": "Idle Soft",
#		"_Fall": "_Fall_",
	
		"A_": "",
		"A_MOD_BL_": "",
		"_Masc": "",
		"_Femn": "",
		"_Neut": "",
		".res": "",
	}

	for f in fix.keys():
		final = final.replace(f, fix[f])

	# replace all underscores and multiple spaces with a single space
#	var regex = RegEx.new()
#	regex.compile("[_\\s]+")
#	final = regex.sub(final, " ")

#	# Special cases
#	if final == "Walk F":
#		final = "Walk Forward"
#	elif final == "Run F":
#		final = "Run Forward"
#	elif final == "Sprint F":
#		final = "Sprint Forward"

	return final
