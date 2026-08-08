class_name ExploreCloset
extends Area3D

const EnvironmentMaterialsScript = preload("res://scripts/assets/environment_materials.gd")

signal ambush_requested(player: CharacterBody3D)
signal closet_interacted(message: String)

@export var closet_id: String = ""
@export var area_id: String = ""
@export var ambush_enemy_id: String = ""
@export var encounter_id: String = ""
@export var pickup_id: String = ""
@export var key_item_id: String = "cellar_key"

var _player_inside: bool = false


func _ready() -> void:
	if closet_id.is_empty() or ambush_enemy_id.is_empty() or encounter_id.is_empty():
		push_error("ExploreCloset requires closet_id, ambush_enemy_id, and encounter_id.")
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 2.2, 1.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()


func _build_visual() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 2.0, 0.8)
	mesh.mesh = box
	mesh.material_override = EnvironmentMaterialsScript.create_closet_material()
	mesh.position = Vector3(0.0, 1.0, 0.0)
	add_child(mesh)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("explore_player"):
		_player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("explore_player"):
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not can_interact():
		return
	if event.is_action_pressed("interact"):
		if interact():
			get_viewport().set_input_as_handled()


func interact() -> bool:
	if not can_interact():
		return false
	if not GameState.is_enemy_defeated(ambush_enemy_id):
		var player := _get_player()
		if player != null:
			ambush_requested.emit(player)
		return true
	if not pickup_id.is_empty() and not GameState.is_pickup_collected(pickup_id):
		var message := GameState.collect_pickup(pickup_id, key_item_id, 1)
		closet_interacted.emit(message)
		return true
	closet_interacted.emit("The closet is empty.")
	return true


func can_interact() -> bool:
	return _player_inside and not closet_id.is_empty()


func get_interact_prompt() -> String:
	if not GameState.is_enemy_defeated(ambush_enemy_id):
		return "Press E or click to open the closet"
	if not pickup_id.is_empty() and not GameState.is_pickup_collected(pickup_id):
		return "Press E or click to search the closet"
	return "Press E or click to inspect the closet"


func _get_player() -> CharacterBody3D:
	for node: Node in get_tree().get_nodes_in_group("explore_player"):
		return node as CharacterBody3D
	return null
