class_name BattleCamera
extends Camera3D

const BLEND_DURATION: float = 0.55
const MOVE_BLEND_DURATION: float = 0.35
const HEIGHT: float = 3.6
const BEHIND_DISTANCE: float = 5.6
const PAN_STRENGTH: float = 0.7
const MOVE_SELECT_HEIGHT: float = 9.0
const MOVE_SELECT_DISTANCE: float = 9.5
const MOVE_SELECT_PAN_STRENGTH: float = 0.25

var _blend_tween: Tween = null


func focus_unit(unit_world_pos: Vector3, look_at: Vector3, instant: bool = false) -> void:
	_apply_transform(
		_compute_combat_transform(unit_world_pos, look_at),
		instant,
		DebugSettings.scale_battle_duration(BLEND_DURATION),
	)


func focus_move_selection(unit_world_pos: Vector3, look_at: Vector3, instant: bool = false) -> void:
	_apply_transform(
		_compute_move_select_transform(unit_world_pos, look_at),
		instant,
		DebugSettings.scale_battle_duration(BLEND_DURATION),
	)


func track_movement(
	from_pos: Vector3,
	to_pos: Vector3,
	look_at: Vector3,
	duration: float = MOVE_BLEND_DURATION,
) -> void:
	if _blend_tween != null and _blend_tween.is_valid():
		_blend_tween.kill()
	_blend_tween = create_tween()
	_blend_tween.tween_method(
		_apply_combat_focus.bind(look_at),
		from_pos,
		to_pos,
		duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _apply_combat_focus(look_at: Vector3, unit_world_pos: Vector3) -> void:
	global_transform = _compute_combat_transform(unit_world_pos, look_at)


func _apply_transform(target_transform: Transform3D, instant: bool, duration: float) -> void:
	if instant:
		global_transform = target_transform
		return
	if _blend_tween != null and _blend_tween.is_valid():
		_blend_tween.kill()
	_blend_tween = create_tween()
	_blend_tween.tween_property(self, "global_transform", target_transform, duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)


func _compute_combat_transform(unit_world_pos: Vector3, look_at: Vector3) -> Transform3D:
	var camera_pos := Vector3(
		unit_world_pos.x * PAN_STRENGTH,
		HEIGHT,
		unit_world_pos.z - BEHIND_DISTANCE,
	)
	var focus_point := unit_world_pos.lerp(look_at, 0.25)
	focus_point.y = 0.85
	return _make_look_transform(camera_pos, focus_point)


func _compute_move_select_transform(unit_world_pos: Vector3, look_at: Vector3) -> Transform3D:
	var camera_pos := Vector3(
		unit_world_pos.x * MOVE_SELECT_PAN_STRENGTH,
		MOVE_SELECT_HEIGHT,
		unit_world_pos.z - MOVE_SELECT_DISTANCE,
	)
	var focus_point := unit_world_pos.lerp(look_at, 0.6)
	focus_point.y = 0.2
	return _make_look_transform(camera_pos, focus_point)


static func _make_look_transform(camera_pos: Vector3, focus_point: Vector3) -> Transform3D:
	var transform := Transform3D()
	transform.origin = camera_pos
	transform = transform.looking_at(focus_point, Vector3.UP)
	return transform
