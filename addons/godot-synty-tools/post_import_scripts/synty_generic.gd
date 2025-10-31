@tool
extends EditorScenePostImport

const DEBUG_LOGGING: bool = false
const GST_POLYGON_MASC_ANIM_LIB: String = "res://godot-synty-tools-output/base_locomotion/Polygon_Masculine.tres"
const GST_QUAL_ANIM_LIB: String = "res://godot-synty-tools-output/quaternius_ual/Quaternius_UAL.tres"

var animation_tree_builder = preload("res://addons/godot-synty-tools/utils/base_locomotion_animation_tree_builder.gd")
var character_controller = preload("res://addons/godot-synty-tools/misc/character_controller.gd")

# This install script may be useful on its own, so far we're not doing any pre-processing like with Base Locomotion
func _post_import(scene: Node) -> Object:
	var src_file: String = get_source_file()

	if DEBUG_LOGGING:
		print("Running Godot Synty Tools Generic Post Import Script for: " + src_file)
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

func set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.set_owner(new_owner)
		set_owner_recursive(child, new_owner)

func clean_scene_name(name: String) -> String:
	if name.begins_with("SM_"):
		# ["Bld", "Env", "Icon", "Prop", "Sign", "Veh", "Wep"]
		pass
	elif name.begins_with("Character-"):
		pass
	else:
		pass

	return name.replace("_", " ")

func process_scene(scene: Node, src_file: String) -> Node:
	var src_base_fn: String = src_file.get_file()

	if src_base_fn.begins_with("Character_"):
		scene = process_character(scene, src_file)
	elif src_base_fn.begins_with("SM_"):
		scene = process_sm_staticbody3d_root(scene, src_file)
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
#			print("Processing mesh")
			scene.remove_child(child)
			child.set_owner(null)
			body.add_child(child)
			child.set_owner(body)
			set_owner_recursive(child, body)

			# TODO: collider shapes?
#			print("Adding collision")
			var shape: CollisionShape3D = generate_box_collider(child)
#			var shape: CollisionShape3D = generate_trimesh_collider(child)
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

func process_character(scene: Node, char_file_path: String) -> Node:
	print("Processing fixed character " + scene.name + " at " + char_file_path)
	var char_name: String = scene.name.replace(".fbx", "")

#	print("Deleting extra meshes")	
	for child in scene.get_children():
		if child is Skeleton3D:
			for gchild in child.get_children():
#				print("char_name: " + char_name + " gchild_name: " + gchild.name)
				if gchild is MeshInstance3D:
					if gchild.name == char_name:
						gchild.name = "MeshInstance3D"
					else:
						child.remove_child(gchild)
						gchild.queue_free()
		elif child is AnimationPlayer:
			scene.remove_child(child)
			child.queue_free()

	# flip skeleton facing to match Godot
	var char_skeleton: Skeleton3D = scene.get_node("Skeleton3D")
	char_skeleton.rotation.y = deg_to_rad(180)

	# TODO: collider shapes?
#	print("Adding collision")
	var collision: CollisionShape3D = generate_char_collsion_from_skel(char_skeleton)
#	var collision: CollisionShape3D = make_collision_for_mesh(char_skeleton.get_node(char_name))
	if collision:
		scene.add_child(collision)
		collision.set_owner(scene)

#	print("Adding anim player")
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	scene.add_child(anim_player)
	anim_player.set_owner(scene)
	anim_player.root_node = anim_player.get_path_to(scene)

	# preload polygon anim lib if it exists in our output dir
	var anim_lib: AnimationLibrary = null
	if FileAccess.file_exists(GST_POLYGON_MASC_ANIM_LIB):
		anim_lib = load(GST_POLYGON_MASC_ANIM_LIB)
		var err: Error = anim_player.add_animation_library("Polygon_Masculine", anim_lib)
		if not err == OK:
			push_error("Could not add Polygon Masculine to animation player")

		print("Added Polygon Masculine Base Locomotion, adding animation blending and controller")
#		print("Adding anim tree")
		animation_tree_builder.add_animation_tree(scene, anim_player)
	
#		print("Adding character controller")
		scene.set_script(character_controller)

	# preload ual anim lib if it exists in our output dir
	if FileAccess.file_exists(GST_QUAL_ANIM_LIB):
		anim_lib = load(GST_QUAL_ANIM_LIB)
		var err: Error = anim_player.add_animation_library("Quaternius_UAL", anim_lib)
		if not err == OK:
			push_error("Could not add UAL to animation player")

		print("Added Quaternius UAL")

#	print("Adding sound")

	return scene

func generate_box_collider(mesh: MeshInstance3D) -> CollisionShape3D:
	if not mesh.mesh:
		print("Skipping collision: mesh is null for " + mesh.name)
		return null

	# measure mesh
	var aabb: AABB = mesh.mesh.get_aabb()
	var collision_shape := BoxShape3D.new()
	if not collision_shape:
		print("Skipping collision: could not generate collision shape")
		return null
	collision_shape.size = aabb.size

	var shape = CollisionShape3D.new()
	shape.shape = collision_shape
	shape.name = "CollisionShape3D"

	# adjust the position due to meshes having origin at floor
	shape.position = aabb.position + (aabb.size * 0.5)

	return shape

func generate_trimesh_collider(mesh: MeshInstance3D) -> CollisionShape3D:
	if not mesh.mesh:
		print("Skipping collision: mesh is null for " + mesh.name)
		return null

	var collision_shape: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
	if not collision_shape:
		print("Skipping collision: could not generate collision shape")
		return null

	var shape = CollisionShape3D.new()
	shape.shape = collision_shape
	shape.name = "CollisionShape3D"

	return shape

# TODO: test
func generate_char_collsion_from_skel(skel: Skeleton3D) -> CollisionShape3D:
	# compute top and bottom of skeleton bones
	var min_y:float = INF
	var max_y:float = -INF
	for bone_idx in range(skel.get_bone_count()):
		var bone_transform: Transform3D = skel.get_bone_global_pose(bone_idx)
		var y: float = bone_transform.origin.y
		if y < min_y:
			min_y = y
		if y > max_y:
			max_y = y

	var height: float = max_y - min_y
	var capsule = CapsuleShape3D.new()
	capsule.radius = height * 0.2	 # approximate shoulder width

	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = capsule

	# height padding
	capsule.height = height * 1.05  # +5% to cover head/feet

	# adjust the position due to meshes having origin at floor
	collision.position.y = (min_y + max_y) * 0.5

	return collision

# TODO: test
func generate_char_collision_from_mesh(mesh_instance: MeshInstance3D) -> CollisionShape3D:
	if not mesh_instance or not mesh_instance.mesh:
		push_warning("make_collision_for_mesh: No mesh assigned to " + str(mesh_instance))
		return null

	# measure mesh
	var aabb: AABB = mesh_instance.mesh.get_aabb()
	var height: float = aabb.size.y
	var radius = max(aabb.size.x, aabb.size.z) * 0.25  # approximate shoulder width

	# create capsule shape
	var capsule = CapsuleShape3D.new()
	capsule.height = height * 1.05  # +5% padding for coverage
	capsule.radius = radius

	# create collision shape node
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = capsule

	# adjust the position due to meshes having origin at floor
	collision.position = aabb.position + (aabb.size * 0.5)

	return collision
