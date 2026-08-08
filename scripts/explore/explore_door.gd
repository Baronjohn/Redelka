class_name ExploreDoor
extends Node3D

signal door_entered(door: Node3D)
signal door_exited(door: Node3D)

@export var target_area_id: String = ""
@export var target_spawn: Vector3 = Vector3.ZERO
@export var target_rotation_y: float = 0.0
@export var door_label: String = "next room"
@export var required_item_id: String = ""

var _player_inside: bool = false


func _ready() -> void:
	add_to_group("explore_doors")
	_orient_panel_to_wall()
	var trigger := get_node_or_null("Trigger") as Area3D
	if trigger == null:
		push_error("ExploreDoor requires a Trigger Area3D child.")
		return
	trigger.body_entered.connect(_on_body_entered)
	trigger.body_exited.connect(_on_body_exited)


func _orient_panel_to_wall() -> void:
	var panel := get_node_or_null("Panel") as Node3D
	if panel == null:
		return
	var panel_pos := panel.position
	if absf(panel_pos.z) <= absf(panel_pos.x):
		return
	panel.rotate_y(PI / 2.0)
	var trigger := get_node_or_null("Trigger") as Node3D
	if trigger != null:
		trigger.rotate_y(PI / 2.0)


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
	if not can_use():
		return
	if event.is_action_pressed("interact"):
		if interact():
			get_viewport().set_input_as_handled()


func interact() -> bool:
	if not can_use():
		return false
	GameState.travel_to_area(target_area_id, target_spawn, target_rotation_y)
	SceneTransition.go_to_explore()
	return true


func can_use() -> bool:
	if not _player_inside or target_area_id.is_empty():
		return false
	if is_locked():
		return false
	return true


func is_locked() -> bool:
	if required_item_id.is_empty():
		return false
	return _player_inside and not GameState.has_item(required_item_id)


func get_lock_prompt() -> String:
	return "Locked — requires %s" % _get_required_item_name()


func _get_required_item_name() -> String:
	var items := DataLoader.load_items()
	if items.has(required_item_id):
		return (items[required_item_id] as ItemData).display_name
	return required_item_id
