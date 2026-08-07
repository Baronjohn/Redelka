class_name ExplorePlayer
extends CharacterBody3D

const MOVE_SPEED: float = 4.5
const ACCELERATION: float = 18.0

@export var camera_rig_path: NodePath

var _camera_rig: Node3D
var movement_enabled: bool = true


func _ready() -> void:
	if not camera_rig_path.is_empty():
		_camera_rig = get_node(camera_rig_path) as Node3D
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.82, 0.28)
		mesh.material_override = material


func _physics_process(delta: float) -> void:
	if not movement_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3.ZERO
	if not input_dir.is_zero_approx() and _camera_rig != null:
		direction = _camera_rig.call("get_planar_move_direction", input_dir) as Vector3

	if direction.is_zero_approx():
		velocity.x = move_toward(velocity.x, 0.0, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCELERATION * delta)
	else:
		direction = direction.normalized()
		velocity.x = move_toward(velocity.x, direction.x * MOVE_SPEED, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * MOVE_SPEED, ACCELERATION * delta)

	move_and_slide()


func get_foot_position() -> Vector3:
	return global_position


func set_spawn(position: Vector3, rotation_y: float) -> void:
	global_position = position
	rotation.y = rotation_y
	velocity = Vector3.ZERO
