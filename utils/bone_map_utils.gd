@tool

# NOTE: not used
class_name BoneMapUtils

# NOTE: useful? could just keep the different maps here in code, easier to check for matches than separate files?
func _create_bone_map() -> BoneMap:
	var bone_map = BoneMap.new()
	var profile = SkeletonProfileHumanoid.new()
	bone_map.profile = profile
	
	# Map your skeleton bones to the humanoid profile
	bone_map.set_skeleton_bone_name("Root", &"Root")
	bone_map.set_skeleton_bone_name("Hips", &"Hips")
	bone_map.set_skeleton_bone_name("Spine", &"Spine_01")
	bone_map.set_skeleton_bone_name("Chest", &"Spine_02")
	# ... add all your bone mappings
	
	# Save it
#	var bone_map_path = "res://temp_import/bone_map.tres"
#	var bone_map_path = default_import_path.path_join("bone_map.tres")
#	ResourceSaver.save(bone_map, bone_map_path)
	
	return bone_map
