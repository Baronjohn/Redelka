class_name Ps1BlockModel
extends Node3D

const SNAP: float = 0.05

var _walk_phase: float = 0.0
var _part_base_positions: Dictionary = {}


func build_from_parts(parts: Array[Dictionary]) -> void:
	for child: Node in get_children():
		child.queue_free()
	for part: Dictionary in parts:
		_add_part(part)
	_cache_part_positions()


func _cache_part_positions() -> void:
	_part_base_positions.clear()
	for mesh_instance: MeshInstance3D in get_mesh_instances():
		_part_base_positions[mesh_instance.name] = mesh_instance.position


func update_walk_animation(delta: float, speed_ratio: float) -> void:
	if _part_base_positions.is_empty():
		_cache_part_positions()
	if speed_ratio < 0.05:
		_walk_phase = 0.0
		_reset_walk_pose()
		return
	_walk_phase += delta * 9.0 * speed_ratio
	var leg_swing := sin(_walk_phase) * 0.14 * speed_ratio
	var leg_swing_opposite := sin(_walk_phase + PI) * 0.14 * speed_ratio
	var arm_swing := sin(_walk_phase + PI) * 0.1 * speed_ratio
	var arm_swing_opposite := sin(_walk_phase) * 0.1 * speed_ratio
	var bob := absf(sin(_walk_phase * 2.0)) * 0.025 * speed_ratio
	_offset_part("LegL", Vector3(0.0, bob * 0.3, leg_swing))
	_offset_part("LegR", Vector3(0.0, bob * 0.3, leg_swing_opposite))
	_offset_part("BootL", Vector3(0.0, bob * 0.3, leg_swing))
	_offset_part("BootR", Vector3(0.0, bob * 0.3, leg_swing_opposite))
	_offset_part("ArmL", Vector3(0.0, 0.0, arm_swing))
	_offset_part("ArmR", Vector3(0.0, 0.0, arm_swing_opposite))
	_offset_part("Torso", Vector3(0.0, bob, 0.0))


func _reset_walk_pose() -> void:
	for part_name: String in _part_base_positions.keys():
		_offset_part(part_name, Vector3.ZERO)


func _offset_part(part_name: String, offset: Vector3) -> void:
	if not _part_base_positions.has(part_name):
		return
	var mesh_instance := get_node_or_null(part_name) as MeshInstance3D
	if mesh_instance == null:
		return
	mesh_instance.position = (_part_base_positions[part_name] as Vector3) + offset


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
) -> Dictionary:
	return {"name": part_name, "type": "box", "size": size, "pos": pos, "color": color}
