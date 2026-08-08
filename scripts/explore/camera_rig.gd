class_name CameraRig
extends Node3D

const SWITCH_BLEND: float = 0.35

@export var camera_path: NodePath
@export var default_zone_path: NodePath

var _camera: Camera3D
var _active_zone: Node3D
var _target_position: Vector3 = Vector3.ZERO
var _target_basis: Basis = Basis.IDENTITY
var _track_target: Node3D


func _ready() -> void:
	if not camera_path.is_empty():
		_camera = get_node(camera_path) as Camera3D
	if _camera != null:
		_camera.current = true


func set_track_target(target: Node3D) -> void:
	_track_target = target
	if _active_zone == null and not default_zone_path.is_empty():
		var zone := get_node(default_zone_path) as Node3D
		if zone != null:
			_active_zone = zone
	_snap_camera_to_target()


func set_active_zone(zone: Node3D) -> void:
	if zone == null or zone == _active_zone:
		return
	_active_zone = zone
	_snap_camera_to_target()


func _process(delta: float) -> void:
	if _camera == null or _active_zone == null or _track_target == null:
		return
	_recompute_camera_target()
	var blend := clampf(delta / SWITCH_BLEND, 0.0, 1.0)
	_camera.global_position = _camera.global_position.lerp(_target_position, blend)
	_camera.global_basis = _camera.global_basis.slerp(_target_basis, blend)


func _snap_camera_to_target() -> void:
	if not _recompute_camera_target():
		return
	_camera.global_position = _target_position
	_camera.global_basis = _target_basis


func _recompute_camera_target() -> bool:
	if _camera == null or _active_zone == null or _track_target == null:
		return false
	var anchor: Transform3D = _active_zone.call(
		"get_camera_anchor", _track_target.global_position
	) as Transform3D
	_target_position = anchor.origin
	_target_basis = anchor.basis
	return true


func get_planar_move_direction(input_dir: Vector2) -> Vector3:
	if _camera == null:
		return Vector3(input_dir.x, 0.0, input_dir.y)
	var forward := -_camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := _camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return forward * -input_dir.y + right * input_dir.x


func get_camera() -> Camera3D:
	return _camera
