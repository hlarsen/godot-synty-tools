@tool
extends EditorScenePostImport

const DEBUG_LOGGING: bool = false
const LOOPED_ANIMS: Array[Variant] = []
const OUTPUT_DIR: String = "res://godot-synty-tools-output/quaternius_ual/"

# TODO: move this to the import generator if possible, post import should be node hierarchy setup only (if possible)
func _post_import(scene: Node) -> Object:
	var src_file: String = get_source_file()

	if DEBUG_LOGGING:
		print("Running Godot Synty Tools Qaternius UAP Post Import Script for: " + src_file)
		print("Before: \n")
		print_node_hierarchy(scene)

	scene = process_scene(scene, src_file)

	if DEBUG_LOGGING:
		print("\nAfter: ")
		print_node_hierarchy(scene)

	return scene

func print_node_hierarchy(node: Node, indent: String = "") -> void:
	var info: String = "%s- %s" % [indent, node.name]

	print(info)
	for child in node.get_children():
		if child is Node:
			print_node_hierarchy(child, indent + "  ")

func process_scene(scene: Node, src_file: String) -> Node:
	var anim_player: AnimationPlayer = scene.get_node_or_null("AnimationPlayer")
	if not anim_player:
		push_error("No AnimationPlayer found")
		return scene

	var anim_lib: AnimationLibrary = AnimationLibrary.new()

	for anim_name in anim_player.get_animation_list():
		var original_anim: Animation = anim_player.get_animation(anim_name)
		var anim: Animation = original_anim.duplicate(true)
#		print("adding anim_name: " + anim_name)
		anim_lib.add_animation(anim_name, anim)

	var out_path: String = OUTPUT_DIR.path_join("Quaternius_UAL.tres")
	var dir: DirAccess = DirAccess.open("res://")
	if not dir.dir_exists(OUTPUT_DIR):
		dir.make_dir_recursive(OUTPUT_DIR)

	var save_result: Error = ResourceSaver.save(anim_lib, out_path)
	if save_result != OK:
		push_error("Failed to save animation library: " + error_string(save_result))
		return scene
		
	print("Saved animation library: ", out_path)
	if anim_player.has_animation_library("Quaternius_UAL"):
		anim_player.remove_animation_library("Quaternius_UAL")
	
	anim_player.add_animation_library("Quaternius_UAL", anim_lib)
#	print("Attached Quaternius_UAL library with animations:", anim_lib.get_animation_list())

	return scene
