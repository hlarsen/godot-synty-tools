@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	var src_file: String = get_source_file()

	print("Running Godot Synty Tools Sci-Fi City Post Import Script for: " + src_file)
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
	var src_base_fn: String = src_file.get_file()
	if src_base_fn == "Characters.fbx":
		scene = _process_characters(scene)
	elif src_base_fn.begins_with("SM_"):
		scene = _process_sm(scene)
	else:
		print("Not modifying unhandled file: " + src_file)

	return scene

# TODO: Characters is a bunch of meshes, how to handle? Maybe outside this script, or just like this?
func _process_characters(scene: Node) -> Node:
	# TODO: what - charbody3d > skeleton3d > mesh, collsion, animation...?
	return scene

func _process_sm(scene: Node) -> Node:
	var body = StaticBody3D.new()
	body.name = scene.name

	print("Processing children:")
	for child in scene.get_children():
		print("Child: ", child.name, " (", child.get_class(), ")")
		if child is MeshInstance3D:
			# TODO: pull off the textures to get rid of the import errors? fix paths here?
			scene.remove_child(child)
			child.set_owner(null)
			body.add_child(child)
			child.set_owner(body)
			child.name = body.name + "_Mesh"
			_add_collision(body, child)
		elif child is AnimationPlayer:
			# we don't want it
			pass
		else:
			print("Skipping unhandled child class " + str(child))
	
	return body

func _add_collision(body: StaticBody3D, mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		push_warning("Skipping collision: mesh is null for " + mesh.name)
		return

	var shape = CollisionShape3D.new()
	shape.name = body.name + "_Collision"

	# TODO: what shape(s)?
	var collision_shape: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
	if collision_shape == null:
		return

	shape.shape = collision_shape
	body.add_child(shape)
	shape.owner = body

#	print("Added collision shape for ", mesh_instance.name)
