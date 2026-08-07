class_name ExploreCheckpointNode
extends Area3D

signal save_requested

@export var area_id: String = "test_room"

var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("explore_player"):
		_player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("explore_player"):
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event.is_action_pressed("interact"):
		save_requested.emit()
		get_viewport().set_input_as_handled()


func can_interact() -> bool:
	return _player_inside
