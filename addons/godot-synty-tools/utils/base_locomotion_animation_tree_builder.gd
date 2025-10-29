# res://addons/your_importer/animation_tree_builder.gd
class_name BaseLocomotionAnimationTreeBuilder

# TODO: handle this so it's not hardcoded or figure something else out
const ANIM_LIB_PREFIX: String = "Polygon Masculine/"

static func add_animation_tree(scene: Node, anim_player: AnimationPlayer) -> void:
	var anim_tree := AnimationTree.new()
	anim_tree.name = "AnimationTree"
	scene.add_child(anim_tree)
	anim_tree.owner = scene
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	var state_machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	anim_tree.tree_root = state_machine

	var standing_blend: AnimationNodeBlendSpace2D = build_standing_blend(scene, anim_player)
	# NOTE: project restart needed to see changes to position in editor
	state_machine.add_node("StandingBlend", standing_blend, Vector2(400, 100))
	print("StandingBlend setup complete with %d blend points" % standing_blend.get_blend_point_count())

	var crouching_blend: AnimationNodeBlendSpace2D = build_crouching_blend(anim_player,ANIM_LIB_PREFIX)
	state_machine.add_node("CrouchingBlend", crouching_blend, Vector2(400, 300))
	print("CrouchingBlend setup complete with %d blend points" % crouching_blend.get_blend_point_count())

	# transition: start to standing blend
	var start_transition: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	state_machine.add_transition("Start", "StandingBlend", start_transition)

	# transition: standing to crouching
	var stand_to_crouch: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	stand_to_crouch.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	stand_to_crouch.xfade_time = 0.2
	state_machine.add_transition("StandingBlend", "CrouchingBlend", stand_to_crouch)

	# transition: crouching to standing
	var crouch_to_stand: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	crouch_to_stand.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	crouch_to_stand.xfade_time = 0.2
	state_machine.add_transition("CrouchingBlend", "StandingBlend", crouch_to_stand)

	anim_tree.active = true

static func build_standing_blend(scene: Node, anim_player: AnimationPlayer) -> AnimationNodeBlendSpace2D:
	var standing_blend: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	standing_blend.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	standing_blend.snap = Vector2(0.01, 0.01)

	# idle at center (0, 0)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Idle_Standing", Vector2.ZERO, standing_blend)

	# walk: inner ring at 0.5 radius
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Walk_FwdStrafeF", Vector2(0, 0.5), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Walk_FwdStrafeR", Vector2(0.5, 0), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Walk_BckStrafeB", Vector2(0, -0.5), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Walk_FwdStrafeL", Vector2(-0.5, 0), standing_blend)

	# walk diagonals
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Walk_FwdStrafeFR", Vector2(0.35, 0.35), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Walk_BckStrafeBR", Vector2(0.35, -0.35), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Walk_BckStrafeBL", Vector2(-0.35, -0.35), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Walk_FwdStrafeFL", Vector2(-0.35, 0.35), standing_blend)

	# run: outer ring at 1.0 radius
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Run_FwdStrafeF", Vector2(0, 1.0), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Run_FwdStrafeR", Vector2(1.0, 0), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Run_BckStrafeB", Vector2(0, -1.0), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Run_FwdStrafeL", Vector2(-1.0, 0), standing_blend)

	# run diagonals
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Run_FwdStrafeFR", Vector2(0.7, 0.7), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Run_BckStrafeBR", Vector2(0.7, -0.7), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Run_BckStrafeBL", Vector2(-0.7, -0.7), standing_blend)
	add_blend_anim(anim_player,	ANIM_LIB_PREFIX + "Run_FwdStrafeFL", Vector2(-0.7, 0.7), standing_blend)

	return standing_blend

static func build_crouching_blend(anim_player: AnimationPlayer,ANIM_LIB_PREFIX: String) -> AnimationNodeBlendSpace2D:
	var crouching_blend: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	crouching_blend.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	crouching_blend.snap = Vector2(0.01, 0.01)
	
	# idle at center (0, 0)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Idle_Crouching", Vector2.ZERO, crouching_blend)
	
	# shuffle: inner ring at 0.25 radius (slower movement)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Shuffle_Crouching_F", Vector2(0, 0.25), crouching_blend)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Shuffle_Crouching_R", Vector2(0.25, 0), crouching_blend)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Shuffle_Crouching_B", Vector2(0, -0.25), crouching_blend)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Shuffle_Crouching_L", Vector2(-0.25, 0), crouching_blend)
	
	# crouch strafe: middle ring at 0.5 radius (cardinals only, no diagonals available)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Crouch_FwdStrafeF", Vector2(0, 0.5), crouching_blend)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Crouch_FwdStrafeR", Vector2(0.5, 0), crouching_blend)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Crouch_BckStrafeB", Vector2(0, -0.5), crouching_blend)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Crouch_FwdStrafeL", Vector2(-0.5, 0), crouching_blend)
	
	# crouch strafe diagonals: at 0.5 radius
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Crouch_FwdStrafeFR", Vector2(0.35, 0.35), crouching_blend)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Crouch_BckStrafeBR", Vector2(0.35, -0.35), crouching_blend)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Crouch_BckStrafeBL", Vector2(-0.35, -0.35), crouching_blend)
	add_blend_anim(anim_player,ANIM_LIB_PREFIX + "Crouch_FwdStrafeFL", Vector2(-0.35, 0.35), crouching_blend)

	# no crouch run	

	return crouching_blend

# Helper function to add animation to blend space
static func add_blend_anim(anim_player: AnimationPlayer, anim_name: String, pos: Vector2, standing_blend) -> void:
	if anim_player.has_animation(anim_name):
		var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
		node.animation = anim_name
		standing_blend.add_blend_point(node, pos)
	else:
		push_warning("Animation not found: %s" % anim_name)
