extends Node

signal global_illumination_changed(value: float)
signal battle_speed_changed(value: float)

var global_illumination: float = 1.0
var battle_speed: float = 1.0
var explore_sky_color: Color = Color.BLACK
var battle_shadows_enabled: bool = false

var _scene_base_ambient: Dictionary = {}
var _scene_base_directional: Dictionary = {}


func _ready() -> void:
	load_defaults()


func load_defaults() -> void:
	var data := DataLoader.load_debug()
	global_illumination = float(data.get("global_illumination", 1.0))
	battle_speed = float(data.get("battle_speed", 1.0))
	explore_sky_color = _color_from_array(data.get("explore_sky_color", [0.0, 0.0, 0.0]))
	battle_shadows_enabled = bool(data.get("battle_shadows_enabled", false))


func set_battle_speed(value: float) -> void:
	battle_speed = clampf(value, 0.25, 4.0)
	battle_speed_changed.emit(battle_speed)


func scale_battle_duration(seconds: float) -> float:
	return seconds / clampf(battle_speed, 0.25, 4.0)


func set_global_illumination(value: float) -> void:
	global_illumination = clampf(value, 0.0, 2.0)
	global_illumination_changed.emit(global_illumination)
	apply_to_current_scene()


func apply_explore_lighting(root: Node3D) -> void:
	_apply_scene_lighting(root, true)


func apply_battle_lighting(root: Node3D) -> void:
	_apply_scene_lighting(root, false)


func apply_to_current_scene() -> void:
	var root := get_tree().current_scene as Node3D
	if root == null:
		return
	var explore_mode := root.get_node_or_null("Room") != null
	_apply_scene_lighting(root, explore_mode)


func _apply_scene_lighting(root: Node3D, explore_mode: bool) -> void:
	var scene_key := root.scene_file_path
	if scene_key.is_empty():
		scene_key = root.name
	var world_env := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env != null and world_env.environment != null:
		var env := world_env.environment
		if not _scene_base_ambient.has(scene_key):
			_scene_base_ambient[scene_key] = env.ambient_light_energy
		env.ambient_light_energy = float(_scene_base_ambient[scene_key]) * global_illumination
		if explore_mode:
			env.background_mode = Environment.BG_COLOR
			env.background_color = explore_sky_color
		else:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color.BLACK
	var light := root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light != null:
		if not _scene_base_directional.has(scene_key):
			_scene_base_directional[scene_key] = light.light_energy if light.light_energy > 0.0 else 1.0
		light.light_energy = float(_scene_base_directional[scene_key]) * global_illumination
		if explore_mode:
			light.shadow_enabled = true
		else:
			light.shadow_enabled = battle_shadows_enabled


static func _color_from_array(value: Variant) -> Color:
	if value is Array and (value as Array).size() >= 3:
		var array := value as Array
		return Color(float(array[0]), float(array[1]), float(array[2]))
	return Color.BLACK
