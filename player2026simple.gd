extends CharacterBody3D

# ── Exportables (editables desde el Inspector) ────────────────
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 12.0
@export var mouse_sensitivity: float = 0.15
@export var min_pitch: float = -60.0
@export var max_pitch: float = 40.0
@export var rotation_speed: float = 7.0
@export var cam_offset_idle: float = 0.4
@export var cam_offsetApuntar: float = 1.1
@export var cam_offset_walk: float = 0.3
@export var cam_offset_sprint: float = 0.15
@export var cam_offset_lerp: float = 6.0
var isFierre: bool = false

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
	physicsProcessBullet(delta)

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
		target_offset = 1.2
	elif is_sprint:		 
		target_offset = cam_offset_sprint*0
	elif is_moving:
		target_offset = cam_offset_walk	 
	else:
		target_offset = cam_offset_idle

	cam_offset_current = lerp(cam_offset_current, target_offset, cam_offset_lerp * delta)
	spring_arm.transform.origin.x = cam_offset_current
	
#fire Ini
var _bullet_count=0
var isFire=false;
var _is_shooting:bool=false;
var _bullets=[]
var counttimeanterbulet=0
func physicsProcessBullet(delta):
	fireSimple(delta)	
	if counttimeanterbulet >=20 and not isFire:
		_cleanup_bullets()
 
 
@onready var shooTo :Node3D= $CameraBase/CameraRot/SpringArm/Camera/shooTo
@onready var shootFrom :Node3D=  $CameraBase/CameraRot/SpringArm/Camera/ShootFrom
func  fireSimple(delta):
	if Input.is_action_just_pressed("shoot"):
		if(await movimientoCamera(camera)):
			var dir= (shooTo.global_position-shootFrom.global_position).normalized()
			_spawn_bullet(shootFrom.global_position, dir, 70)
			
			pass
		 
	if Input.is_action_just_released("shoot"):
		isFire = false
	if(!isFire and _bullets.size()>0):
		counttimeanterbulet=counttimeanterbulet+1
		pass


func _spawn_bullet(spawn_pos:Vector3, shoot_dir:Vector3, speedBullet:float=70):
	isFire = true
	var bullet_body = RigidBody3D.new()
	var col_shape   = CollisionShape3D.new()
	var sphere      = SphereShape3D.new()
	var mesh_inst   = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	var material    = StandardMaterial3D.new()

	sphere.radius      = 0.1
	col_shape.shape    = sphere

	sphere_mesh.radius = sphere.radius
	sphere_mesh.height = sphere.radius * 2
	material.albedo_color     = Color(1, 0, 0)
	material.emission_enabled = true
	material.emission         = Color(1, 0, 0)
	material.emission_energy_multiplier = 3.0
	mesh_inst.mesh              = sphere_mesh
	mesh_inst.material_override = material

	var omni_light = OmniLight3D.new()
	omni_light.light_color = Color(1, 0.5, 0.5)
	omni_light.light_energy = 5.0
	omni_light.omni_range = 5.0
	omni_light.transform.origin = Vector3(0, 0, 0)

	bullet_body.add_child(col_shape)
	bullet_body.add_child(mesh_inst)
	bullet_body.add_child(omni_light)

	bullet_body.add_collision_exception_with(self)
	get_parent().add_child(bullet_body)
	bullet_body.global_transform.origin = spawn_pos
	bullet_body.linear_velocity = shoot_dir * speedBullet

	_bullets.append(bullet_body)
	_bullet_count += 1
func _cleanup_bullets():
	for b in _bullets:
		if is_instance_valid(b):
			b.queue_free()
	_bullets.clear()
	_bullet_count= 0
	counttimeanterbulet=0 



func rotate_node3d_euler_lerp_and_back(node_to_rotate: Node3D, target_angle_degrees: float, axis: Vector3.Axis, duration: float = 0.1):
	 
	var axis_index: int
	match axis:
		Vector3.AXIS_X: axis_index = 0
		Vector3.AXIS_Y: axis_index = 1
		Vector3.AXIS_Z: axis_index = 2
		_:
			push_error("Eje de rotación inválido. Debe ser Vector3.AXIS_X, Y o Z para Euler.")
			return

	var initial_rotation_radians: Vector3 = node_to_rotate.rotation
	var target_rotation_radians: Vector3 = initial_rotation_radians
	target_rotation_radians[axis_index] = deg_to_rad(target_angle_degrees)

	var t_start_forward: float = Time.get_ticks_msec() / 1000.0
	while (Time.get_ticks_msec() / 1000.0 - t_start_forward) < duration:
		var t_progress: float = (Time.get_ticks_msec() / 1000.0 - t_start_forward) / duration
		node_to_rotate.rotation = initial_rotation_radians.lerp(target_rotation_radians, t_progress)
		await get_tree().process_frame

	node_to_rotate.rotation = target_rotation_radians
	await get_tree().process_frame

	var t_start_backward: float = Time.get_ticks_msec() / 1000.0
	while (Time.get_ticks_msec() / 1000.0 - t_start_backward) < duration:
		var t_progress: float = (Time.get_ticks_msec() / 1000.0 - t_start_backward) / duration
		node_to_rotate.rotation = target_rotation_radians.lerp(initial_rotation_radians, t_progress)
		await get_tree().process_frame

	node_to_rotate.rotation = initial_rotation_radians
	await get_tree().process_frame
	return true
 
 
func rotate_node3d_lerp_and_back(node_to_rotate: Node3D, target_angle_degrees: float, axis: Vector3, duration: float = 0.1):
	 

	var initial_rotation_quat: Quaternion = node_to_rotate.global_transform.basis.get_rotation_quaternion()
	var target_rotation_quat: Quaternion = initial_rotation_quat * Quaternion(axis, deg_to_rad(target_angle_degrees))

	var t_start_forward: float = Time.get_ticks_msec() / 1000.0
	while (Time.get_ticks_msec() / 1000.0 - t_start_forward) < duration:
		var t_progress: float = (Time.get_ticks_msec() / 1000.0 - t_start_forward) / duration
		node_to_rotate.global_transform.basis = Basis(initial_rotation_quat.slerp(target_rotation_quat, t_progress))
		await get_tree().process_frame

	node_to_rotate.global_transform.basis = Basis(target_rotation_quat)
	await get_tree().process_frame

	var t_start_backward: float = Time.get_ticks_msec() / 1000.0
	while (Time.get_ticks_msec() / 1000.0 - t_start_backward) < duration:
		var t_progress: float = (Time.get_ticks_msec() / 1000.0 - t_start_backward) / duration
		node_to_rotate.global_transform.basis = Basis(target_rotation_quat.slerp(initial_rotation_quat, t_progress))
		await get_tree().process_frame

	node_to_rotate.global_transform.basis = Basis(initial_rotation_quat)
	await get_tree().process_frame
	return true
 
func movimientoCamera(camera:Camera3D):
	var bl = await rotate_node3d_euler_lerp_and_back(camera  , -3, Vector3.AXIS_X,  0.1)
	return  bl
 
#firre end
