@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	var src_file: String = get_source_file()

	print("Running Godot Synty Tools Base Locomotion Post Import Script for: " + src_file)
	_print_node_hierarchy(scene)

	scene =_process_scene(scene, src_file)

	_print_node_hierarchy(scene)
	print("Finishing running Post Import Script for " + src_file)

	return scene

func _print_node_hierarchy(node: Node, indent: String = "") -> void:
	var info: String = "%s- %s" % [indent, node.name]
	
	print(info)
	for child in node.get_children():
		if child is Node:
			_print_node_hierarchy(child, indent + "  ")

func _process_scene(scene: Node, src_file: String) -> Node:
	return scene
