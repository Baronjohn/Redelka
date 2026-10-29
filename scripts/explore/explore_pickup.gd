class_name ExplorePickup
extends Area3D

const ItemModelsScript = preload("res://scripts/assets/item_models.gd")

signal pickup_collected(message: String)

@export var pickup_id: String = ""
@export var item_id: String = ""
@export var count: int = 1

var _player_inside: bool = false
var _glint: MeshInstance3D
var _glint_material: StandardMaterial3D
var _time: float = 0.0


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


## The item's own model lying where it was dropped, with a faint, slow glint so it reads in the dark.
func _build_visual() -> void:
	_time = randf() * 10.0
	var model := ItemModelsScript.build(item_id)
	model.rotation_degrees.y = randf_range(0.0, 360.0)
	add_child(model)
	_glint_material = StandardMaterial3D.new()
	_glint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glint_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glint_material.albedo_color = Color(0.95, 0.85, 0.65, 0.0)
	_glint = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	_glint.mesh = quad
	_glint.material_override = _glint_material
	_glint.position = Vector3(0.06, _model_top(model) + 0.06, 0.04)
	add_child(_glint)
	var click_body := StaticBody3D.new()
	click_body.name = "ClickBody"
	var click_shape := CollisionShape3D.new()
	var click_box := BoxShape3D.new()
	click_box.size = Vector3(0.6, 0.5, 0.6)
	click_shape.shape = click_box
	click_body.position = Vector3(0.0, 0.25, 0.0)
	click_body.add_child(click_shape)
	add_child(click_body)


func _model_top(model: Node3D) -> float:
	var top := 0.2
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		top = maxf(top, box.end.y)
	return minf(top, 1.2)


func _process(delta: float) -> void:
	if _glint_material == null:
		return
	_time += delta
	# A short flash every few seconds, like light catching something metal.
	var phase := fmod(_time, 3.4)
	_glint_material.albedo_color.a = clampf(1.0 - absf(phase - 0.25) * 6.0, 0.0, 1.0) * 0.85


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
