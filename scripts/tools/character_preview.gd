extends Node3D

## Dev tool: renders every survivor and enemy model (front, back, heads) to PNGs.
## Run: godot --path . res://scenes/tools/character_preview.tscn [-- <output_dir>]
## Output defaults to /tmp: redelka_preview.png plus _sides, _backs and _closeup_<n> (two models each).

const SPACING: float = 1.25
const DEFAULT_OUTPUT_DIR: String = "/tmp"

var _models: Array[Node3D] = []
var _camera: Camera3D


func _ready() -> void:
	var paths: Array[String] = []
	for character: CharacterData in DataLoader.load_characters().values():
		paths.append(character.model_path)
	for enemy: EnemyData in DataLoader.load_enemies().values():
		paths.append(enemy.model_path)
	var start_x := -SPACING * float(paths.size() - 1) * 0.5
	for index: int in paths.size():
		var model := (load(paths[index]) as PackedScene).instantiate() as Node3D
		add_child(model)
		model.position = Vector3(start_x + SPACING * float(index), 0.0, 0.0)
		_models.append(model)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	light.light_energy = 1.15
	add_child(light)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.13, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.5, 0.55)
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
	var width := SPACING * float(paths.size())
	await _shoot(Vector3(0.0, 1.1, width * 1.25), Vector3(0.0, 0.9, 0.0), output_dir.path_join("redelka_preview.png"))
	for pair: int in range(0, paths.size(), 2):
		var x := start_x + SPACING * (float(pair) + 0.5)
		await _shoot(Vector3(x, 1.55, 2.3), Vector3(x, 1.35, 0.0),
			output_dir.path_join("redelka_preview_closeup_%d.png" % (pair / 2)))
	for model: Node3D in _models:
		model.rotation.y = PI * 0.5
	await _shoot(Vector3(0.0, 1.1, width * 1.25), Vector3(0.0, 0.9, 0.0), output_dir.path_join("redelka_preview_sides.png"))
	for model: Node3D in _models:
		model.rotation.y = PI
	await _shoot(Vector3(0.0, 1.1, width * 1.25), Vector3(0.0, 0.9, 0.0), output_dir.path_join("redelka_preview_backs.png"))
	print("Preview saved to %s" % output_dir)
	get_tree().quit()


func _shoot(from: Vector3, target: Vector3, path: String) -> void:
	_camera.position = from
	_camera.look_at(target)
	for _frame: int in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
