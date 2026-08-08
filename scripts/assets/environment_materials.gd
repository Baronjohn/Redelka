class_name EnvironmentMaterials
extends RefCounted

enum Pattern {
	STONE,
	COBBLE,
	PLASTER,
	WOOD_PLANK,
	WOOD_GRAIN,
	BRICK,
	DIRT,
}

class AreaTheme:
	var floor_pattern: Pattern = Pattern.STONE
	var floor_tint: Color = Color(0.32, 0.34, 0.38)
	var floor_uv: Vector3 = Vector3(4.0, 1.0, 4.0)
	var wall_pattern: Pattern = Pattern.PLASTER
	var wall_tint: Color = Color(0.24, 0.26, 0.3)
	var wall_uv: Vector3 = Vector3(3.0, 1.5, 1.0)
	var door_tint: Color = Color(0.45, 0.32, 0.22)


static func apply_explore_room(room: Node3D, area_id: String) -> void:
	var theme := get_area_theme(area_id)
	var floor_mesh := room.get_node_or_null("Floor/FloorMesh") as MeshInstance3D
	if floor_mesh != null:
		floor_mesh.material_override = create_surface_material(
			theme.floor_pattern, theme.floor_tint, theme.floor_uv
		)
	for child: Node in room.get_children():
		if not str(child.name).begins_with("Wall"):
			continue
		var wall_mesh := child.get_node_or_null("WallMesh") as MeshInstance3D
		if wall_mesh != null:
			wall_mesh.material_override = create_surface_material(
				theme.wall_pattern, theme.wall_tint, theme.wall_uv
			)


static func apply_explore_doors(doors_root: Node3D, area_id: String) -> void:
	var theme := get_area_theme(area_id)
	for door: Node in doors_root.get_children():
		var door_mesh := door.get_node_or_null("Panel/DoorMesh") as MeshInstance3D
		if door_mesh == null:
			continue
		door_mesh.material_override = create_surface_material(
			Pattern.WOOD_GRAIN, theme.door_tint, Vector3(1.0, 2.0, 1.0)
		)


static func apply_explore_checkpoint(checkpoint: Node3D, area_id: String) -> void:
	var theme := get_area_theme(area_id)
	var marker := checkpoint.get_node_or_null("CheckpointMarker") as MeshInstance3D
	if marker == null:
		return
	marker.material_override = create_surface_material(
		Pattern.STONE, theme.floor_tint.lightened(0.08), Vector3(1.0, 1.0, 1.0)
	)


static func create_pickup_material() -> StandardMaterial3D:
	var material := create_surface_material(
		Pattern.WOOD_GRAIN, Color(0.78, 0.66, 0.28), Vector3(1.0, 1.0, 1.0)
	)
	material.emission_enabled = true
	material.emission = Color(0.95, 0.82, 0.28)
	material.emission_energy_multiplier = 0.35
	return material


static func create_closet_material() -> StandardMaterial3D:
	return create_surface_material(
		Pattern.WOOD_GRAIN, Color(0.38, 0.3, 0.22), Vector3(1.0, 2.0, 1.0)
	)


static func get_area_theme(area_id: String) -> AreaTheme:
	var theme := AreaTheme.new()
	match area_id:
		"village_square":
			theme.floor_pattern = Pattern.COBBLE
			theme.floor_tint = Color(0.34, 0.31, 0.28)
			theme.floor_uv = Vector3(5.0, 1.0, 5.0)
			theme.wall_pattern = Pattern.STONE
			theme.wall_tint = Color(0.26, 0.24, 0.22)
			theme.door_tint = Color(0.42, 0.3, 0.2)
		"adjacent_room":
			theme.floor_pattern = Pattern.STONE
			theme.floor_tint = Color(0.3, 0.34, 0.3)
			theme.wall_pattern = Pattern.PLASTER
			theme.wall_tint = Color(0.22, 0.26, 0.22)
			theme.door_tint = Color(0.4, 0.3, 0.2)
		"old_chapel":
			theme.floor_pattern = Pattern.STONE
			theme.floor_tint = Color(0.3, 0.28, 0.34)
			theme.wall_pattern = Pattern.BRICK
			theme.wall_tint = Color(0.2, 0.18, 0.24)
			theme.wall_uv = Vector3(2.0, 2.0, 1.0)
			theme.door_tint = Color(0.34, 0.24, 0.18)
		"root_cellar":
			theme.floor_pattern = Pattern.DIRT
			theme.floor_tint = Color(0.18, 0.15, 0.12)
			theme.wall_pattern = Pattern.BRICK
			theme.wall_tint = Color(0.12, 0.1, 0.1)
			theme.wall_uv = Vector3(2.5, 2.0, 1.0)
			theme.door_tint = Color(0.22, 0.16, 0.12)
		"weavers_cottage":
			theme.floor_pattern = Pattern.WOOD_PLANK
			theme.floor_tint = Color(0.34, 0.27, 0.2)
			theme.floor_uv = Vector3(6.0, 1.0, 4.0)
			theme.wall_pattern = Pattern.WOOD_PLANK
			theme.wall_tint = Color(0.26, 0.2, 0.15)
			theme.wall_uv = Vector3(3.0, 2.0, 1.0)
			theme.door_tint = Color(0.4, 0.3, 0.22)
		"granary":
			theme.floor_pattern = Pattern.WOOD_PLANK
			theme.floor_tint = Color(0.34, 0.27, 0.2)
			theme.floor_uv = Vector3(6.0, 1.0, 4.0)
			theme.wall_pattern = Pattern.WOOD_PLANK
			theme.wall_tint = Color(0.26, 0.2, 0.15)
			theme.wall_uv = Vector3(3.0, 2.0, 1.0)
			theme.door_tint = Color(0.4, 0.3, 0.22)
		_:
			pass
	return theme


