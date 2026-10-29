class_name ExploreDoor
extends Node3D

const EnvironmentMaterialsScript = preload("res://scripts/assets/environment_materials.gd")

signal door_entered(door: Node3D)
signal door_exited(door: Node3D)

@export var target_area_id: String = ""
@export var target_spawn: Vector3 = Vector3.ZERO
@export var target_rotation_y: float = 0.0
@export var door_label: String = "next room"
@export var required_item_id: String = ""
## Story flag that must be set before the door opens (narrative gating).
@export var required_story_flag: String = ""
@export var flag_locked_prompt: String = "Not yet."
## How the doorway is dressed: a plank door in a timber frame, an open field gate,
## or a dark passage (a gap between buildings).
@export_enum("door", "gate", "passage") var door_style: String = "door"

var _player_inside: bool = false


func _ready() -> void:
	add_to_group("explore_doors")
	_orient_panel_to_wall()
	_build_dressing()
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


## Replaces the placeholder slab with a dressed doorway, built in the panel's local space
## (x = through the wall, y = up, z = across the opening), so it follows the panel's rotation.
func _build_dressing() -> void:
	var panel := get_node_or_null("Panel") as Node3D
	if panel == null or panel.has_node("Dressing"):
		return
	var slab := panel.get_node_or_null("DoorMesh") as MeshInstance3D
	if slab != null:
		slab.visible = false
	var root := Node3D.new()
	root.name = "Dressing"
	panel.add_child(root)
	var timber := EnvironmentMaterialsScript.world_material("timber", Color(0.8, 0.76, 0.72), 1.2)
	var boards := EnvironmentMaterialsScript.world_material("boards", Color(1, 1, 1), 1.0)
	var iron := EnvironmentMaterialsScript.world_material("iron", Color(1, 1, 1), 0.6)
	var bottom := -1.2
	match door_style:
		"gate":
			for z: float in [-1.55, 1.55]:
				_box(root, Vector3(0.0, bottom + 0.75, z), Vector3(0.2, 1.5, 0.2), timber)
			for y: float in [0.35, 0.8, 1.2]:
				_box(root, Vector3(0.0, bottom + y, 0.0), Vector3(0.08, 0.1, 3.0), boards)
			_box(root, Vector3(0.0, bottom + 0.78, 0.0), Vector3(0.07, 0.1, 3.2), boards, 24.0)
		"passage":
			for z: float in [-1.7, 1.7]:
				_box(root, Vector3(0.0, bottom + 1.4, z), Vector3(0.5, 2.8, 0.25), timber)
			_box(root, Vector3(0.0, bottom + 2.75, 0.0), Vector3(0.55, 0.3, 3.7), timber)
			var void_mat := StandardMaterial3D.new()
			void_mat.albedo_color = Color(0.01, 0.012, 0.016)
			void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_box(root, Vector3(0.12, bottom + 1.3, 0.0), Vector3(0.05, 2.6, 3.2), void_mat)
		_:
			for z: float in [-1.75, 1.75]:
				_box(root, Vector3(0.0, bottom + 1.45, z), Vector3(0.45, 2.9, 0.3), timber)
			_box(root, Vector3(0.0, bottom + 2.95, 0.0), Vector3(0.55, 0.32, 3.95), timber)
			_box(root, Vector3(0.05, bottom + 0.04, 0.0), Vector3(0.6, 0.08, 3.4), timber)
			for side: float in [-1.0, 1.0]:
				var z := side * 0.79
				_box(root, Vector3(0.0, bottom + 1.4, z), Vector3(0.12, 2.76, 1.54), boards)
				for y: float in [0.45, 1.35, 2.3]:
					_box(root, Vector3(-0.075, bottom + y, z), Vector3(0.03, 0.09, 1.36), iron)
					_box(root, Vector3(0.075, bottom + y, z), Vector3(0.03, 0.09, 1.36), iron)
				_box(root, Vector3(-0.09, bottom + 1.15, side * 0.2), Vector3(0.05, 0.14, 0.05), iron)
				_box(root, Vector3(0.09, bottom + 1.15, side * 0.2), Vector3(0.05, 0.14, 0.05), iron)
			if not required_item_id.is_empty():
				_box(root, Vector3(-0.1, bottom + 1.35, 0.0), Vector3(0.08, 0.22, 0.18), iron)
				_box(root, Vector3(-0.1, bottom + 1.35, 0.0), Vector3(0.1, 0.06, 0.5), iron)


func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, roll_deg: float = 0.0) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	mesh.rotation_degrees.x = roll_deg
	parent.add_child(mesh)


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
	SfxManager.play("door_open")
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
	if not _player_inside:
		return false
	if not required_story_flag.is_empty() and not NarrativeDirector.get_flag(required_story_flag):
		return true
	if required_item_id.is_empty():
		return false
	return not GameState.has_item(required_item_id)


func get_lock_prompt() -> String:
	if not required_story_flag.is_empty() and not NarrativeDirector.get_flag(required_story_flag):
		return flag_locked_prompt
	return "Locked — requires %s" % _get_required_item_name()


func _get_required_item_name() -> String:
	var items := DataLoader.load_items()
	if items.has(required_item_id):
		return (items[required_item_id] as ItemData).display_name
	return required_item_id
