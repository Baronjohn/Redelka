class_name BattleMaterials
extends RefCounted

const FLOOR_TEXTURE_PATH: String = "res://assets/textures/battle/floor.png"
const TILE_TEXTURE_PATH: String = "res://assets/textures/battle/grid_tile.png"

const FLOOR_UV: Vector3 = Vector3(8.0, 1.0, 8.0)
const TILE_FLOOR_UV: Vector3 = Vector3(1.0, 1.0, 1.0)
const FLOOR_TINT: Color = Color(0.52, 0.44, 0.36)

const TILE_DEFAULT_TINT: Color = Color(0.72, 0.76, 0.7, 0.12)
const TILE_MOVE_TINT: Color = Color(0.95, 0.88, 0.55, 0.48)
const TILE_MOVE_HOVER_TINT: Color = Color(1.0, 0.96, 0.68, 0.72)
const TILE_TARGET_TINT: Color = Color(0.95, 0.42, 0.42, 0.52)
const TILE_TARGET_HOVER_TINT: Color = Color(1.0, 0.58, 0.58, 0.78)

static var _floor_material: StandardMaterial3D = null
static var _tile_template: StandardMaterial3D = null


static func apply_battleground_floor(floor: MeshInstance3D) -> void:
	if floor == null:
		return
	floor.material_override = get_floor_material()


static func get_floor_material() -> StandardMaterial3D:
	if _floor_material == null:
		_floor_material = _build_floor_material()
	return _floor_material


static func get_tile_floor_material() -> StandardMaterial3D:
	var material := get_floor_material().duplicate() as StandardMaterial3D
	material.uv1_scale = TILE_FLOOR_UV
	return material


static func get_tile_default_tint() -> Color:
	return TILE_DEFAULT_TINT


static func get_tile_move_tint() -> Color:
	return TILE_MOVE_TINT


static func get_tile_move_hover_tint() -> Color:
	return TILE_MOVE_HOVER_TINT


static func get_tile_target_tint() -> Color:
	return TILE_TARGET_TINT


static func get_tile_target_hover_tint() -> Color:
	return TILE_TARGET_HOVER_TINT


static func create_tile_material(tint: Color) -> StandardMaterial3D:
	var material := _get_tile_template().duplicate() as StandardMaterial3D
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func export_texture_assets() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/textures/battle")
	_generate_battle_floor_image().save_png(FLOOR_TEXTURE_PATH)
	_generate_battle_tile_image().save_png(TILE_TEXTURE_PATH)


static func _build_floor_material() -> StandardMaterial3D:
	var texture := _load_or_generate_floor_texture()
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = FLOOR_TINT
	material.uv1_scale = FLOOR_UV
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.96
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


static func _get_tile_template() -> StandardMaterial3D:
	if _tile_template == null:
		_tile_template = _build_tile_template()
	return _tile_template


static func _build_tile_template() -> StandardMaterial3D:
	var texture := _load_or_generate_tile_texture()
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = TILE_DEFAULT_TINT
	material.uv1_scale = Vector3.ONE
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


static func _load_or_generate_floor_texture() -> Texture2D:
	if ResourceLoader.exists(FLOOR_TEXTURE_PATH):
		return load(FLOOR_TEXTURE_PATH) as Texture2D
	return ImageTexture.create_from_image(_generate_battle_floor_image())


static func _load_or_generate_tile_texture() -> Texture2D:
	if ResourceLoader.exists(TILE_TEXTURE_PATH):
		return load(TILE_TEXTURE_PATH) as Texture2D
	return ImageTexture.create_from_image(_generate_battle_tile_image())


static func _generate_battle_floor_image() -> Image:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var gap := Color(0.1, 0.08, 0.07)
	var plank_a := Color(0.34, 0.26, 0.18)
	var plank_b := Color(0.28, 0.21, 0.15)
	var plank_c := Color(0.22, 0.17, 0.12)
	image.fill(gap)
	var plank_height := 8
	for row: int in range(size / plank_height):
		var palette: Array[Color] = [plank_a, plank_b, plank_c]
		var base := palette[row % palette.size()]
		for py: int in range(plank_height):
			for px: int in range(size):
				var grain := sin(float(px) * 0.85 + float(row) * 0.35) * 0.03
				var stain := 0.0 if _hash01(px + row, py) > 0.88 else -0.08
				image.set_pixel(px, row * plank_height + py, base.lightened(grain + stain))
	return image


static func _generate_battle_tile_image() -> Image:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var fill := Color(0.24, 0.22, 0.18)
	var edge := Color(0.14, 0.12, 0.1)
	image.fill(fill)
	for i: int in range(size):
		image.set_pixel(i, 0, edge)
		image.set_pixel(i, size - 1, edge)
		image.set_pixel(0, i, edge)
		image.set_pixel(size - 1, i, edge)
	return image


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


static func _hash01(x: int, y: int) -> float:
	var value := (x * 374761393 + y * 668265263) & 0x7fffffff
	return float(value % 1000) / 1000.0
