extends CharacterBody3D

@export var speed: float = 5.0
@export var acceleration: float = 4.0
@export var jump_velocity: float = 8.0
@export var face_direction_of_travel: bool = true  # Usually want this for 3rd person
@export var is_crouching: bool = false

# Camera settings
@export_group("Camera")
@export var mouse_sensitivity: float = 0.002
@export var camera_distance: float = 5.0
@export var camera_height_offset: float = 1.5

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var model: Node3D = $Skeleton3D  # Changed to Node3D for rotation
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_rotation: Vector2 = Vector2.ZERO

func _ready() -> void:
	if anim_tree:
		var playback = anim_tree.get("parameters/playback")
		playback.start("StandingBlend")
	
	# Setup camera
	if spring_arm:
		spring_arm.spring_length = camera_distance
		spring_arm.position.y = camera_height_offset
	
	# Capture mouse for camera control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Camera rotation with mouse
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.x -= event.relative.y * mouse_sensitivity
		camera_rotation.y -= event.relative.x * mouse_sensitivity
		camera_rotation.x = clamp(camera_rotation.x, -PI/3, PI/3)  # Limit vertical rotation
	
	# Toggle mouse capture
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Apply camera rotation to spring arm
	if spring_arm:
		spring_arm.rotation.x = camera_rotation.x
		spring_arm.rotation.y = camera_rotation.y
	
	# Gravity
	velocity.y += -gravity * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Movement input (relative to camera)
	var vy: float = velocity.y
	velocity.y = 0
	
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Transform input relative to camera direction
	var camera_basis := Basis()
	if spring_arm:
		camera_basis = spring_arm.global_transform.basis
	
	var dir := Vector3.ZERO
	dir = camera_basis * Vector3(input.x, 0, input.y)
	dir.y = 0  # Keep movement horizontal
	dir = dir.normalized()

	# Update velocity
	velocity = lerp(velocity, dir * speed, acceleration * delta)
	velocity.y = vy

	if not model:
		push_error("No model found")
		return

	if not anim_tree:
		push_error("No anim tree found")
		return

	# Update animation blend position
	var blend_pos: Vector2 = Vector2.ZERO
	if face_direction_of_travel:
		var local_velocity: Vector3 = model.global_transform.basis.inverse() * velocity
		blend_pos = Vector2(local_velocity.x, local_velocity.z) / speed

		# Rotate character to face movement direction
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
