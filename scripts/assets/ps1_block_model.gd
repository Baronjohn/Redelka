class_name Ps1BlockModel
extends Node3D

enum AnimState {
	IDLE,
	WALK,
	ATTACK,
	CHANT,
}

const SNAP: float = 0.05

var attack_style: String = "melee"

var _anim_state: AnimState = AnimState.IDLE
var _walk_phase: float = 0.0
var _idle_phase: float = 0.0
var _chant_phase: float = 0.0
var _is_chanting: bool = false
var _action_tween: Tween = null
var _part_base_positions: Dictionary = {}
var _part_base_rotations: Dictionary = {}


func build_from_parts(parts: Array[Dictionary]) -> void:
	for child: Node in get_children():
		child.queue_free()
	for part: Dictionary in parts:
		_add_part(part)
	_cache_part_transforms()


func is_action_playing() -> bool:
	if _anim_state == AnimState.ATTACK:
		return true
	return _action_tween != null and _action_tween.is_valid() and _action_tween.is_running()


func is_chanting() -> bool:
	return _is_chanting


func set_chanting(enabled: bool) -> void:
	_is_chanting = enabled
	if enabled:
		_anim_state = AnimState.CHANT
		_chant_phase = 0.0
	elif _anim_state == AnimState.CHANT:
		_anim_state = AnimState.IDLE
		_reset_pose()


func update_walk_animation(delta: float, speed_ratio: float) -> void:
	update_animation(delta, speed_ratio)


func update_animation(delta: float, speed_ratio: float) -> void:
	if _part_base_positions.is_empty():
		_cache_part_transforms()
	if is_action_playing():
		return
	if _is_chanting:
		_apply_chant_pose(delta)
		return
	if speed_ratio >= 0.05:
		_anim_state = AnimState.WALK
		_apply_walk_pose(delta, speed_ratio)
	else:
		_anim_state = AnimState.IDLE
		_apply_idle_pose(delta)


