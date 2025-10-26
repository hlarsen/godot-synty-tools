@tool
extends EditorScenePostImport

const DEBUG_LOGGING: bool = true
# Overrides for the default
# const FILE_MAP = preload("res://addons/godot-synty-tools/file_map.gd").FILE_MAP
const FILE_MAP = {
	"SM_Bld_Background_": "PolygonScifi_Background_Building_Emissive", # no albedo texture
	"_Glass": "Glass_01_A",	# no albedo texture (match Glass?)
	"Glass_": "Glass_01_A",	# no albedo texture (match Glass?)
	"SM_HologramPods_": "PolygonScifi_Hologram_Outline", # no albedo texture
	"SkyDome": "SimpleSky", # uses custom shader
	"SM_Env_Graffiti_": "PolygonSciFi_Billboards",
	"SM_Env_Planet_Plane_01": "Planet_Material_01",
	"SM_Env_Planet_Plane_02": "Planet_Material_02",
	"SM_Env_Road": "Road", # uses custom shader
	# TODO skipping FX files
	"Fire_01_FX": "Polygon_Scifi_FX", # uses custom shader
	# bunch more
	# TODO skipping FX files
	"SM_Prop_Hologram_Bottle_": "PolygonScifi_Hologram_Base",	# uses custom shader - matching issue?
	"SM_Prop_Bottle_": "PolygonScifi_Hologram_Outline",	# no albedo texture - matching issue?
	"SM_Prop_Hologram_": "PolygonScifi_Hologram_Base",	# uses custom shader - matching issue?
	"SM_Prop_LargeSign_": "PolygonScifi_Hologram_Outline",	# no albedo texture - matching issue?
	"SM_Prop_Jar": "Glass_01_Jar", # no albedo texture (match Jar?)
	"SM_Prop_Posters_": "PolygonSciFi_Billboards",
	"SM_Sign_Ad_": "Signs",
	"SM_Sign_Billboard_Large_": "PolygonSciFi_Billboards",
	"SM_Sign_Neon_": "PolygonScifi_NeonSigns", # uses custom shader
	"SM_Sign_Neon_Flat_": "PolygonScifi_NeonSigns", # uses custom shader
	
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
		return scene
	elif src_base_fn.begins_with("Character_"):
		fix_scene_materials(scene)
		scene = process_character(scene, src_file)
	elif src_base_fn.begins_with("SM_"):
		fix_scene_materials(scene)
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
			set_owner_recursive(child, body)

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

# TODO: what shape(s)? testing...
func generate_collision(mesh: MeshInstance3D) -> CollisionShape3D:
	if not mesh.mesh:
		print("Skipping collision: mesh is null for " + mesh.name)
		return null

#	var collision_shape: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
#	if not collision_shape:
#		print("Skipping collision: could not generate collision shape")
#		return null

	# Create a box that matches the mesh AABB/bounding box
	var aabb: AABB = mesh.mesh.get_aabb()
	var collision_shape := BoxShape3D.new()
	if not collision_shape:
		print("Skipping collision: could not generate collision shape")
		return null
	collision_shape.size = aabb.size

	var shape = CollisionShape3D.new()
	shape.shape = collision_shape
	shape.name = "CollisionShape3D"
#	shape.name = mesh.name + "_Collision"
	shape.position = aabb.position + (aabb.size * 0.5)

	return shape

func process_character(scene: Node, char_file_path: String) -> Node:
#	print("Processing fixed character " + scene.name + " at " + char_file_path)
	var char_name: String = scene.name.replace(".fbx", "")

	# delete extra meshes	
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

	# collision
	var char_skeleton: Skeleton3D = scene.get_node("Skeleton3D")
	# TODO: testing shapes
	var collision: CollisionShape3D = make_collision_for_skel(char_skeleton)
#	var collision: CollisionShape3D = make_collision_for_mesh(char_skeleton.get_node(char_name))
	if collision:
		scene.add_child(collision)
		collision.set_owner(scene)

#	# animation
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	scene.add_child(anim_player)
	anim_player.set_owner(scene)
	anim_player.root_node = anim_player.get_path_to(scene)
	# TODO: preload anim lib (create in preload?)
#	var anim_lib: AnimationLibrary = preload("res://path_to_library.tres")
#	anim_player.animation_library = anim_lib

	var anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
#	# TODO: need to set/maybe prep this as well, idle loop/walk/run/jump
##	anim_player.tree_root = AnimationNodeStateMachine.new()
	scene.add_child(anim_tree)
	anim_tree.set_owner(scene)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	return scene

# TODO: test
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

# TODO: test
func make_collision_for_mesh(mesh_instance: MeshInstance3D) -> CollisionShape3D:
	if not mesh_instance or not mesh_instance.mesh:
		push_warning("make_collision_for_mesh: No mesh assigned to " + str(mesh_instance))
		return null

	# Get the mesh’s overall bounds
	var aabb: AABB = mesh_instance.mesh.get_aabb()
	var height = aabb.size.y
	var radius = max(aabb.size.x, aabb.size.z) * 0.25  # approximate shoulder width

	# Create capsule shape
	var capsule = CapsuleShape3D.new()
	capsule.height = height * 1.05  # +5% padding for coverage
	capsule.radius = radius

	# Create collision shape node
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = capsule

	# Position at the center of the mesh bounds
	collision.position = aabb.position + (aabb.size * 0.5)

	return collision

func fix_scene_materials(root: Node) -> void:
	if not root:
		return

	if root is MeshInstance3D:
		print("Fixing mesh materials for: " + root.name)
		fix_mesh_materials(root)

	# recursively process children
	for child in root.get_children():
		if child is Node:
			fix_scene_materials(child)


func fix_mesh_materials(mesh: MeshInstance3D) -> void:
	if not mesh or not mesh.mesh:
		print("No mesh or mesh.mesh found")
		return

	for surface_idx in range(mesh.mesh.get_surface_count()):
		var mat: Material = mesh.mesh.surface_get_material(surface_idx)
		print("Processing material for mesh:", mesh.name, "Surface:", surface_idx, "Current material:", mat)

		var new_mat = StandardMaterial3D.new()
		new_mat.albedo_color = Color(1,1,1)

		var file_to_use: String = "PolygonScifi_01_A.png"
		for key in FILE_MAP.keys():
			if mesh.name.begins_with(key):
				file_to_use = FILE_MAP[key] + ".png"
				break

		var tex_path: String = "res://godot-synty-tools-output/scifi_city/Textures/" + file_to_use
		if not FileAccess.file_exists(tex_path):
			print("Texture not found, using default fallback:", tex_path)

		new_mat.albedo_texture = load(tex_path)
		mesh.mesh.surface_set_material(surface_idx, new_mat)

		print("Assigned texture:", tex_path)
