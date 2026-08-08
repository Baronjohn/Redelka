class_name CharacterMeshUtils
extends RefCounted

## Low-poly humanoid mesh builders in the PS1 style.
## All meshes bake color into vertex colors; use create_base_material()
## (white albedo, vertex_color_use_as_albedo) so colors render unmodified.


static func create_base_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	return material


static func create_state_material(tint: Color, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := create_base_material()
	material.albedo_color = tint
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
	return material


static func shade(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor, 1.0)


## Ring descriptor for lathe surfaces: elliptical cross-section at height y,
## optionally pushed along z (for curved hoods, boots, etc.).
static func ring(y: float, rx: float, rz: float, color: Color, z: float = 0.0) -> Dictionary:
	return {"y": y, "rx": rx, "rz": rz, "z": z, "color": color}


static func make_lathe(rings: Array, sides: int = 10, cap_bottom: bool = true, cap_top: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_lathe(st, rings, sides, Vector3.INF, Vector3.INF, cap_bottom, cap_top)
	st.generate_normals()
	return st.commit()


static func make_sphere(
	radius: float,
	color: Color,
	sphere_scale: Vector3 = Vector3.ONE,
	center: Vector3 = Vector3.ZERO,
	lat_steps: int = 4,
	sides: int = 10,
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_sphere(st, radius, color, sphere_scale, center, lat_steps, sides)
	st.generate_normals()
	return st.commit()


static func make_box(size: Vector3, color: Color, offset: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_box(st, size, color, offset)
	st.generate_normals()
	return st.commit()


static func make_sword(
	blade_length: float,
	blade_width: float,
	blade_color: Color,
	metal_color: Color,
	grip_color: Color,
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_lathe(st, [
		ring(-0.03, 0.015, 0.015, grip_color),
		ring(0.07, 0.013, 0.013, grip_color),
	], 6)
	add_sphere(st, 0.02, metal_color, Vector3.ONE, Vector3(0.0, 0.08, 0.0), 3, 6)
	add_box(st, Vector3(blade_width * 4.2, 0.018, 0.034), metal_color, Vector3(0.0, -0.035, 0.0))
	add_lathe(st, [
		ring(-blade_length, blade_width * 0.55, 0.005, blade_color),
		ring(-0.045, blade_width, 0.008, blade_color),
	], 4, Vector3(0.0, -blade_length - 0.05, 0.0))
	st.generate_normals()
	return st.commit()


static func make_staff(wood_color: Color, orb_color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_lathe(st, [
		ring(-0.52, 0.013, 0.013, shade(wood_color, 0.85)),
		ring(0.56, 0.016, 0.016, wood_color),
	], 6)
	add_sphere(st, 0.042, orb_color, Vector3.ONE, Vector3(0.0, 0.6, 0.0), 4, 8)
	st.generate_normals()
	return st.commit()


static func make_book(size: Vector3, cover_color: Color, page_color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_box(st, size, cover_color)
	add_box(st, Vector3(size.x * 0.9, size.y * 0.7, size.z * 0.9), page_color, Vector3(size.x * 0.08, 0.0, 0.0))
	st.generate_normals()
	return st.commit()


## Bow as a two-sided ribbon arc in the local YZ plane plus a straight string.
static func make_bow(
	radius: float,
	half_angle_deg: float,
	wood_color: Color,
	string_color: Color,
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 8
	var half_width := 0.011
	var half_angle := deg_to_rad(half_angle_deg)
	var previous_top := Vector3.ZERO
	var previous_bottom := Vector3.ZERO
	for step_index: int in steps + 1:
		var t := -half_angle + 2.0 * half_angle * float(step_index) / float(steps)
		var point := Vector3(0.0, radius * sin(t), radius * cos(t) - radius)
		var top := point + Vector3(half_width, 0.0, 0.0)
		var bottom := point + Vector3(-half_width, 0.0, 0.0)
		if step_index > 0:
			_quad_two_sided(st, previous_bottom, previous_top, top, bottom, wood_color)
		previous_top = top
		previous_bottom = bottom
	var tip_z := radius * cos(half_angle) - radius
	var tip_y := radius * sin(half_angle)
	_quad_two_sided(
		st,
		Vector3(-0.003, -tip_y, tip_z),
		Vector3(0.003, -tip_y, tip_z),
		Vector3(0.003, tip_y, tip_z),
		Vector3(-0.003, tip_y, tip_z),
		string_color,
	)
	st.generate_normals()
	return st.commit()


static func add_lathe(
	st: SurfaceTool,
	rings: Array,
	sides: int,
	bottom_point: Vector3 = Vector3.INF,
	top_point: Vector3 = Vector3.INF,
	cap_bottom: bool = true,
	cap_top: bool = true,
) -> void:
	if rings.size() < 2:
		return
	var ring_points: Array = []
	for ring_variant: Variant in rings:
		var ring_data: Dictionary = ring_variant as Dictionary
		var points: Array[Vector3] = []
		for side_index: int in sides:
			var angle := TAU * float(side_index) / float(sides)
			points.append(Vector3(
				cos(angle) * float(ring_data["rx"]),
				float(ring_data["y"]),
				sin(angle) * float(ring_data["rz"]) + float(ring_data.get("z", 0.0)),
			))
		ring_points.append(points)

	for ring_index: int in rings.size() - 1:
		var lower: Array[Vector3] = ring_points[ring_index]
		var upper: Array[Vector3] = ring_points[ring_index + 1]
		var lower_color: Color = (rings[ring_index] as Dictionary)["color"]
		var upper_color: Color = (rings[ring_index + 1] as Dictionary)["color"]
		for side_index: int in sides:
			var next_index := (side_index + 1) % sides
			_tri(st, lower[side_index], lower[next_index], upper[next_index], lower_color, lower_color, upper_color)
			_tri(st, lower[side_index], upper[next_index], upper[side_index], lower_color, upper_color, upper_color)

	if cap_bottom:
		var first_ring: Dictionary = rings[0] as Dictionary
		var first_points: Array[Vector3] = ring_points[0]
		var bottom_center := bottom_point
		if bottom_center == Vector3.INF:
			bottom_center = Vector3(0.0, float(first_ring["y"]), float(first_ring.get("z", 0.0)))
		var bottom_color: Color = first_ring["color"]
		for side_index: int in sides:
			var next_index := (side_index + 1) % sides
			_tri(st, first_points[next_index], first_points[side_index], bottom_center, bottom_color, bottom_color, bottom_color)

	if cap_top:
		var last_ring: Dictionary = rings[rings.size() - 1] as Dictionary
		var last_points: Array[Vector3] = ring_points[ring_points.size() - 1]
		var top_center := top_point
		if top_center == Vector3.INF:
			top_center = Vector3(0.0, float(last_ring["y"]), float(last_ring.get("z", 0.0)))
		var top_color: Color = last_ring["color"]
		for side_index: int in sides:
			var next_index := (side_index + 1) % sides
			_tri(st, last_points[side_index], last_points[next_index], top_center, top_color, top_color, top_color)


static func add_sphere(
	st: SurfaceTool,
	radius: float,
	color: Color,
	sphere_scale: Vector3,
	center: Vector3,
	lat_steps: int = 4,
	sides: int = 10,
) -> void:
	var rings: Array = []
	for step_index: int in range(1, lat_steps):
		var lat := -PI * 0.5 + PI * float(step_index) / float(lat_steps)
		rings.append(ring(
			center.y + radius * sphere_scale.y * sin(lat),
			radius * sphere_scale.x * cos(lat),
			radius * sphere_scale.z * cos(lat),
			color,
			center.z,
		))
	add_lathe(
		st,
		rings,
		sides,
		Vector3(0.0, center.y - radius * sphere_scale.y, center.z),
		Vector3(0.0, center.y + radius * sphere_scale.y, center.z),
	)


static func add_box(st: SurfaceTool, size: Vector3, color: Color, offset: Vector3 = Vector3.ZERO) -> void:
	var half := size * 0.5
	var fbl := offset + Vector3(-half.x, -half.y, half.z)
	var fbr := offset + Vector3(half.x, -half.y, half.z)
	var ftr := offset + Vector3(half.x, half.y, half.z)
	var ftl := offset + Vector3(-half.x, half.y, half.z)
	var bbl := offset + Vector3(-half.x, -half.y, -half.z)
	var bbr := offset + Vector3(half.x, -half.y, -half.z)
	var btr := offset + Vector3(half.x, half.y, -half.z)
	var btl := offset + Vector3(-half.x, half.y, -half.z)
	_quad(st, fbl, fbr, ftr, ftl, color)
	_quad(st, bbr, bbl, btl, btr, color)
	_quad(st, bbl, fbl, ftl, btl, color)
	_quad(st, fbr, bbr, btr, ftr, color)
	_quad(st, ftl, ftr, btr, btl, color)
	_quad(st, bbl, bbr, fbr, fbl, color)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(st, a, b, c, color, color, color)
	_tri(st, a, c, d, color, color, color)


static func _quad_two_sided(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_quad(st, a, b, c, d, color)
	_quad(st, d, c, b, a, color)


static func _tri(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color_a: Color,
	color_b: Color,
	color_c: Color,
) -> void:
	st.set_color(color_a)
	st.set_uv(Vector2.ZERO)
	st.add_vertex(a)
	st.set_color(color_b)
	st.set_uv(Vector2.ZERO)
	st.add_vertex(b)
	st.set_color(color_c)
	st.set_uv(Vector2.ZERO)
	st.add_vertex(c)
