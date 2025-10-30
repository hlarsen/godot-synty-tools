class_name BaseLocomotionAnimationTreeBuilder

# TODO: handle this so it's not hardcoded or figure something else out
const POLYGON_ANIM_LIB_PREFIX: String = "Polygon_Masculine/"
const UAL_ANIM_LIB_PREFIX: String = "Quaternius_UAL/"

# Helper function to add animation to blend space
static func add_blend_anim(anim_player: AnimationPlayer, anim_name: String, pos: Vector2, blend: AnimationNodeBlendSpace2D) -> void:
	if anim_player.has_animation(anim_name):
		var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
		node.animation = anim_name
		blend.add_blend_point(node, pos)
	else:
		push_warning("Animation not found: %s" % anim_name)

static func add_blend_point_1d(blend: AnimationNodeBlendSpace1D, anim_name: String, pos: float) -> void:
	var node := AnimationNodeAnimation.new()
	node.animation = anim_name
	blend.add_blend_point(node, pos)

# called to help set up character controller
static func add_animation_tree(scene: Node, anim_player: AnimationPlayer) -> void:
	var anim_tree := AnimationTree.new()
	anim_tree.name = "AnimationTree"
	scene.add_child(anim_tree)
	anim_tree.owner = scene
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	var state_machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	anim_tree.tree_root = state_machine

	# animation state machine nodes
	var standing_blend_synty: AnimationNodeBlendSpace2D = build_standing_blend_synty(anim_player, POLYGON_ANIM_LIB_PREFIX)
	# NOTE: project restart needed to see changes to position in editor
	state_machine.add_node("StandingBlend", standing_blend_synty, Vector2(400, 50))
	print("Synty StandingBlend setup complete with %d blend points" % standing_blend_synty.get_blend_point_count())

	var crouching_blend_synty: AnimationNodeBlendSpace2D = build_crouching_blend_synty(anim_player, POLYGON_ANIM_LIB_PREFIX)
	state_machine.add_node("CrouchingBlend", crouching_blend_synty, Vector2(400, 300))
	print("Synty CrouchingBlend setup complete with %d blend points" % crouching_blend_synty.get_blend_point_count())

	# TODO: need to finish these
#	var standing_blend_ual: AnimationNodeBlendSpace1D = build_standing_blend_ual(anim_player, UAL_ANIM_LIB_PREFIX)
#	state_machine.add_node("StandingBlend", standing_blend_ual, Vector2(400, 50))
#	print("Quaternius UAL StandingBlend setup complete with %d blend points" % standing_blend_ual.get_blend_point_count())
#
#	var crouching_blend_ual: AnimationNodeBlendSpace1D = build_crouching_blend_ual(anim_player, UAL_ANIM_LIB_PREFIX)
#	state_machine.add_node("CrouchingBlend", crouching_blend_ual, Vector2(400, 50))
#	print("Quaternius UAL CrouchingBlend setup complete with %d blend points" % standing_blend_ual.get_blend_point_count())

	# transitions
	var start_transition: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	state_machine.add_transition("Start", "StandingBlend", start_transition)

	var stand_to_crouch: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	stand_to_crouch.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	stand_to_crouch.xfade_time = 0.2
	state_machine.add_transition("StandingBlend", "CrouchingBlend", stand_to_crouch)

	var crouch_to_stand: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	crouch_to_stand.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	crouch_to_stand.xfade_time = 0.2
	state_machine.add_transition("CrouchingBlend", "StandingBlend", crouch_to_stand)

#	build_jump_states(state_machine,POLYGON_ANIM_LIB_PREFIX)
#	build_jump_states(state_machine,UAL_ANIM_LIB_PREFIX)

	anim_tree.active = true

static func build_jump_states(state_machine: AnimationNodeStateMachine, anim_lib_prefix: String) -> void:
	var jump_node := AnimationNodeAnimation.new()
	jump_node.animation = anim_lib_prefix + "Jump_Idle"
	state_machine.add_node("Jump", jump_node)
	state_machine.set_node_position("Jump", Vector2(700, 150))

	# animation state machine nodes
	var inair_node := AnimationNodeAnimation.new()
	inair_node.animation = anim_lib_prefix + "InAir_FallShort"
	inair_node.loop_mode = Animation.LOOP_LINEAR
	state_machine.add_node("InAir", inair_node)
	state_machine.set_node_position("InAir", Vector2(500, 125))

	var land_node := AnimationNodeAnimation.new()
	land_node.animation = anim_lib_prefix + "Land_IdleSoft"
	state_machine.add_node("Land", land_node)
	state_machine.set_node_position("Land", Vector2(500, 225))

	# transitions
	var standing_to_jump := AnimationNodeStateMachineTransition.new()
	standing_to_jump.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	state_machine.add_transition("StandingBlend", "Jump", standing_to_jump)
	
	var crouching_to_jump := AnimationNodeStateMachineTransition.new()
	crouching_to_jump.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	state_machine.add_transition("CrouchingBlend", "Jump", crouching_to_jump)

	var jump_to_inair := AnimationNodeStateMachineTransition.new()
	jump_to_inair.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	jump_to_inair.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	state_machine.add_transition("Jump", "InAir", jump_to_inair)

	var inair_to_land := AnimationNodeStateMachineTransition.new()
	inair_to_land.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	state_machine.add_transition("InAir", "Land", inair_to_land)

	var land_to_standing := AnimationNodeStateMachineTransition.new()
	land_to_standing.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	land_to_standing.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	state_machine.add_transition("Land", "StandingBlend", land_to_standing)
	
	var land_to_crouching := AnimationNodeStateMachineTransition.new()
	land_to_crouching.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	land_to_crouching.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	state_machine.add_transition("Land", "CrouchingBlend", land_to_crouching)
	
	print("Jump system added: Jump, InAir, Land states")

