extends CharacterBody3D

# ── Exportables (editables desde el Inspector) ────────────────
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 6.0
@export var mouse_sensitivity: float = 0.15
@export var min_pitch: float = -60.0
@export var max_pitch: float = 40.0
@export var rotation_speed: float = 7.0
@export var cam_offset_idle: float = 0.4
@export var cam_offsetApuntar: float = 1.1
@export var cam_offset_walk: float = 0.3
@export var cam_offset_sprint: float = 0.15
@export var cam_offset_lerp: float = 6.0

# ── Nodos (se asignan solos con @onready) ─────────────────────
@onready var camera: Camera3D         =  $CameraBase/CameraRot/SpringArm/Camera
@onready var pivot_x: Node3D          =  $CameraBase/CameraRot
@onready var pivot_y: Node3D          = $CameraBase
@onready var spring_arm: SpringArm3D  =  $CameraBase/CameraRot/SpringArm
@onready var mesh_pivot: Node3D       =  $MeshPivot

# ── Variables internas ────────────────────────────────────────
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var airborne_time: float = 0.0
var cam_offset_current: float = 0.4

# ── _ready ────────────────────────────────────────────────────
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)



@export var CAMERA_CONTROLLER_ROTATION_SPEED2: float =1.5
@export var CAMERA_MOUSE_ROTATION_SPEED2: float = 0.1  
func rotate_cameraOnly( rotation_amount ) -> void:
	pivot_y.rotate_y(deg_to_rad(-rotation_amount.x * mouse_sensitivity))
	pivot_x.rotation_degrees.x += rotation_amount.y * mouse_sensitivity*-1.0
	pivot_x.rotation_degrees.x = clamp(pivot_x.rotation_degrees.x, min_pitch, max_pitch)
# ── Captura el mouse para rotar la cámara ─────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pivot_y.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		pivot_x.rotation_degrees.x += event.relative.y * mouse_sensitivity*-1.0
		pivot_x.rotation_degrees.x = clamp(pivot_x.rotation_degrees.x, min_pitch, max_pitch)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# ── Lógica principal ──────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	_update_cam_offset(delta)
	move_and_slide()

# ── Gravedad ──────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		airborne_time += delta
	else:
		airborne_time = 0.0

# ── Salto ─────────────────────────────────────────────────────
func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

# ── Movimiento WASD relativo a la cámara ──────────────────────
func _handle_movement(delta: float) -> void:
	var speed = sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back")  - Input.get_action_strength("move_forward")
	)
	var camera_move = Vector2(
		Input.get_action_strength("view_right") - Input.get_action_strength("view_left"),
		Input.get_action_strength("view_up")    - Input.get_action_strength("view_down")
	)
	 
	#rotate_camera(camera_move * CAMERA_CONTROLLER_ROTATION_SPEED * delta_real)
	camera_move.y=camera_move.y*-10.0;
	camera_move.x=camera_move.x*20.0;
	rotate_cameraOnly(  camera_move    )
		

	var cam_basis := camera.global_transform.basis
	var cam_z     := Vector3(cam_basis.z.x, 0.0, cam_basis.z.z).normalized()
	var cam_x     := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()

	var world_dir := Vector3.ZERO
	if input_dir.length() > 0.001:
		world_dir = (cam_x * input_dir.x + cam_z * input_dir.y).normalized()

	velocity.x = world_dir.x * speed
	velocity.z = world_dir.z * speed

	# Rotar el mesh hacia la dirección de movimiento
	if world_dir.length() > 0.1:
		var target_angle := atan2(world_dir.x, world_dir.z)
		mesh_pivot.rotation.y = lerp_angle(
			mesh_pivot.rotation.y,
			target_angle,
			rotation_speed * delta
		)

# ── Offset OTS de la cámara ───────────────────────────────────
func _update_cam_offset(delta: float) -> void:
	var is_moving  := Vector2(velocity.x, velocity.z).length() > 0.1
	var is_sprint  := Input.is_action_pressed("sprint") and is_moving
	
	var isApuntar:= Input.is_action_pressed("aim")    

	var target_offset: float
	if isApuntar:
		target_offset = cam_offsetApuntar
	elif is_moving:
		target_offset = cam_offset_walk
	elif is_sprint:
		 
		target_offset = cam_offset_sprint
		 
	else:
		target_offset = cam_offset_idle

	cam_offset_current = lerp(cam_offset_current, target_offset, cam_offset_lerp * delta)
	spring_arm.transform.origin.x = cam_offset_current
	
