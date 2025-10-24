@tool
extends EditorScenePostImport

const DEBUG_LOGGING: bool = true

# This install script may be useful on its own, so far we're not doing any pre-processing like with Base Locomotion
func _post_import(scene: Node) -> Object:
	var src_file: String = get_source_file()

	if DEBUG_LOGGING:
		print("Running Godot Synty Tools Sci-Fi City Post Import Script for: " + src_file)
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

	if src_base_fn == "Characters.fbx":
		scene = process_characters(scene, src_file)
	elif src_base_fn.begins_with("SM_"):
		scene = process_sm(scene, src_file)
	else:
		print("Not modifying unhandled file: " + src_file)

	return scene

# TODO: Characters is a bunch of meshes, how to handle? Maybe outside this script, or just like this?
func process_characters(scene: Node, src_file: String) -> Node:
	# TODO: what - charbody3d > skeleton3d > mesh, collsion, animation...?
	return scene

func process_sm(scene: Node, src_file: String) -> Node:
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
			child.name = body.name + "MeshInstance3D"
#			child.name = body.name + "_Mesh"
			
			# add collision to mesh
			var shape: CollisionShape3D = generate_collision(child)
			if not shape:
				return scene
				
			body.add_child(shape)
			shape.set_owner(body)
		elif child is AnimationPlayer:
			# we don't want it
			pass
		else:
			if DEBUG_LOGGING:
				print("Skipping unhandled child class " + str(child))
	
	return body

# NOTE: coming in without the collision
func _process_sm_mesh_on_top(scene: Node, src_file: String) -> Node:
	var root_mesh = null

	if DEBUG_LOGGING:		
		print("Processing children:")

	for child in scene.get_children():
		if DEBUG_LOGGING:
			print("Child: ", child.name, " (", child.get_class(), ")")
		if child is MeshInstance3D:
			# TODO: pull off the textures to get rid of the import errors? fix paths here?
			root_mesh = child
			break
		else:
			if DEBUG_LOGGING:
				print("Skipping unhandled child class " + str(child))

	if not root_mesh:
		return scene

	root_mesh.set_owner(null)
	if root_mesh.get_parent():
		root_mesh.get_parent().remove_child(root_mesh)

	var body = StaticBody3D.new()
	root_mesh.add_child(body)	
	body.set_owner(root_mesh)
	body.name = "StaticBody3D"
#	body.name = mesh.name + "_StaticBody3D"

	var shape: CollisionShape3D = generate_collision(root_mesh)
	if not shape:
		return scene
		
	body.add_child(shape)
	shape.set_owner(body)

	return root_mesh

func generate_collision(mesh: MeshInstance3D) -> CollisionShape3D:
	if not mesh.mesh:
		print("Skipping collision: mesh is null for " + mesh.name)
		return null

	# TODO: what shape(s)?
	var collision_shape: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
	if not collision_shape:
		print("Skipping collision: could not generate collision shape")
		return null

	var shape = CollisionShape3D.new()
	shape.shape = collision_shape
	shape.name = "CollisionShape3D"
#	shape.name = mesh.name + "_Collision

#	print("Returning shape: " + str(shape))
	return shape