static func build_standing_blend_synty(anim_player: AnimationPlayer, anim_lib_prefix: String) -> AnimationNodeBlendSpace2D:
	var standing_blend: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	standing_blend.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	standing_blend.snap = Vector2(0.01, 0.01)

	# idle at center (0, 0)
	add_blend_anim(anim_player, anim_lib_prefix + "Idle_Standing", Vector2.ZERO, standing_blend)

	# walk: inner ring at 0.5 radius
	add_blend_anim(anim_player,	anim_lib_prefix + "Walk_FwdStrafeF", Vector2(0, 0.5), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Walk_FwdStrafeR", Vector2(0.5, 0), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Walk_BckStrafeB", Vector2(0, -0.5), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Walk_FwdStrafeL", Vector2(-0.5, 0), standing_blend)

	# walk diagonals
	add_blend_anim(anim_player,	anim_lib_prefix + "Walk_FwdStrafeFR", Vector2(0.35, 0.35), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Walk_BckStrafeBR", Vector2(0.35, -0.35), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Walk_BckStrafeBL", Vector2(-0.35, -0.35), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Walk_FwdStrafeFL", Vector2(-0.35, 0.35), standing_blend)

	# run: outer ring at 1.0 radius
	add_blend_anim(anim_player,	anim_lib_prefix + "Run_FwdStrafeF", Vector2(0, 1.0), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Run_FwdStrafeR", Vector2(1.0, 0), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Run_BckStrafeB", Vector2(0, -1.0), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Run_FwdStrafeL", Vector2(-1.0, 0), standing_blend)

	# run diagonals
	add_blend_anim(anim_player,	anim_lib_prefix + "Run_FwdStrafeFR", Vector2(0.7, 0.7), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Run_BckStrafeBR", Vector2(0.7, -0.7), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Run_BckStrafeBL", Vector2(-0.7, -0.7), standing_blend)
	add_blend_anim(anim_player,	anim_lib_prefix + "Run_FwdStrafeFL", Vector2(-0.7, 0.7), standing_blend)

	return standing_blend

static func build_crouching_blend_synty(anim_player: AnimationPlayer, anim_lib_prefix: String) -> AnimationNodeBlendSpace2D:
	var crouching_blend: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	crouching_blend.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	crouching_blend.snap = Vector2(0.01, 0.01)
	
	# idle at center (0, 0)
	add_blend_anim(anim_player,anim_lib_prefix + "Idle_Crouching", Vector2.ZERO, crouching_blend)
	
	# shuffle: inner ring at 0.25 radius (slower movement)
	add_blend_anim(anim_player,anim_lib_prefix + "Shuffle_Crouching_F", Vector2(0, 0.25), crouching_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Shuffle_Crouching_R", Vector2(0.25, 0), crouching_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Shuffle_Crouching_B", Vector2(0, -0.25), crouching_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Shuffle_Crouching_L", Vector2(-0.25, 0), crouching_blend)
	
	# crouch strafe: middle ring at 0.5 radius (cardinals only, no diagonals available)
	add_blend_anim(anim_player,anim_lib_prefix + "Crouch_FwdStrafeF", Vector2(0, 0.5), crouching_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Crouch_FwdStrafeR", Vector2(0.5, 0), crouching_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Crouch_BckStrafeB", Vector2(0, -0.5), crouching_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Crouch_FwdStrafeL", Vector2(-0.5, 0), crouching_blend)
	
	# crouch strafe diagonals: at 0.5 radius
	add_blend_anim(anim_player,anim_lib_prefix + "Crouch_FwdStrafeFR", Vector2(0.35, 0.35), crouching_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Crouch_BckStrafeBR", Vector2(0.35, -0.35), crouching_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Crouch_BckStrafeBL", Vector2(-0.35, -0.35), crouching_blend)
	add_blend_anim(anim_player,anim_lib_prefix + "Crouch_FwdStrafeFL", Vector2(-0.35, 0.35), crouching_blend)

	# no crouch run	

	return crouching_blend

static func build_standing_blend_ual(anim_player: AnimationPlayer, anim_lib_prefix: String) -> AnimationNodeBlendSpace1D:
	var blend := AnimationNodeBlendSpace1D.new()
	blend.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_INTERPOLATED
	blend.snap = 0.01

	add_blend_point_1d(blend, anim_lib_prefix + "Idle", 0.0)
	add_blend_point_1d(blend, anim_lib_prefix + "Walk", 0.5)
	add_blend_point_1d(blend, anim_lib_prefix + "Sprint", 1.0)

	return blend

static func build_crouching_blend_ual(anim_player: AnimationPlayer, anim_lib_prefix: String) -> AnimationNodeBlendSpace1D:
	var blend := AnimationNodeBlendSpace1D.new()
	blend.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_INTERPOLATED
	blend.snap = 0.01

	add_blend_point_1d(blend, anim_lib_prefix + "Crouch_Idle", 0.0)
	add_blend_point_1d(blend, anim_lib_prefix + "Crouch_Fwd", 0.5)

	return blend
