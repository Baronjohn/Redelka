class_name NarrativeActor
extends Node3D

signal clicked

@export var actor_id: String = ""
@export var model_scene: PackedScene
@export var display_name: String = ""
@export var portrait_path: String = ""
@export var default_color: Color = Color(1, 1, 1, 1)
@export var start_hidden: bool = false
## Hide the actor on scene load once this story flag is set (e.g. someone who has left).
@export var hide_when_flag: String = ""

var _model: Node3D = null
var _initial_position: Vector3 = Vector3.ZERO
var _initial_rotation_y: float = 0.0


func _ready() -> void:
	if actor_id.is_empty():
		push_warning("NarrativeActor spawned without actor_id")
	_attach_model()
	_initial_position = global_position
	_initial_rotation_y = rotation.y
	if start_hidden:
		visible = false
	if not hide_when_flag.is_empty() and NarrativeDirector.get_flag(hide_when_flag):
		visible = false
	add_to_group("narrative_actors")


func _attach_model() -> void:
	if model_scene == null:
		return
	_model = model_scene.instantiate() as Node3D
	if _model == null:
		return
	add_child(_model)


func move_to(target: Vector3, duration: float) -> void:
	if duration <= 0.001:
		global_position = target
		return
	face_to(target)
	_set_walking(true)
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_property(self, "global_position", target, duration)
	await tween.finished
	_set_walking(false)


func _set_walking(walking: bool) -> void:
	if _model != null and _model.has_method("update_animation"):
		_model.call("update_animation", 0.0, 0.8 if walking else 0.0)


func face_to(target_position: Vector3, duration: float = 0.0) -> void:
	var offset := target_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return
	var target_angle := atan2(offset.x, offset.z)
	if duration <= 0.001:
		rotation.y = target_angle
		return
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_property(self, "rotation:y", target_angle, duration)
	await tween.finished


func face_actor(other: Node3D, duration: float = 0.0) -> void:
	if other == null:
		return
	await face_to(other.global_position, duration)


func show_actor() -> void:
	visible = true


func hide_actor() -> void:
	visible = false


func reset_to_initial() -> void:
	global_position = _initial_position
	rotation.y = _initial_rotation_y


func get_model_node() -> Node3D:
	return _model
