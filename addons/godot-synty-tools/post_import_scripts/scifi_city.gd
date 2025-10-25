@tool
extends EditorScenePostImport

const DEBUG_LOGGING: bool = false

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
	var info: String = "%s: %s (%s)" % [indent, node.name, node.get_class()]
	
	print(info)
	for child in node.get_children():
		if child is Node:
			print_node_hierarchy(child, indent + "  ")

func process_scene(scene: Node, src_file: String) -> Node:
	var src_base_fn: String = src_file.get_file()

	if src_base_fn == "Characters.fbx":
		scene = process_characters(scene, src_file)
	elif src_base_fn.begins_with("SM_"):
		# NOTE: set up the export object however you prefer
#		scene = process_sm_staticbody3d_root(scene, src_file)
		scene = _process_sm_meshinstance3d_root(scene, src_file)
	else:
		print("Not modifying unhandled file: " + src_file)

	return scene

func process_sm_staticbody3d_root(scene: Node, src_file: String) -> Node:
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
			child.name = "MeshInstance3D"
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
#	shape.name = mesh.name + "_Collision"

	return shape

# NOTE: coming in without the collision
func _process_sm_meshinstance3d_root(scene: Node, src_file: String) -> Node:
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
	body.name = "StaticBody3D"
#	body.name = mesh.name + "_StaticBody3D"
	root_mesh.add_child(body)	
	body.set_owner(root_mesh)

	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"

	var shape = root_mesh.mesh.create_convex_shape()
	collision.shape = shape

	body.add_child(collision)
	collision.set_owner(root_mesh)

	return root_mesh

func generate_collsion_shape(mesh: MeshInstance3D) -> ConcavePolygonShape3D:
	var collision_shape: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
	if not collision_shape:
		print("Skipping collision: could not generate collision shape")
		return null

	return collision_shape

func process_characters(char_root: Node, char_file_path: String) -> Node:
#	print_node_hierarchy(char_root)
	
	var skel: Skeleton3D = null
	var meshes: Array[MeshInstance3D] = []
	for child in char_root.get_children():
		if child is Skeleton3D:
			skel = child
			for skel_child in child.get_children():
				if skel_child is MeshInstance3D:
					meshes.append(skel_child)
		elif child is AnimationPlayer:
			# we don't want it
			pass
		else:
			print("Skipping unhandled child class " + str(child))
	
	if not skel:
		push_error("Skeleton3D not found in char_root")
		return char_root
	
	if not meshes.size():
		push_error("No MeshInstance3D found in char_root")
		return char_root
	
	for mesh in meshes:
		var new_root: CharacterBody3D = CharacterBody3D.new()
		new_root.name = mesh.name
		
		# collision
		var collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var capsule = CapsuleShape3D.new()
		collision.shape = capsule
		new_root.add_child(collision)
		collision.set_owner(new_root)
		
		# duplicate the skeleton
		var new_skel: Skeleton3D = skel.duplicate()
#		new_skel.name = "Skeleton3D"
		new_skel.name = "Skeleton3D"
		new_root.add_child(new_skel)
		new_skel.set_owner(new_root)
		
		# remove all mesh children from duplicated skeleton
		for child in new_skel.get_children():
			child.queue_free()
		
		# duplicate only this specific mesh
		var new_mesh: MeshInstance3D = mesh.duplicate()
		new_mesh.name = "MeshInstance3D"
		new_skel.add_child(new_mesh)
		new_mesh.set_owner(new_root)
		new_mesh.skeleton = new_mesh.get_path_to(new_skel)

		# animation player
		var new_anim = AnimationPlayer.new()
		new_anim.name = "AnimationPlayer"
		new_root.add_child(new_anim)
		new_anim.set_owner(new_root)
		new_anim.root_node = new_anim.get_path_to(new_root)

		# save it
		var packed_scene = PackedScene.new()
		packed_scene.pack(new_root)
	
		var save_path: String = char_file_path.replace("Characters.fbx", "Character-" + mesh.name + ".tscn")
		var err: Error = ResourceSaver.save(packed_scene, save_path)
		if not err == OK:
			push_error("Failed to save scene: " + error_string(err))
			return char_root

#		print("Saved individual character: " + save_path)

	return char_root
