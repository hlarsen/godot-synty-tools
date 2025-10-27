@tool
extends EditorScenePostImport

class_name BaseLocomotionPostImport

const DEBUG_LOGGING: bool = false

# This Post Install script is probably not too useful on its own, it just creates animation .resources files
# At this point we've already fixed the animations, so if you run this without it the animations won't work correctly
func _post_import(scene: Node) -> Object:
	var src_file: String = get_source_file()

	if DEBUG_LOGGING:
		print("Running Godot Synty Tools Base Locomotion Post Import Script for: " + src_file)
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
	var src_base_fn: String = src_file.get_file()

	if not src_base_fn.ends_with(".fbx"):
		return scene
		
	if not (src_base_fn.begins_with("A_") or src_base_fn.begins_with("A_MOD_")):
		return scene

	var err: Error = create_animation_resource_file(scene, src_file)
	if not err == OK:
		push_error("Could not create animation resource file: " + error_string(err))

	return scene

func create_animation_resource_file(scene: Node, src_file: String) -> Error:
	if DEBUG_LOGGING:		
		print("Processing children:")

	for child in scene.get_children():
		if DEBUG_LOGGING:
			print("Child: ", child.name, " (", child.get_class(), ")")
		if child is AnimationPlayer:
			if child.get_animation_list().size() != 1:
				push_error("More than one animation found")
				return ERR_INVALID_DATA

			for anim_name in child.get_animation_list():
				var anim: Animation = child.get_animation(StringName(str(anim_name)))
				if anim:
					return ResourceSaver.save(anim, src_file.replace(".fbx", ".res"))
		else:
			if DEBUG_LOGGING:
				print("Skipping unhandled child class " + str(child))

	return FAILED
