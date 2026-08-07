class_name UnitView
extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var name_label: Label3D = $Label3D
@onready var hp_bar: MeshInstance3D = $HPBar

var runtime_id: String = ""
var combat_unit: CombatUnit = null
var _is_active_turn: bool = false


func bind_unit(unit: CombatUnit) -> void:
	combat_unit = unit
	runtime_id = unit.runtime_id
	name_label.text = unit.display_name
	unit.hp_changed.connect(_on_hp_changed)
	unit.ko_changed.connect(_on_ko_changed)
	_on_hp_changed(unit.current_hp, unit.max_hp)
	_on_ko_changed(unit.is_ko)
	_apply_visual_state()


func set_turn_active(active: bool) -> void:
	_is_active_turn = active
	_apply_visual_state()


func move_to_world(world_pos: Vector3, instant: bool = false) -> void:
	if instant:
		position = world_pos
		return
	var tween := create_tween()
	tween.tween_property(self, "position", world_pos, 0.25).set_trans(Tween.TRANS_QUAD)


func _apply_visual_state() -> void:
	if combat_unit == null:
		return

	var color: Color
	if combat_unit.is_ko:
		color = Color(0.45, 0.45, 0.45)
		rotation.z = deg_to_rad(90.0)
		scale = Vector3.ONE
	elif _is_active_turn:
		color = CombatConstants.TURN_HIGHLIGHT_COLOR
		rotation.z = 0.0
		scale = Vector3.ONE * CombatConstants.TURN_ACTIVE_SCALE
	else:
		color = CombatConstants.ALLY_COLOR if combat_unit.is_ally else CombatConstants.ENEMY_COLOR
		rotation.z = 0.0
		scale = Vector3.ONE

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if _is_active_turn and not combat_unit.is_ko:
		material.emission_enabled = true
		material.emission = color * 0.35
	mesh.material_override = material


func _on_hp_changed(current: int, maximum: int) -> void:
	var ratio := 0.0 if maximum <= 0 else float(current) / float(maximum)
	hp_bar.scale.x = maxf(ratio, 0.05)
	var hp_material := StandardMaterial3D.new()
	hp_material.albedo_color = Color(0.2, 0.85, 0.25) if ratio > 0.35 else Color(0.9, 0.3, 0.2)
	hp_bar.material_override = hp_material


func _on_ko_changed(is_ko: bool) -> void:
	_apply_visual_state()
