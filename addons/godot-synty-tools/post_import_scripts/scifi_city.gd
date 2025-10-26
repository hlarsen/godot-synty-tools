@tool
extends EditorScenePostImport

const DEBUG_LOGGING: bool = true
# Overrides for the default
const FILE_MAP = {
	"SM_Bld_Background_Lrg_01": "PolygonSciFi_Buildings_Background", # no albedo texture
	"SM_Bld_Bank_01_Glass": "Glass_01_A",	# no albedo texture (match Glass?)
	"SM_HologramPods_01": "PolygonScifi_Hologram_Outline", # no albedo texture
	"SkyDome": "SimpleSky", # uses custom shader
	"SM_Env_Graffiti_Ground_01": "PolygonSciFi_Billboards",
	"SM_Env_Planet_Plane_01": "Planet_Material_01",
	"SM_Env_Road_Lines_01_SF": "Road", # uses custom shader
	# TODO skipping FX files
	"Fire_01_FX": "Polygon_Scifi_FX", # uses custom shader
	# bunch more
	# TODO skipping FX files
	"SM_Prop_Hologram_Bottle_01": "PolygonScifi_Hologram_Base",	# uses custom shader
	"SM_Prop_Bottle_01_Outline": "PolygonScifi_Hologram_Outline",	# no albedo texture
	"SM_Prop_JarFull_01": "Glass_01_A", # no albedo texture (match Jar?)
	"SM_Prop_Posters_01": "PolygonSciFi_Billboards",
	"SM_Sign_Ad_01": "Signs",
	"SM_Sign_Billboard_Large_01": "PolygonSciFi_Billboards",
	"SM_Sign_Neon_01": "PolygonScifi_NeonSigns", # uses custom shader
	"SM_Sign_Neon_Flat_01": "PolygonScifi_NeonSigns", # uses custom shader
	
}

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

	if src_base_fn == "Characters.fbx":
		scene = process_characters(scene, src_file)
	elif src_base_fn.begins_with("SM_"):
		# NOTE: set up the export object however you prefer
		scene = process_sm_staticbody3d_root(scene, src_file)
#		scene = _process_sm_meshinstance3d_root(scene, src_file)
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
			# TODO: need to handle if this mesh has decsendants (SM_Wep syringe)
			# TODO: pull off the textures to get rid of the import errors? fix paths here?
			scene.remove_child(child)
			child.set_owner(null)
			body.add_child(child)
			child.set_owner(body)
#			child.name = "MeshInstance3D"	# NOTE: not renaming the meshes rn
			set_owner_recursive(child, body)
#			for c in child.get_children():
#				c.set_owner(null)
#			child.name = body.name + "_Mesh"

			fix_mesh_materials(child)

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
#		print("Processing mesh " + mesh.name)

		# duplicate the skeleton
		var new_skel: Skeleton3D = skel.duplicate()
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
#		new_mesh.skeleton = new_mesh.get_path_to(new_skel)

		# collision
#		var collision = CollisionShape3D.new()
#		collision.name = "CollisionShape3D"
#		var capsule = CapsuleShape3D.new()
#		collision.shape = capsule
		var collision: CollisionShape3D = make_collision_for_skel(new_skel)
		if collision:
			new_root.add_child(collision)
			collision.set_owner(new_root)

		# animation player
		var anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		new_root.add_child(anim_player)
		anim_player.set_owner(new_root)
		# TODO: needed?
		anim_player.root_node = anim_player.get_path_to(new_skel)
		# TODO: preload anim lib (in .import?)
#		var anim_lib: AnimationLibrary = preload("res://path_to_library.tres")
#		anim_player.animation_library = anim_lib

		var anim_tree = AnimationTree.new()
		anim_tree.name = "AnimationTree"
		new_root.add_child(anim_tree)
		anim_tree.set_owner(new_root)
		# TODO: seems to be causing issues?
#		anim_tree.anim_player = anim_player

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

func make_collision_for_skel(skel: Skeleton3D) -> CollisionShape3D:
	# Compute top and bottom of skeleton bones
	var min_y = INF
	var max_y = -INF
	for bone_idx in range(skel.get_bone_count()):
		var bone_transform = skel.get_bone_global_pose(bone_idx)
		var y = bone_transform.origin.y
		if y < min_y:
			min_y = y
		if y > max_y:
			max_y = y

	var height = max_y - min_y
	var capsule = CapsuleShape3D.new()
#	capsule.height = height * 0.9	 # slightly smaller than full skeleton height
	capsule.radius = height * 0.2	 # approximate shoulder width

	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = capsule

#	 Center the collision node on skeleton
#	collision.position.y = (min_y + max_y) * 0.5

	# test padding
	capsule.height = height * 1.05  # +5% to cover head/feet
	collision.position.y = (min_y + max_y) * 0.5

	return collision

func fix_mesh_materials(mesh: MeshInstance3D):
	if not mesh or not mesh.mesh:
		return

	for surface_idx in range(mesh.mesh.get_surface_count()):
		var mat: Material = mesh.mesh.surface_get_material(surface_idx)
		print("Processing material: ", mat)

		# Replace any non-null material with a clean StandardMaterial3D
		var new_mat = StandardMaterial3D.new()
		new_mat.albedo_color = Color(1,1,1)
		new_mat.albedo_texture = load("res://godot-synty-tools-output/scifi_city/Textures/PolygonScifi_01_A.png")
#		new_mat.albedo_texture = load("res://godot-synty-tools-output/PolygonScifi_01_A.png")
		
		mesh.mesh.surface_set_material(surface_idx, new_mat)

