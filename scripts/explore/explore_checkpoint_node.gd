class_name ExploreCheckpointNode
extends Area3D

signal checkpoint_saved

@export var area_id: String = "test_room"

var _player_inside: bool = false
var _player: CharacterBody3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("explore_player"):
		_player_inside = true
		_player = body as CharacterBody3D


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("explore_player"):
		_player_inside = false
		_player = null


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or _player == null:
		return
	if event.is_action_pressed("interact"):
		GameState.save_checkpoint(area_id, _player.global_position, _player.rotation.y)
		checkpoint_saved.emit()
		get_viewport().set_input_as_handled()


func can_interact() -> bool:
	return _player_inside
