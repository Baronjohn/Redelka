class_name ExploreCloset
extends Area3D

const EnvironmentMaterialsScript = preload("res://scripts/assets/environment_materials.gd")
const ItemModelsScript = preload("res://scripts/assets/item_models.gd")

signal ambush_requested(player: CharacterBody3D)
signal closet_interacted(message: String)

@export var closet_id: String = ""
@export var area_id: String = ""
@export var ambush_enemy_id: String = ""
@export var encounter_id: String = ""
@export var pickup_id: String = ""
@export var key_item_id: String = "cellar_key"

var _player_inside: bool = false
var _doors: Array[Node3D] = []
var _key_model: Node3D


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


## A tall wardrobe: body, crown, feet, and two doors that sit a finger's width ajar. Once the
## ambush is beaten the doors hang open and the key lies on the shelf inside until taken.
func _build_visual() -> void:
	var body := EnvironmentMaterialsScript.create_closet_material()
	var trim := EnvironmentMaterialsScript.world_material("timber", Color(0.7, 0.66, 0.62), 0.8)
	var iron := EnvironmentMaterialsScript.world_material("iron", Color(1, 1, 1), 0.5)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.035)
	_add_part(self, Vector3(0.0, 1.05, -0.05), Vector3(1.4, 1.9, 0.65), body)
	_add_part(self, Vector3(0.0, 1.05, 0.29), Vector3(1.28, 1.76, 0.04), dark)
	_add_part(self, Vector3(0.0, 0.85, 0.32), Vector3(1.26, 0.05, 0.12), trim)
	_add_part(self, Vector3(0.0, 2.06, 0.0), Vector3(1.55, 0.14, 0.86), trim)
	_add_part(self, Vector3(0.0, 0.07, 0.0), Vector3(1.5, 0.14, 0.82), trim)
	_doors.clear()
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 0.66, 1.05, 0.39)
		add_child(hinge)
		_add_part(hinge, Vector3(-side * 0.32, 0.0, 0.0), Vector3(0.64, 1.7, 0.04), trim)
		_add_part(hinge, Vector3(-side * 0.6, 0.0, 0.04), Vector3(0.04, 0.16, 0.04), iron)
		hinge.set_meta("side", side)
		_doors.append(hinge)
	_key_model = ItemModelsScript.build(key_item_id)
	_key_model.position = Vector3(0.1, 0.875, 0.32)
	add_child(_key_model)
	_refresh_state()


func _refresh_state() -> void:
	var opened := GameState.is_enemy_defeated(ambush_enemy_id)
	for hinge: Node3D in _doors:
		var side := float(hinge.get_meta("side"))
		hinge.rotation_degrees.y = side * (100.0 if opened else 3.0)
	if _key_model != null:
		_key_model.visible = opened and not pickup_id.is_empty() and not GameState.is_pickup_collected(pickup_id)


func _add_part(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)


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
	SfxManager.play("closet_open")
	if not GameState.is_enemy_defeated(ambush_enemy_id):
		var player := _get_player()
		if player != null:
			ambush_requested.emit(player)
		return true
	if not pickup_id.is_empty() and not GameState.is_pickup_collected(pickup_id):
		var message := GameState.collect_pickup(pickup_id, key_item_id, 1)
		SfxManager.play("pickup")
		_refresh_state()
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
