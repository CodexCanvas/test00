# test 06


extends CharacterBody3D

# Movement parameters
@export var WALK_SPEED = 15.0
@export var SPRINT_SPEED = 8.0
@export var CROUCH_SPEED = 3.0
@export var JUMP_VELOCITY = 4.5
@export var MOUSE_SENSITIVITY = 0.003

# Ability parameters
@export var BULLET_TIME_SCALE = 0.3
@export var BULLET_TIME_DURATION = 5.0
@export var BULLET_TIME_COOLDOWN = 3.0
@export var STEALTH_ALPHA = 0.3

# Slide parameters
@export var SLIDE_SPEED = 10.0
@export var SLIDE_DURATION = 0.7
@export var SLIDE_FRICTION = 7.0

# Camera bob parameters
@export var BOB_SPEED = 1.0
@export var BOB_AMPLITUDE_CROUCH = 0.025
@export var BOB_AMPLITUDE_WALK = 0.05

# Node references
@onready var camera = $Camera3D
@onready var character_mesh = $MeshInstance3D

# State variables
@onready var current_speed = WALK_SPEED
var bullet_time_active = false
var bullet_time_timer = 0.0
var bullet_time_cooldown_timer = 0.0
var is_stealthed = false
var is_crouching = false
var initial_camera_height = 0.0
var crouch_camera_height = 0.0
var is_sliding = false
var slide_timer = 0.0
var slide_direction = Vector3.ZERO
var slide_tilt_amount = 0.3

# Get the gravity from the project settings
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	initial_camera_height = camera.position.y
	crouch_camera_height = initial_camera_height * 0.6

func _unhandled_input(event):
	handle_input(event)

func _physics_process(delta):
	if is_sliding:
		handle_slide(delta)
		
	handle_bullet_time(delta)
	
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY * (1.2 if bullet_time_active else 1.0)

	var input_dir = Input.get_vector("left", "right", "forward", "backwards")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_crouching:
		current_speed = CROUCH_SPEED
	else:
		current_speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
	handle_camera_bob(delta)

func handle_input(event):
	if event is InputEventMouseMotion:
		var sensitivity_modifier = 1.0 if !bullet_time_active else 1.5
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY * sensitivity_modifier)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY * sensitivity_modifier)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if event.is_action_pressed("bullet_time"):
		toggle_bullet_time()
	if event.is_action_pressed("stealth"):
		toggle_stealth()
	if event.is_action_pressed("crouch"):
		toggle_crouch()
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("slide") and is_on_floor() and !is_sliding and velocity.length() > 0.5:
		start_slide()

func toggle_bullet_time():
	if bullet_time_cooldown_timer <= 0:
		bullet_time_active = !bullet_time_active
		if bullet_time_active:
			Engine.time_scale = BULLET_TIME_SCALE
			bullet_time_timer = BULLET_TIME_DURATION
		else:
			Engine.time_scale = 1.0

func handle_bullet_time(delta):
	if bullet_time_active:
		bullet_time_timer -= delta
		if bullet_time_timer <= 0:
			bullet_time_active = false
			Engine.time_scale = 1.0
			bullet_time_cooldown_timer = BULLET_TIME_COOLDOWN
	elif bullet_time_cooldown_timer > 0:
		bullet_time_cooldown_timer -= delta

func toggle_stealth():
	is_stealthed = !is_stealthed
	if character_mesh:
		character_mesh.transparency = STEALTH_ALPHA if is_stealthed else 0.0

func toggle_crouch():
	is_crouching = !is_crouching
	var target_height = crouch_camera_height if is_crouching else initial_camera_height
	create_tween().tween_property(camera, "position:y", target_height, 0.2)

func handle_camera_bob(_delta):
	if is_on_floor() and velocity.length() > 0.5:
		var bob_amplitude = BOB_AMPLITUDE_CROUCH if is_crouching else BOB_AMPLITUDE_WALK
		camera.position.y = (initial_camera_height if !is_crouching else crouch_camera_height) + \
						   sin(Time.get_ticks_msec() * 0.01 * BOB_SPEED) * bob_amplitude

func start_slide():
	if is_crouching:
		return
	
	is_sliding = true
	slide_timer = SLIDE_DURATION
	
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	slide_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if slide_direction == Vector3.ZERO:
		slide_direction = -transform.basis.z
	
	velocity = slide_direction * SLIDE_SPEED
	
	var tilt_tween = create_tween().set_ease(Tween.EASE_OUT)
	tilt_tween.tween_property(camera, "rotation:z", -slide_tilt_amount, 0.2)

func handle_slide(delta):
	slide_timer -= delta
	
	velocity = velocity.move_toward(Vector3.ZERO, SLIDE_FRICTION * delta)
	
	if slide_timer <= 0 or velocity.length() < 2.0:
		end_slide()
	
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_vector = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if input_vector != Vector3.ZERO:
		velocity = velocity.lerp(input_vector * SLIDE_SPEED, 0.1)

func end_slide():
	is_sliding = false
	
	var tilt_tween = create_tween().set_ease(Tween.EASE_OUT)
	tilt_tween.tween_property(camera, "rotation:z", 0.0, 0.2)