static func create_surface_material(
	pattern: Pattern,
	tint: Color,
	uv_scale: Vector3,
) -> StandardMaterial3D:
	var texture_path := _pattern_asset_path(pattern)
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		return create_textured_material(load(texture_path) as Texture2D, tint, uv_scale)
	return create_textured_material(_generate_pattern_texture(pattern), tint, uv_scale)


static func create_textured_material(
	texture: Texture2D,
	tint: Color,
	uv_scale: Vector3,
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.uv1_scale = uv_scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.94
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


static func _generate_pattern_texture(pattern: Pattern) -> ImageTexture:
	var image := _generate_pattern_image(pattern)
	var texture := ImageTexture.create_from_image(image)
	return texture


static func _generate_pattern_image(pattern: Pattern) -> Image:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	match pattern:
		Pattern.STONE:
			_fill_stone(image, Color(0.42, 0.44, 0.48), 8)
		Pattern.COBBLE:
			_fill_cobble(image)
		Pattern.PLASTER:
			_fill_plaster(image)
		Pattern.WOOD_PLANK:
			_fill_wood_planks(image, Color(0.46, 0.34, 0.24), true)
		Pattern.WOOD_GRAIN:
			_fill_wood_planks(image, Color(0.4, 0.28, 0.18), false)
		Pattern.BRICK:
			_fill_brick(image)
		Pattern.DIRT:
			_fill_dirt(image)
	return image


static func _fill_stone(image: Image, base: Color, block_size: int) -> void:
	var size := image.get_width()
	for y: int in range(0, size, block_size):
		for x: int in range(0, size, block_size):
			var shade := _hash01(x / block_size, y / block_size) * 0.14 - 0.07
			var color := base.lightened(shade)
			_fill_block(image, x, y, block_size, color)


static func _fill_cobble(image: Image) -> void:
	var size := image.get_width()
	var block_size := 10
	for y: int in range(0, size, block_size):
		for x: int in range(0, size, block_size):
			var offset_x := int(_hash01(x, y + 3) * 3.0) - 1
			var offset_y := int(_hash01(x + 5, y) * 3.0) - 1
			var shade := _hash01(x + 1, y + 2) * 0.18 - 0.08
			var color := Color(0.34, 0.32, 0.3).lightened(shade)
			_fill_block(image, x + offset_x, y + offset_y, block_size - 2, color)


static func _fill_plaster(image: Image) -> void:
	_fill_stone(image, Color(0.36, 0.37, 0.4), 6)
	var size := image.get_width()
	for i: int in range(3):
		var start := Vector2i(int(_hash01(i, 0) * float(size)), int(_hash01(i, 1) * float(size)))
		var end := Vector2i(int(_hash01(i, 2) * float(size)), int(_hash01(i, 3) * float(size)))
		_draw_line(image, start, end, Color(0.24, 0.25, 0.28))


static func _fill_wood_planks(image: Image, base: Color, horizontal: bool) -> void:
	var size := image.get_width()
	var plank_size := 8
	if horizontal:
		for y: int in range(0, size, plank_size):
			var shade := _hash01(0, y / plank_size) * 0.12 - 0.06
			var color := base.lightened(shade)
			for py: int in range(plank_size):
				for px: int in range(size):
					var grain := sin(float(px) * 0.65 + float(y) * 0.08) * 0.025
					image.set_pixel(px, y + py, color.lightened(grain))
	else:
		for x: int in range(0, size, plank_size):
			var shade := _hash01(x / plank_size, 0) * 0.12 - 0.06
			var color := base.lightened(shade)
			for px: int in range(plank_size):
				for py: int in range(size):
					var grain := sin(float(py) * 0.65 + float(x) * 0.08) * 0.025
					image.set_pixel(x + px, py, color.lightened(grain))


static func _fill_brick(image: Image) -> void:
	var size := image.get_width()
	var brick_w := 16
	var brick_h := 8
	var mortar := Color(0.18, 0.17, 0.19)
	image.fill(mortar)
	for row: int in range(size / brick_h):
		var offset := (row % 2) * (brick_w / 2)
		for col: int in range(size / brick_w + 1):
			var x := col * brick_w + offset
			var y := row * brick_h
			var shade := _hash01(row, col) * 0.14 - 0.05
			var color := Color(0.34, 0.22, 0.2).lightened(shade)
			_fill_rect(image, x + 1, y + 1, brick_w - 2, brick_h - 2, color)


static func _fill_dirt(image: Image) -> void:
	var size := image.get_width()
	for y: int in range(size):
		for x: int in range(size):
			var noise := _hash01(x, y) * 0.16 - 0.08
			var pebble := 1.0 if _hash01(x + 7, y + 3) > 0.93 else 0.0
			var color := Color(0.22, 0.18, 0.14).lightened(noise + pebble * 0.08)
			image.set_pixel(x, y, color)


static func _fill_block(
	image: Image,
	x: int,
	y: int,
	block_size: int,
	color: Color,
) -> void:
	_fill_rect(image, x, y, block_size, block_size, color)


static func _fill_rect(
	image: Image,
	x: int,
	y: int,
	width: int,
	height: int,
	color: Color,
) -> void:
	var size := image.get_width()
	for py: int in range(height):
		for px: int in range(width):
			var px_clamped := x + px
			var py_clamped := y + py
			if px_clamped < 0 or py_clamped < 0 or px_clamped >= size or py_clamped >= size:
				continue
			image.set_pixel(px_clamped, py_clamped, color)


static func _draw_line(image: Image, start: Vector2i, end: Vector2i, color: Color) -> void:
	var size := image.get_width()
	var steps := maxi(absi(end.x - start.x), absi(end.y - start.y))
	if steps <= 0:
		return
	for step: int in range(steps + 1):
		var t := float(step) / float(steps)
		var x := int(lerpf(float(start.x), float(end.x), t))
		var y := int(lerpf(float(start.y), float(end.y), t))
		if x >= 0 and y >= 0 and x < size and y < size:
			image.set_pixel(x, y, color)


static func _hash01(x: int, y: int) -> float:
	var value := (x * 374761393 + y * 668265263) & 0x7fffffff
	return float(value % 1000) / 1000.0


static func export_texture_assets() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/textures/explore")
	DirAccess.make_dir_recursive_absolute("res://assets/battlegrounds")
	_save_pattern(Pattern.STONE, "res://assets/textures/explore/stone.png")
	_save_pattern(Pattern.COBBLE, "res://assets/textures/explore/cobble.png")
	_save_pattern(Pattern.PLASTER, "res://assets/textures/explore/plaster.png")
	_save_pattern(Pattern.WOOD_PLANK, "res://assets/textures/explore/wood_plank.png")
	_save_pattern(Pattern.WOOD_GRAIN, "res://assets/textures/explore/wood_grain.png")
	_save_pattern(Pattern.BRICK, "res://assets/textures/explore/brick.png")
	_save_pattern(Pattern.DIRT, "res://assets/textures/explore/dirt.png")


static func _save_pattern(pattern: Pattern, path: String) -> void:
	var image := _generate_pattern_image(pattern)
	image.save_png(path)


static func _pattern_asset_path(pattern: Pattern) -> String:
	match pattern:
		Pattern.STONE:
			return "res://assets/textures/explore/stone.png"
		Pattern.COBBLE:
			return "res://assets/textures/explore/cobble.png"
		Pattern.PLASTER:
			return "res://assets/textures/explore/plaster.png"
		Pattern.WOOD_PLANK:
			return "res://assets/textures/explore/wood_plank.png"
		Pattern.WOOD_GRAIN:
			return "res://assets/textures/explore/wood_grain.png"
		Pattern.BRICK:
			return "res://assets/textures/explore/brick.png"
		Pattern.DIRT:
			return "res://assets/textures/explore/dirt.png"
	return ""