func play_attack() -> void:
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_anim_state = AnimState.ATTACK
	_reset_pose()
	_action_tween = create_tween()
	var duration := 0.22
	_action_tween.tween_method(_apply_attack_pose, 0.0, 1.0, duration * 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_method(_apply_attack_pose, 1.0, 0.0, duration * 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _action_tween.finished
	_action_tween = null
	_anim_state = AnimState.IDLE
	_reset_pose()


func play_chant_release() -> void:
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_anim_state = AnimState.ATTACK
	_action_tween = create_tween()
	_action_tween.tween_method(_apply_chant_release_pose, 0.0, 1.0, 0.16)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_action_tween.tween_method(_apply_chant_release_pose, 1.0, 0.0, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _action_tween.finished
	_action_tween = null
	_is_chanting = false
	_anim_state = AnimState.IDLE
	_reset_pose()


func _cache_part_transforms() -> void:
	_part_base_positions.clear()
	_part_base_rotations.clear()
	for mesh_instance: MeshInstance3D in get_mesh_instances():
		_part_base_positions[mesh_instance.name] = mesh_instance.position
		_part_base_rotations[mesh_instance.name] = mesh_instance.rotation


func _apply_idle_pose(delta: float) -> void:
	_idle_phase += delta * 1.6
	var breathe := sin(_idle_phase) * 0.012
	var sway := sin(_idle_phase * 0.7) * 0.008
	_reset_pose()
	_offset_part("Torso", Vector3(0.0, breathe, 0.0))
	_offset_part("CoatFlap", Vector3(0.0, breathe * 0.5, sway))
	_offset_part("Scarf", Vector3(sway * 0.4, breathe, sway * 0.2))
	_offset_part("ArmL", Vector3(0.0, breathe * 0.4, sway * 0.5))
	_offset_part("ArmR", Vector3(0.0, breathe * 0.4, -sway * 0.5))
	_offset_part("Head", Vector3(0.0, breathe * 0.8, 0.0))
	_offset_part("HoodTop", Vector3(0.0, breathe * 0.6, sway * 0.15))
	_offset_part("HoodPeak", Vector3(0.0, breathe * 0.5, sway * 0.1))
	_offset_part("Weapon", Vector3(0.0, breathe * 0.3, sway * 0.1))
	_offset_part("Book", Vector3(0.0, breathe * 0.35, -sway * 0.08))
	_offset_part("Staff", Vector3(0.0, breathe * 0.25, 0.0))


func _apply_walk_pose(delta: float, speed_ratio: float) -> void:
	_walk_phase += delta * 9.0 * speed_ratio
	var leg_swing := sin(_walk_phase) * 0.16 * speed_ratio
	var leg_swing_opposite := sin(_walk_phase + PI) * 0.16 * speed_ratio
	var arm_swing := sin(_walk_phase + PI) * 0.12 * speed_ratio
	var arm_swing_opposite := sin(_walk_phase) * 0.12 * speed_ratio
	var bob := absf(sin(_walk_phase * 2.0)) * 0.03 * speed_ratio
	_reset_pose()
	for leg_name: String in ["LegL", "ShinL", "FootL", "BootL"]:
		_offset_part(leg_name, Vector3(0.0, bob * 0.25, leg_swing))
	for leg_name: String in ["LegR", "ShinR", "FootR", "BootR"]:
		_offset_part(leg_name, Vector3(0.0, bob * 0.25, leg_swing_opposite))
	_offset_part("ArmL", Vector3(0.0, bob * 0.15, arm_swing))
	_offset_part("ArmR", Vector3(0.0, bob * 0.15, arm_swing_opposite))
	_offset_part("HandL", Vector3(0.0, 0.0, arm_swing * 0.5))
	_offset_part("HandR", Vector3(0.0, 0.0, arm_swing_opposite * 0.5))
	_offset_part("Torso", Vector3(0.0, bob, 0.0))
	_offset_part("Head", Vector3(0.0, bob * 0.8, 0.0))
	_offset_part("CoatFlap", Vector3(0.0, bob * 0.4, leg_swing_opposite * 0.08))
	_offset_part("Scarf", Vector3(leg_swing * 0.04, bob * 0.3, leg_swing * 0.06))
	_offset_part("Satchel", Vector3(0.0, bob * 0.2, -leg_swing * 0.05))
	_offset_part("Skirt", Vector3(0.0, bob * 0.2, leg_swing_opposite * 0.05))
	_offset_part("Weapon", Vector3(0.0, bob * 0.2, arm_swing_opposite * 0.04))
	_offset_part("Bow", Vector3(0.0, bob * 0.15, 0.0))
	_offset_part("Quiver", Vector3(0.0, bob * 0.1, -leg_swing * 0.03))
	_offset_part("Staff", Vector3(0.0, bob * 0.15, 0.0))
	_offset_part("Book", Vector3(0.0, bob * 0.2, 0.0))


func _apply_attack_pose(progress: float) -> void:
	var t := sin(progress * PI)
	_reset_pose()
	match attack_style:
		"dagger":
			_apply_dagger_attack_pose(t)
		"bow":
			_apply_bow_attack_pose(t)
		"staff":
			_apply_staff_attack_pose(t)
		_:
			_apply_melee_attack_pose(t)


func _apply_melee_attack_pose(t: float) -> void:
	_offset_part("Torso", Vector3(0.0, 0.02 * t, 0.1 * t), Vector3(-0.08 * t, 0.0, 0.0))
	_offset_part("ArmR", Vector3(0.06 * t, 0.08 * t, -0.16 * t), Vector3(-1.0 * t, 0.0, 0.35 * t))
	_offset_part("HandR", Vector3(0.08 * t, 0.04 * t, -0.2 * t), Vector3(-0.8 * t, 0.0, 0.2 * t))
	_offset_part("ArmL", Vector3(-0.04 * t, 0.0, 0.06 * t), Vector3(0.15 * t, 0.0, -0.1 * t))
	_offset_part("LegL", Vector3(0.0, 0.0, 0.08 * t))
	_offset_part("LegR", Vector3(0.0, 0.0, -0.06 * t))
	_offset_part("Weapon", Vector3(0.1 * t, 0.06 * t, -0.24 * t), Vector3(-1.1 * t, 0.15 * t, 0.4 * t))
	_offset_part("SwordBlade", Vector3(0.14 * t, 0.08 * t, -0.28 * t), Vector3(-1.1 * t, 0.15 * t, 0.4 * t))
	_offset_part("Head", Vector3(0.0, 0.0, 0.02 * t), Vector3(-0.06 * t, 0.0, 0.0))


func _apply_dagger_attack_pose(t: float) -> void:
	_offset_part("Torso", Vector3(0.04 * t, 0.01 * t, 0.08 * t), Vector3(0.0, 0.12 * t, 0.0))
	_offset_part("ArmR", Vector3(0.1 * t, 0.04 * t, -0.12 * t), Vector3(-0.7 * t, -0.25 * t, 0.5 * t))
	_offset_part("HandR", Vector3(0.12 * t, 0.0, -0.14 * t), Vector3(-0.5 * t, -0.2 * t, 0.45 * t))
	_offset_part("ArmL", Vector3(-0.08 * t, 0.02 * t, 0.04 * t), Vector3(0.25 * t, -0.15 * t, -0.2 * t))
	_offset_part("Weapon", Vector3(0.12 * t, 0.0, -0.16 * t), Vector3(-0.6 * t, -0.2 * t, 0.5 * t))
	_offset_part("DaggerBlade", Vector3(0.14 * t, 0.0, -0.18 * t), Vector3(-0.6 * t, -0.2 * t, 0.5 * t))
	_offset_part("LegL", Vector3(0.0, 0.0, 0.1 * t))
	_offset_part("LegR", Vector3(0.0, 0.0, -0.08 * t))


func _apply_bow_attack_pose(t: float) -> void:
	_offset_part("Torso", Vector3(0.0, 0.0, -0.04 * t), Vector3(0.05 * t, -0.08 * t, 0.0))
	_offset_part("ArmL", Vector3(-0.06 * t, 0.06 * t, 0.08 * t), Vector3(-0.35 * t, 0.0, 0.45 * t))
	_offset_part("ArmR", Vector3(0.08 * t, 0.04 * t, -0.1 * t), Vector3(-0.55 * t, 0.0, -0.35 * t))
	_offset_part("HandL", Vector3(-0.08 * t, 0.08 * t, 0.1 * t))
	_offset_part("HandR", Vector3(0.1 * t, 0.02 * t, -0.12 * t), Vector3(-0.45 * t, 0.0, -0.25 * t))
	_offset_part("Bow", Vector3(-0.04 * t, 0.06 * t, 0.06 * t), Vector3(0.0, 0.0, 0.25 * t))
	_offset_part("BowString", Vector3(0.02 * t, 0.05 * t, -0.02 * t))
	_offset_part("Head", Vector3(0.0, 0.0, 0.0), Vector3(0.04 * t, -0.06 * t, 0.0))


func _apply_staff_attack_pose(t: float) -> void:
	_offset_part("Torso", Vector3(0.0, 0.02 * t, 0.06 * t), Vector3(-0.06 * t, 0.0, 0.0))
	_offset_part("ArmR", Vector3(0.04 * t, 0.1 * t, -0.08 * t), Vector3(-0.9 * t, 0.0, 0.2 * t))
	_offset_part("Staff", Vector3(0.08 * t, 0.14 * t, -0.18 * t), Vector3(-0.95 * t, 0.0, 0.25 * t))
	_offset_part("StaffTop", Vector3(0.1 * t, 0.22 * t, -0.2 * t), Vector3(-0.95 * t, 0.0, 0.25 * t))
	_offset_part("ArmL", Vector3(-0.05 * t, 0.04 * t, 0.02 * t), Vector3(0.2 * t, 0.0, 0.0))
	_offset_part("Book", Vector3(0.16 * t, 0.06 * t, 0.04 * t))


func _apply_chant_pose(delta: float) -> void:
	_chant_phase += delta * 2.4
	var sway := sin(_chant_phase) * 0.025
	var lift := 0.08 + sin(_chant_phase * 2.0) * 0.012
	_reset_pose()
	_offset_part("Torso", Vector3(0.0, sway, 0.0))
	_offset_part("Head", Vector3(0.0, sway * 0.5, 0.0), Vector3(-0.08, 0.0, 0.0))
	_offset_part("ArmL", Vector3(-0.06, lift, 0.04), Vector3(-0.75, 0.15, 0.1))
	_offset_part("ArmR", Vector3(0.06, lift, 0.04), Vector3(-0.75, -0.15, -0.1))
	_offset_part("HandL", Vector3(-0.06, lift - 0.08, 0.05))
	_offset_part("HandR", Vector3(0.06, lift - 0.08, 0.05))
	_offset_part("Book", Vector3(0.08, lift - 0.02, 0.1), Vector3(-0.35, 0.0, 0.0))
	_offset_part("Staff", Vector3(-0.04, 0.02, -0.02))
	_offset_part("StaffTop", Vector3(-0.04, 0.18, -0.02))
	_offset_part("Hood", Vector3(0.0, sway * 0.4, 0.0))
	_offset_part("HoodPeak", Vector3(0.0, sway * 0.5, 0.0))
	_offset_part("Weapon", Vector3(0.0, lift * 0.2, 0.0))
	_set_part_emission(["Book", "StaffTop"], Color(0.35, 0.22, 0.55), 0.12 + absf(sin(_chant_phase * 2.5)) * 0.18)


func _apply_chant_release_pose(progress: float) -> void:
	var t := sin(progress * PI)
	_reset_pose()
	_offset_part("Torso", Vector3(0.0, 0.03 * t, 0.0), Vector3(-0.12 * t, 0.0, 0.0))
	_offset_part("ArmL", Vector3(-0.1 * t, 0.16 * t, 0.06 * t), Vector3(-1.0 * t, 0.25 * t, 0.0))
	_offset_part("ArmR", Vector3(0.1 * t, 0.16 * t, 0.06 * t), Vector3(-1.0 * t, -0.25 * t, 0.0))
	_offset_part("Book", Vector3(0.04 * t, 0.12 * t, 0.14 * t), Vector3(-0.5 * t, 0.0, 0.0))
	_offset_part("StaffTop", Vector3(-0.02 * t, 0.24 * t, 0.02 * t))
	_offset_part("Head", Vector3(0.0, 0.02 * t, 0.0), Vector3(-0.15 * t, 0.0, 0.0))
	_set_part_emission(["Book", "StaffTop"], Color(0.65, 0.45, 0.95), 0.35 * t)


func _reset_pose() -> void:
	for part_name: String in _part_base_positions.keys():
		_offset_part(part_name, Vector3.ZERO, Vector3.ZERO)
	_clear_part_emission()


func _offset_part(part_name: String, pos_offset: Vector3, rot_offset: Vector3 = Vector3.ZERO) -> void:
	if not _part_base_positions.has(part_name):
		return
	var mesh_instance := get_node_or_null(part_name) as MeshInstance3D
	if mesh_instance == null:
		return
	mesh_instance.position = (_part_base_positions[part_name] as Vector3) + pos_offset
	mesh_instance.rotation = (_part_base_rotations.get(part_name, Vector3.ZERO) as Vector3) + rot_offset


func _set_part_emission(part_names: Array[String], color: Color, strength: float) -> void:
	for part_name: String in part_names:
		var mesh_instance := get_node_or_null(part_name) as MeshInstance3D
		if mesh_instance == null:
			continue
		var source := mesh_instance.get_meta("base_color", Color.WHITE) as Color
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		material.albedo_color = source
		material.emission_enabled = strength > 0.01
		material.emission = color * strength
		mesh_instance.material_override = material


func _clear_part_emission() -> void:
	for mesh_instance: MeshInstance3D in get_mesh_instances():
		if mesh_instance.material_override == null:
			continue
		var source := mesh_instance.get_meta("base_color", Color.WHITE) as Color
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		material.albedo_color = source
		mesh_instance.material_override = material


func get_mesh_instances() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, meshes)
	return meshes


func apply_tint(base_tint: Color, emission: Color = Color.BLACK) -> void:
	for mesh_instance: MeshInstance3D in get_mesh_instances():
		var source := mesh_instance.get_meta("base_color", Color.WHITE) as Color
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		material.albedo_color = source.lerp(base_tint, 0.18)
		if emission != Color.BLACK:
			material.emission_enabled = true
			material.emission = emission
		mesh_instance.material_override = material


func reset_materials() -> void:
	_clear_part_emission()
	for mesh_instance: MeshInstance3D in get_mesh_instances():
		var source := mesh_instance.get_meta("base_color", Color.WHITE) as Color
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		material.albedo_color = source
		mesh_instance.material_override = material


func apply_ko_darken() -> void:
	for mesh_instance: MeshInstance3D in get_mesh_instances():
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		var base := mesh_instance.get_meta("base_color", Color.WHITE) as Color
		material.albedo_color = base.darkened(0.55)
		mesh_instance.material_override = material


static func _collect_mesh_instances(node: Node, meshes: Array[MeshInstance3D]) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)
		_collect_mesh_instances(child, meshes)


func _add_part(part: Dictionary) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = str(part.get("name", "Part"))
	var size: Vector3 = _snap_vec(part.get("size", Vector3.ONE) as Vector3)
	var part_pos: Vector3 = _snap_vec(part.get("pos", Vector3.ZERO) as Vector3)
	mesh_instance.position = part_pos
	var part_rot: Vector3 = part.get("rot", Vector3.ZERO) as Vector3
	mesh_instance.rotation = part_rot
	var mesh_type := str(part.get("type", "box"))
	if mesh_type == "cylinder":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		mesh_instance.mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
	var color: Color = part.get("color", Color.WHITE) as Color
	mesh_instance.set_meta("base_color", color)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.albedo_color = color
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh_instance.material_override = material
	add_child(mesh_instance)


static func _snap(value: float) -> float:
	return snappedf(value, SNAP)


static func _snap_vec(value: Vector3) -> Vector3:
	return Vector3(_snap(value.x), _snap(value.y), _snap(value.z))


static func _box(
	part_name: String,
	size: Vector3,
	pos: Vector3,
	color: Color,
	rot: Vector3 = Vector3.ZERO,
) -> Dictionary:
	return {"name": part_name, "type": "box", "size": size, "pos": pos, "color": color, "rot": rot}
