@tool
extends EditorScenePostImport

const DEBUG_LOGGING: bool = false

func _post_import(scene: Node) -> Object:
	var src_file: String = get_source_file()

	print("Running Godot Synty Tools Sci-Fi City Post Import Script for: " + src_file)

	if DEBUG_LOGGING:
		print("Before: \n")
		print_node_hierarchy(scene)

	scene = process_scene(scene, src_file)

	if DEBUG_LOGGING:
		print("\nAfter: ")
		print_node_hierarchy(scene)

	print("Finishing running Post Import Script for " + src_file)

	return scene

func print_node_hierarchy(node: Node, indent: String = "") -> void:
	var info: String = "%s- %s" % [indent, node.name]
	
	print(info)
	for child in node.get_children():
		if child is Node:
			print_node_hierarchy(child, indent + "  ")

func process_scene(scene: Node, src_file: String) -> Node:
	var src_base_fn: String = src_file.get_file()

	if src_base_fn == "Characters.fbx":
		scene = process_characters(scene)
	elif src_base_fn.begins_with("SM_"):
		scene = process_sm(scene)
	else:
		print("Not modifying unhandled file: " + src_file)

	return scene

# TODO: Characters is a bunch of meshes, how to handle? Maybe outside this script, or just like this?
func process_characters(scene: Node) -> Node:
	# TODO: what - charbody3d > skeleton3d > mesh, collsion, animation...?
	return scene

func process_sm(scene: Node) -> Node:
	var body = StaticBody3D.new()
	body.name = scene.name

	if DEBUG_LOGGING:		
		print("Processing children:")

	for child in scene.get_children():
		if DEBUG_LOGGING:
			print("Child: ", child.name, " (", child.get_class(), ")")
		if child is MeshInstance3D:
			# TODO: pull off the textures to get rid of the import errors? fix paths here?
			scene.remove_child(child)
			child.set_owner(null)
			body.add_child(child)
			child.set_owner(body)
			child.name = body.name + "_Mesh"
			add_collision(body, child)
		elif child is AnimationPlayer:
			# we don't want it
			pass
		else:
			if DEBUG_LOGGING:
				print("Skipping unhandled child class " + str(child))
	
	return body

func add_collision(body: StaticBody3D, mesh: MeshInstance3D) -> void:
	if not mesh.mesh:
		push_warning("Skipping collision: mesh is null for " + mesh.name)
		return

	var shape = CollisionShape3D.new()
	shape.name = body.name + "_Collision"

	# TODO: what shape(s)?
	var collision_shape: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
	if not collision_shape:
		return

	shape.shape = collision_shape
	body.add_child(shape)
	shape.owner = body

#	print("Added collision shape for ", mesh_instance.name)
