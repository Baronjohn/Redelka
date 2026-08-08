class_name ExplorePlayer
extends CharacterBody3D

const MOVE_SPEED: float = 4.5
const ACCELERATION: float = 18.0
const FACE_SPEED: float = 14.0
const PROTAGONIST_MODEL: PackedScene = preload("res://scenes/characters/bran.tscn")

@export var camera_rig_path: NodePath

var _camera_rig: Node3D
var _walk_model: Ps1BlockModel = null
var movement_enabled: bool = true


func _ready() -> void:
	if not camera_rig_path.is_empty():
		_camera_rig = get_node(camera_rig_path) as Node3D
	_attach_protagonist_model()


func _attach_protagonist_model() -> void:
	var placeholder := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if placeholder != null:
		placeholder.visible = false
	var model_root := get_node_or_null("ModelRoot") as Node3D
	if model_root == null:
		model_root = Node3D.new()
		model_root.name = "ModelRoot"
		add_child(model_root)
	for child: Node in model_root.get_children():
		child.queue_free()
	if PROTAGONIST_MODEL != null:
		var model := PROTAGONIST_MODEL.instantiate() as Node3D
		model_root.add_child(model)
		_walk_model = model as Ps1BlockModel


func _physics_process(delta: float) -> void:
	if not movement_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if _walk_model != null:
			_walk_model.update_walk_animation(delta, 0.0)
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
	_update_mouse_facing(delta)
	if _walk_model != null:
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		var speed_ratio := clampf(horizontal_speed / MOVE_SPEED, 0.0, 1.0)
		_walk_model.update_walk_animation(delta, speed_ratio)


func _update_mouse_facing(delta: float) -> void:
	var camera := _get_camera()
	if camera == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	if absf(ray_direction.y) < 0.0001:
		return
	var plane_y := global_position.y
	var hit_distance := (plane_y - ray_origin.y) / ray_direction.y
	if hit_distance < 0.0:
		return
	var target := ray_origin + ray_direction * hit_distance
	var look_dir := target - global_position
	look_dir.y = 0.0
	if look_dir.length_squared() < 0.0001:
		return
	var target_angle := atan2(look_dir.x, look_dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, FACE_SPEED * delta)


func _get_camera() -> Camera3D:
	if _camera_rig == null or not _camera_rig.has_method("get_camera"):
		return null
	return _camera_rig.call("get_camera") as Camera3D


func get_foot_position() -> Vector3:
	return global_position


func set_spawn(position: Vector3, rotation_y: float) -> void:
	global_position = position
	rotation.y = rotation_y
	velocity = Vector3.ZERO
