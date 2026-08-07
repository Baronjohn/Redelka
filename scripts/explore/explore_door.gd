class_name ExploreDoor
extends Node3D

signal door_entered(door: Node3D)
signal door_exited(door: Node3D)

@export var target_area_id: String = ""
@export var target_spawn: Vector3 = Vector3.ZERO
@export var target_rotation_y: float = 0.0
@export var door_label: String = "next room"

var _player_inside: bool = false


func _ready() -> void:
	add_to_group("explore_doors")
	var trigger := get_node_or_null("Trigger") as Area3D
	if trigger == null:
		push_error("ExploreDoor requires a Trigger Area3D child.")
		return
	trigger.body_entered.connect(_on_body_entered)
	trigger.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("explore_player"):
		return
	_player_inside = true
	door_entered.emit(self)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("explore_player"):
		return
	_player_inside = false
	door_exited.emit(self)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or target_area_id.is_empty():
		return
	if not event.is_action_pressed("use_door"):
		return
	GameState.travel_to_area(target_area_id, target_spawn, target_rotation_y)
	SceneTransition.go_to_explore()
	get_viewport().set_input_as_handled()


func can_use() -> bool:
	return _player_inside and not target_area_id.is_empty()
