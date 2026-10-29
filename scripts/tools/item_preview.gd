extends Node3D

## Dev tool: renders every item model (ItemModels) laid out on a floor, with name labels.
## Run: godot --path . res://scenes/tools/item_preview.tscn [-- <output_dir>]
## Writes item_preview.png (all items, labelled) and item_<id>.png (one framed close-up per item).

const ItemModelsScript = preload("res://scripts/assets/item_models.gd")
const EnvironmentMaterialsScript = preload("res://scripts/assets/environment_materials.gd")
const COLUMNS: int = 7
const SPACING: float = 1.0
const DEFAULT_OUTPUT_DIR: String = "/tmp"

var _camera: Camera3D
var _models: Array[Node3D] = []


func _ready() -> void:
	var ids: Array[String] = []
	for item_id: String in DataLoader.load_items().keys():
		ids.append(item_id)
	for item_id: String in DataLoader.load_equipment().keys():
		ids.append(item_id)
	for item_id: String in DataLoader.load_weapons().keys():
		ids.append(item_id)
	var rows := int(ceil(float(ids.size()) / COLUMNS))
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(COLUMNS * SPACING + 2.0, rows * SPACING + 2.0)
	floor.mesh = plane
	floor.material_override = EnvironmentMaterialsScript.world_material("flagstone", Color(0.75, 0.75, 0.78), 2.0)
	floor.position = Vector3(0, 0, 0)
	add_child(floor)
	var names := _display_names()
	for index: int in ids.size():
		var col := index % COLUMNS
		var row := index / COLUMNS
		var pos := Vector3((col - (COLUMNS - 1) * 0.5) * SPACING, 0.0, (row - (rows - 1) * 0.5) * SPACING)
		var model := ItemModelsScript.build(ids[index])
		model.position = pos
		model.set_meta("item_id", ids[index])
		add_child(model)
		_models.append(model)
		var label := Label3D.new()
		label.text = str(names.get(ids[index], ids[index]))
		label.font_size = 28
		label.pixel_size = 0.004
		label.modulate = Color(0.87, 0.84, 0.78)
		label.outline_size = 6
		label.rotation_degrees.x = -60.0
		label.position = pos + Vector3(0, 0.01, 0.36)
		add_child(label)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.045, 0.05, 0.062)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.52, 0.6)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.current = true

	var output_dir := DEFAULT_OUTPUT_DIR
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output_dir = args[0]
	var depth := rows * SPACING
	await _shoot(Vector3(0, depth * 2.2 + 2.0, depth * 1.4 + 1.5), Vector3(0, 0, 0.1), output_dir.path_join("item_preview.png"))
	# One framed shot per item, sized from its bounds, labels hidden.
	for node: Node in get_children():
		if node is Label3D:
			(node as Label3D).visible = false
	for model: Node3D in _models:
		var bounds := _bounds(model)
		var radius := maxf(bounds.size.length() * 0.5, 0.12)
		var centre := bounds.get_center()
		var eye := centre + Vector3(0.0, radius * 1.3, radius * 2.1)
		await _shoot(eye, centre, output_dir.path_join("item_%s.png" % model.get_meta("item_id")))
	print("Item preview saved to %s" % output_dir)
	get_tree().quit()


func _bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _display_names() -> Dictionary:
	var names: Dictionary = {}
	for item: ItemData in DataLoader.load_items().values():
		names[item.id] = item.display_name
	for item_id: String in DataLoader.load_equipment().keys():
		names[item_id] = DataLoader.load_equipment()[item_id].display_name
	for weapon: WeaponData in DataLoader.load_weapons().values():
		names[weapon.id] = weapon.display_name
	return names


func _shoot(from: Vector3, target: Vector3, path: String) -> void:
	_camera.global_position = from
	_camera.look_at(target, Vector3.UP)
	for _i: int in range(4):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
