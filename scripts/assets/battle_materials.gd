class_name BattleMaterials
extends RefCounted

const EnvironmentMaterialsScript = preload("res://scripts/assets/environment_materials.gd")
const TILE_TEXTURE_PATH: String = "res://assets/textures/battle/grid_tile.png"

## Battles are fought on the ground of the area they started in.
const AREA_GROUND: Dictionary = {
	"village_square": "cobble",
	"old_chapel": "flagstone",
	"weavers_cottage": "timber",
	"granary": "timber",
	"root_cellar": "earth",
	"mira_intake_alcove": "cobble",
	"mira_chapel_lane": "cobble",
	"mira_woods_edge": "needles",
}
const DEFAULT_GROUND: String = "flagstone"
const GROUND_PLANE_SIZE: float = 40.0
const TILE_TINT: Color = Color(0.72, 0.71, 0.7)
const GROUND_TINT: Color = Color(0.36, 0.36, 0.38)

const TILE_DEFAULT_TINT: Color = Color(0.72, 0.76, 0.7, 0.12)
const TILE_MOVE_TINT: Color = Color(0.95, 0.88, 0.55, 0.48)
const TILE_MOVE_HOVER_TINT: Color = Color(1.0, 0.96, 0.68, 0.72)
const TILE_TARGET_TINT: Color = Color(0.95, 0.42, 0.42, 0.52)
const TILE_TARGET_HOVER_TINT: Color = Color(1.0, 0.58, 0.58, 0.78)

static var _tile_template: StandardMaterial3D = null


static func get_ground_texture_name() -> String:
	var area_id := ""
	if GameState != null:
		area_id = GameState.return_area_id
	return str(AREA_GROUND.get(area_id, DEFAULT_GROUND))


## A darker sheet of the same ground under the grid, reaching off into the fog.
static func add_ground_plane(battleground: Node3D) -> void:
	if battleground == null or battleground.has_node("GroundPlane"):
		return
	var plane := MeshInstance3D.new()
	plane.name = "GroundPlane"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(GROUND_PLANE_SIZE, GROUND_PLANE_SIZE)
	plane.mesh = mesh
	plane.position = Vector3(0.0, -0.08, 0.0)
	plane.material_override = EnvironmentMaterialsScript.world_material(get_ground_texture_name(), GROUND_TINT, 1.4)
	battleground.add_child(plane)


static func get_tile_floor_material() -> StandardMaterial3D:
	return EnvironmentMaterialsScript.world_material(get_ground_texture_name(), TILE_TINT, CombatConstants.TILE_SIZE)


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
	_generate_battle_tile_image().save_png(TILE_TEXTURE_PATH)


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


static func _load_or_generate_tile_texture() -> Texture2D:
	if ResourceLoader.exists(TILE_TEXTURE_PATH):
		return load(TILE_TEXTURE_PATH) as Texture2D
	return ImageTexture.create_from_image(_generate_battle_tile_image())


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
