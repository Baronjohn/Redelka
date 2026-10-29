class_name CharacterModel
extends Node3D

## Wraps a Blender-generated character .glb (see tools/generate_models.py):
## plays its baked clips (idle, walk, attack, chant, chant_release) and swaps
## materials for the battle highlight and KO states.

const LOOPING_CLIPS: Array[String] = ["idle", "walk", "chant"]
const GLOW_MATERIAL_NAME: String = "Glow"
const KO_TINT: Color = Color(0.35, 0.35, 0.38)

@export var model_scene: PackedScene

var _animation_player: AnimationPlayer = null
var _mesh_instances: Array[MeshInstance3D] = []
var _glow_instances: Array[MeshInstance3D] = []
var _atlas: Texture2D = null
var _glow_color: Color = Color(0.6, 0.4, 0.9)
var _is_chanting: bool = false
var _action_playing: bool = false


func _ready() -> void:
	if model_scene == null:
		push_warning("CharacterModel '%s' has no model_scene" % name)
		return
	var model := model_scene.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		_mesh_instances.append(node as MeshInstance3D)
	_read_imported_materials()
	reset_materials()
	_animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_player == null:
		return
	for clip_name: String in LOOPING_CLIPS:
		if _animation_player.has_animation(clip_name):
			_animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	_animation_player.play("idle")


func update_animation(_delta: float, speed_ratio: float) -> void:
	if _animation_player == null or _action_playing or _is_chanting:
		return
	if speed_ratio >= 0.05:
		if _animation_player.current_animation != "walk":
			_animation_player.play("walk", 0.15)
		_animation_player.speed_scale = clampf(speed_ratio, 0.4, 1.4)
	elif _animation_player.current_animation != "idle":
		_animation_player.play("idle", 0.2)
		_animation_player.speed_scale = 1.0


func update_walk_animation(delta: float, speed_ratio: float) -> void:
	update_animation(delta, speed_ratio)


func is_action_playing() -> bool:
	return _action_playing


func is_chanting() -> bool:
	return _is_chanting


func set_chanting(enabled: bool) -> void:
	_is_chanting = enabled
	if _animation_player == null:
		return
	if enabled:
		_action_playing = false
		_animation_player.speed_scale = 1.0
		_animation_player.play("chant", 0.2)
	elif _animation_player.current_animation == "chant":
		_animation_player.play("idle", 0.2)


func play_attack() -> void:
	await _play_action("attack", 0.5)
	if _animation_player == null:
		return
	_animation_player.play("chant" if _is_chanting else "idle", 0.15)


func play_chant_release() -> void:
	_is_chanting = false
	await _play_action("chant_release", 0.4)
	if _animation_player != null:
		_animation_player.play("idle", 0.15)


func get_mesh_instances() -> Array[MeshInstance3D]:
	return _mesh_instances


func get_ground_y_offset() -> float:
	return CombatConstants.TILE_FLOOR_Y


func get_model_top_y() -> float:
	var top := 0.0
	for mesh_instance: MeshInstance3D in _mesh_instances:
		if mesh_instance.mesh == null:
			continue
		var to_self := _transform_to_self(mesh_instance)
		var aabb := to_self * mesh_instance.mesh.get_aabb()
		top = maxf(top, aabb.end.y)
	return top * scale.y


func apply_tint(base_tint: Color, emission: Color = Color.BLACK) -> void:
	_apply_body_material(_make_body_material(base_tint, emission))


func reset_materials() -> void:
	_apply_body_material(_make_body_material(Color.WHITE))


func apply_ko_darken() -> void:
	_apply_body_material(_make_body_material(KO_TINT))


func _play_action(clip_name: String, fallback_length: float) -> void:
	if _animation_player == null or not _animation_player.has_animation(clip_name):
		return
	_action_playing = true
	_animation_player.speed_scale = 1.0
	_animation_player.play(clip_name)
	var clip := _animation_player.get_animation(clip_name)
	var duration := clip.length if clip != null else fallback_length
	await get_tree().create_timer(DebugSettings.scale_battle_duration(duration)).timeout
	_action_playing = false


## The generator exports one mesh per material: the textured body and, where a
## model has glowing eyes or orbs, a separate mesh using the "Glow" material.
func _read_imported_materials() -> void:
	for mesh_instance: MeshInstance3D in _mesh_instances:
		if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
			continue
		var imported := mesh_instance.mesh.surface_get_material(0) as BaseMaterial3D
		if imported == null:
			continue
		if imported.resource_name == GLOW_MATERIAL_NAME:
			_glow_instances.append(mesh_instance)
			_glow_color = imported.emission if imported.emission_enabled else imported.albedo_color
		elif _atlas == null:
			_atlas = imported.albedo_texture


func _make_body_material(tint: Color, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = tint
	material.albedo_texture = _atlas
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
	return material


func _make_glow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _glow_color
	return material


func _apply_body_material(body: StandardMaterial3D) -> void:
	var glow := _make_glow_material()
	for mesh_instance: MeshInstance3D in _mesh_instances:
		mesh_instance.material_override = glow if _glow_instances.has(mesh_instance) else body


func _transform_to_self(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != self:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
