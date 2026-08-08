class_name GridTile
extends StaticBody3D

const BattleMaterialsScript = preload("res://scripts/assets/battle_materials.gd")

enum SelectionKind {
	NONE,
	MOVE,
	TARGET,
}

@export var cell: Vector2i = Vector2i.ZERO

var _floor_mesh: MeshInstance3D
var _highlight_mesh: MeshInstance3D
var _selection: SelectionKind = SelectionKind.NONE
var _hovered: bool = false


func _ready() -> void:
	_floor_mesh = $FloorMesh
	_floor_mesh.material_override = BattleMaterialsScript.get_tile_floor_material()
	_highlight_mesh = MeshInstance3D.new()
	_highlight_mesh.name = "HighlightMesh"
	var box := BoxMesh.new()
	box.size = Vector3(1.25, 0.12, 1.25)
	_highlight_mesh.mesh = box
	_highlight_mesh.position.y = 0.02
	add_child(_highlight_mesh)
	reset_highlight()


func set_move_highlight(enabled: bool) -> void:
	if enabled:
		_selection = SelectionKind.MOVE
	elif _selection == SelectionKind.MOVE:
		_selection = SelectionKind.NONE
	_apply_highlight()


func set_target_highlight(enabled: bool) -> void:
	if enabled:
		_selection = SelectionKind.TARGET
	elif _selection == SelectionKind.TARGET:
		_selection = SelectionKind.NONE
	_apply_highlight()


func set_hover_highlight(enabled: bool) -> void:
	_hovered = enabled
	_apply_highlight()


func reset_highlight() -> void:
	_selection = SelectionKind.NONE
	_hovered = false
	_apply_highlight()


func _apply_highlight() -> void:
	if _selection == SelectionKind.NONE:
		_highlight_mesh.visible = false
		return
	_highlight_mesh.visible = true
	_highlight_mesh.position.y = 0.04 if _hovered else 0.02
	var tint: Color
	match _selection:
		SelectionKind.MOVE:
			tint = (
				BattleMaterialsScript.get_tile_move_hover_tint()
				if _hovered
				else BattleMaterialsScript.get_tile_move_tint()
			)
		SelectionKind.TARGET:
			tint = (
				BattleMaterialsScript.get_tile_target_hover_tint()
				if _hovered
				else BattleMaterialsScript.get_tile_target_tint()
			)
		_:
			tint = BattleMaterialsScript.get_tile_move_tint()
	_highlight_mesh.material_override = BattleMaterialsScript.create_tile_material(tint)
