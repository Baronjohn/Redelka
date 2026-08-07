class_name GridTile
extends StaticBody3D

@export var cell: Vector2i = Vector2i.ZERO

var _mesh: MeshInstance3D
var _default_color := Color(0.28, 0.32, 0.28, 0.35)
var _highlight_color := Color(0.95, 0.85, 0.2, 0.55)
var _target_color := Color(0.95, 0.35, 0.35, 0.55)


func _ready() -> void:
	_mesh = $MeshInstance3D
	_apply_color(_default_color)


func set_move_highlight(enabled: bool) -> void:
	_apply_color(_highlight_color if enabled else _default_color)


func set_target_highlight(enabled: bool) -> void:
	_apply_color(_target_color if enabled else _default_color)


func reset_highlight() -> void:
	_apply_color(_default_color)


func _apply_color(color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = material
