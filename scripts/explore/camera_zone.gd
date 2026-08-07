class_name CameraZone
extends Area3D

@export var camera_position: Vector3 = Vector3(0.0, 8.0, 10.0)
@export var look_target_offset: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var track_strength: float = 0.35

var _rig: Node3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var explore := get_tree().current_scene
	if explore != null and explore.has_node("CameraRig"):
		_rig = explore.get_node("CameraRig") as Node3D


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("explore_player") and _rig != null:
		_rig.call("set_active_zone", self)


func get_camera_anchor(track_position: Vector3) -> Transform3D:
	var focus := track_position.lerp(global_position + look_target_offset, track_strength)
	var transform := Transform3D.IDENTITY
	transform.origin = global_position + camera_position
	transform = transform.looking_at(focus, Vector3.UP)
	return transform
