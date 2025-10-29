# res://addons/your_importer/animation_tree_builder.gd
class_name AnimationTreeBuilder

# NOTE: currently hardcoded for Synty Base Locomotion (we've slightly normalized animation names in the libraries)
static func add_animation_tree(scene: Node, anim_player: AnimationPlayer) -> void:
	var anim_tree := AnimationTree.new()
	anim_tree.name = "AnimationTree"
	scene.add_child(anim_tree)
	anim_tree.owner = scene
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	var state_machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	anim_tree.tree_root = state_machine

	var standing_blend: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	standing_blend.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	standing_blend.snap = Vector2(0.01, 0.01)

	# TODO: handle this so it's not hardcoded or figure something else out
	var anim_lib_prefix: String = "Polygon Masculine/"

	# Idle at center (0, 0)
	add_blend_anim(anim_player, anim_lib_prefix + "Idle_Standing", Vector2.ZERO, standing_blend)

	# walk: inner ring at 0.5 radius
	add_blend_anim(anim_player,anim_lib_prefix + "Walk_FwdStrafeF", Vector2(0, 0.5), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Walk_FwdStrafeR", Vector2(0.5, 0), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Walk_BckStrafeB", Vector2(0, -0.5), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Walk_FwdStrafeL", Vector2(-0.5, 0), standing_blend)

	# walk diagonals
	add_blend_anim(anim_player,anim_lib_prefix + "Walk_FwdStrafeFR", Vector2(0.35, 0.35), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Walk_BckStrafeBR", Vector2(0.35, -0.35), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Walk_BckStrafeBL", Vector2(-0.35, -0.35), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Walk_FwdStrafeFL", Vector2(-0.35, 0.35), standing_blend)

	# run: outer ring at 1.0 radius
	add_blend_anim(anim_player,anim_lib_prefix + "Run_FwdStrafeF", Vector2(0, 1.0), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Run_FwdStrafeR", Vector2(1.0, 0), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Run_BckStrafeB", Vector2(0, -1.0), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Run_FwdStrafeL", Vector2(-1.0, 0), standing_blend)

	# run diagonals
	add_blend_anim(anim_player,anim_lib_prefix + "Run_FwdStrafeFR", Vector2(0.7, 0.7), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Run_BckStrafeBR", Vector2(0.7, -0.7), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Run_BckStrafeBL", Vector2(-0.7, -0.7), standing_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Run_FwdStrafeFL", Vector2(-0.7, 0.7), standing_blend)

	state_machine.add_node("StandingBlend", standing_blend)

	var start_transition: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	state_machine.add_transition("Start", "StandingBlend", start_transition)

	anim_tree.active = true

	print("AnimationTree setup complete with %d blend points" % standing_blend.get_blend_point_count())


# Helper function to add animation to blend space
static func add_blend_anim(anim_player: AnimationPlayer, anim_name: String, pos: Vector2, standing_blend) -> void:
	if anim_player.has_animation(anim_name):
		var node := AnimationNodeAnimation.new()
		node.animation = anim_name
		standing_blend.add_blend_point(node, pos)
	else:
		push_warning("Animation not found: %s" % anim_name)
