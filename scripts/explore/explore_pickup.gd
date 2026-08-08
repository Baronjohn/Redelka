class_name ExplorePickup
extends Area3D

const EnvironmentMaterialsScript = preload("res://scripts/assets/environment_materials.gd")

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
	mesh.material_override = EnvironmentMaterialsScript.create_pickup_material()
	mesh.position = Vector3(0.0, 0.45, 0.0)
	add_child(mesh)
	var click_body := StaticBody3D.new()
	click_body.name = "ClickBody"
	var click_shape := CollisionShape3D.new()
	var click_box := BoxShape3D.new()
	click_box.size = Vector3(0.5, 0.5, 0.5)
	click_shape.shape = click_box
	click_body.position = Vector3(0.0, 0.45, 0.0)
	click_body.add_child(click_shape)
	add_child(click_body)


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
	SfxManager.play("pickup")
	var message := GameState.collect_pickup(pickup_id, item_id, count)
	pickup_collected.emit(message)
	queue_free()
	return true


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
