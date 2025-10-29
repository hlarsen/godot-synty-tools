extends CharacterBody3D

@export var speed: float = 5.0
@export var acceleration: float = 4.0
@export var jump_velocity: float = 8.0
@export var face_direction_of_travel: bool = false
@export var is_crouching: bool = false

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var model: Skeleton3D = $Skeleton3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	if anim_tree:
		var playback = anim_tree.get("parameters/playback")
		playback.start("StandingBlend")

func _physics_process(delta: float) -> void:
	# gravity
	velocity.y += -gravity * delta

	# jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# movement input
	var vy: float = velocity.y
	velocity.y = 0
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var dir := Vector3(input.x, 0, input.y)

	# update velocity
	velocity = lerp(velocity, dir * speed, acceleration * delta)
	velocity.y = vy

	if not model:
		push_error("No model found")
		return

	if not anim_tree:
		push_error("No anim tree found")
		return

	# update animation blend position
	var blend_pos: Vector2 = Vector2.ZERO
	if face_direction_of_travel:
		var local_velocity: Vector3 = model.global_transform.basis.inverse() * velocity
		blend_pos = Vector2(local_velocity.x, local_velocity.z) / speed

		if dir.length() > 0.01:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	else:
		blend_pos = Vector2(velocity.x, -velocity.z) / speed

	var playback = anim_tree.get("parameters/playback")
	if is_crouching:
		playback.travel("CrouchingBlend")
		anim_tree.set("parameters/CrouchingBlend/blend_position", blend_pos)
	else:
		playback.travel("StandingBlend")
		anim_tree.set("parameters/StandingBlend/blend_position", blend_pos)

	move_and_slide()
