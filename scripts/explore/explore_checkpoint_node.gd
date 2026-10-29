class_name ExploreCheckpointNode
extends Area3D

const EnvironmentMaterialsScript = preload("res://scripts/assets/environment_materials.gd")

signal save_requested

@export var area_id: String = "test_room"

var _player_inside: bool = false
var _flame: OmniLight3D
var _time: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_dressing()


## A save point reads as a candle-lit lectern with an open book: the one warm light in the room.
func _build_dressing() -> void:
	var marker := get_node_or_null("CheckpointMarker") as MeshInstance3D
	if marker != null:
		marker.visible = false
	var root := Node3D.new()
	root.name = "Dressing"
	add_child(root)
	root.global_position = Vector3(global_position.x, _floor_y(), global_position.z)
	var stone := EnvironmentMaterialsScript.world_material("flagstone", Color(0.9, 0.9, 0.92), 1.0)
	var wood := EnvironmentMaterialsScript.world_material("timber", Color(0.9, 0.85, 0.8), 0.8)
	var page := StandardMaterial3D.new()
	page.albedo_color = Color(0.78, 0.73, 0.62)
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.82, 0.78, 0.68)
	wax.emission_enabled = true
	wax.emission = Color(0.89, 0.63, 0.35)
	wax.emission_energy_multiplier = 0.25
	_add_box(root, Vector3(0.0, 0.12, 0.0), Vector3(0.9, 0.24, 0.7), stone)
	_add_box(root, Vector3(0.0, 0.62, 0.0), Vector3(0.22, 0.8, 0.22), wood)
	_add_box(root, Vector3(0.0, 1.05, 0.0), Vector3(0.62, 0.06, 0.44), wood, -14.0)
	_add_box(root, Vector3(-0.14, 1.1, 0.0), Vector3(0.26, 0.03, 0.36), page, -14.0)
	_add_box(root, Vector3(0.14, 1.1, 0.0), Vector3(0.26, 0.03, 0.36), page, -14.0)
	for offset: Vector3 in [Vector3(-0.32, 0.3, 0.22), Vector3(0.34, 0.3, 0.2), Vector3(0.3, 0.3, -0.24)]:
		_add_box(root, offset + Vector3(0.0, 0.08, 0.0), Vector3(0.06, 0.16 + absf(offset.x) * 0.2, 0.06), wax)
	_flame = OmniLight3D.new()
	_flame.light_color = Color(1.0, 0.72, 0.4)
	_flame.light_energy = 0.9
	_flame.omni_range = 4.0
	_flame.position = Vector3(0.0, 0.7, 0.0)
	root.add_child(_flame)


func _floor_y() -> float:
	# Checkpoint areas sit about a metre above the floor; dress from the floor up.
	return global_position.y - 1.0


func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, tilt_deg: float = 0.0) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	mesh.rotation_degrees.x = tilt_deg
	parent.add_child(mesh)


func _process(delta: float) -> void:
	if _flame == null:
		return
	_time += delta
	_flame.light_energy = 0.85 + sin(_time * 7.3) * 0.06 + sin(_time * 2.1) * 0.05


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
		if interact():
			get_viewport().set_input_as_handled()


func interact() -> bool:
	if not can_interact():
		return false
	save_requested.emit()
	return true


func can_interact() -> bool:
	return _player_inside
