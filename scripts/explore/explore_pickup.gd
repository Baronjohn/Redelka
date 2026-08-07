class_name ExplorePickup
extends Area3D

signal pickup_collected(message: String)

@export var pickup_id: String = ""
@export var item_id: String = ""
@export var count: int = 1

var _player_inside: bool = false


func _ready() -> void:
	if pickup_id.is_empty() or item_id.is_empty():
		push_error("ExplorePickup requires pickup_id and item_id.")
		return
	if GameState.is_pickup_collected(pickup_id):
		queue_free()
		return
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()


func _build_visual() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.82, 0.28, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.95, 0.82, 0.28, 1.0)
	material.emission_energy_multiplier = 0.35
	mesh.material_override = material
	mesh.position = Vector3(0.0, 0.45, 0.0)
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
	if not event.is_action_pressed("interact"):
		return
	var message := GameState.collect_pickup(pickup_id, item_id, count)
	pickup_collected.emit(message)
	queue_free()
	get_viewport().set_input_as_handled()


func can_interact() -> bool:
	return _player_inside and not pickup_id.is_empty() and not item_id.is_empty()


func get_pickup_label() -> String:
	return _get_item_display_name()


func _get_item_display_name() -> String:
	var items := DataLoader.load_items()
	if items.has(item_id):
		return (items[item_id] as ItemData).display_name
	var weapons := DataLoader.load_weapons()
	if weapons.has(item_id):
		return (weapons[item_id] as WeaponData).display_name
	var equipment := DataLoader.load_equipment()
	if equipment.has(item_id):
		return equipment[item_id].display_name
	return item_id
