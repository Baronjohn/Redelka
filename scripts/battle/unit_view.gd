class_name UnitView
extends Node3D

const Ps1BlockModelScript = preload("res://scripts/assets/ps1_block_model.gd")
const Ps1SurvivorModelScript = preload("res://scripts/assets/ps1_survivor_model.gd")
const Ps1EnemyModelScript = preload("res://scripts/assets/ps1_enemy_model.gd")

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var name_label: Label3D = $Label3D
@onready var hp_bar: MeshInstance3D = $HPBar

const FLOATING_LABEL_OFFSET: float = 0.18
const FLOATING_LABEL_FALLBACK_Y: float = 1.0

var runtime_id: String = ""
var combat_unit: CombatUnit = null
var _is_active_turn: bool = false
var _block_model: Node3D = null


func bind_unit(unit: CombatUnit) -> void:
	combat_unit = unit
	runtime_id = unit.runtime_id
	name_label.visible = false
	hp_bar.visible = false
	unit.hp_changed.connect(_on_hp_changed)
	unit.ko_changed.connect(_on_ko_changed)
	_on_hp_changed(unit.current_hp, unit.max_hp)
	_on_ko_changed(unit.is_ko)
	_attach_unit_model(unit)
	_apply_visual_state()


func set_turn_active(active: bool) -> void:
	_is_active_turn = active
	_apply_visual_state()


func move_to_world(world_pos: Vector3, instant: bool = false, duration: float = -1.0) -> void:
	if instant:
		position = world_pos
		return
	var move_duration := duration
	if move_duration < 0.0:
		move_duration = DebugSettings.scale_battle_duration(CombatConstants.UNIT_MOVE_DURATION)
	var tween := create_tween()
	tween.tween_property(self, "position", world_pos, move_duration).set_trans(Tween.TRANS_QUAD)


func show_floating_number(amount: int, is_healing: bool) -> void:
	if amount <= 0:
		return
	var text := "+%d" % amount if is_healing else "-%d" % amount
	var color := (
		CombatConstants.HEAL_NUMBER_COLOR
		if is_healing
		else CombatConstants.DAMAGE_NUMBER_COLOR
	)
	_spawn_floating_label(text, color)


func show_floating_miss() -> void:
	_spawn_floating_label("Miss", CombatConstants.DAMAGE_NUMBER_COLOR)


func _attach_unit_model(unit: CombatUnit) -> void:
	if _block_model != null:
		_block_model.queue_free()
		_block_model = null
	mesh.visible = false

	var model_path := ""
	if unit.is_ally:
		var characters := DataLoader.load_characters()
		if characters.has(unit.source_id):
			model_path = (characters[unit.source_id] as CharacterData).model_path
	else:
		var enemies := DataLoader.load_enemies()
		if enemies.has(unit.source_id):
			model_path = (enemies[unit.source_id] as EnemyData).model_path

	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var scene := load(model_path) as PackedScene
		if scene != null:
			_block_model = scene.instantiate() as Node3D

	if _block_model == null:
		if unit.is_ally:
			_block_model = Ps1SurvivorModelScript.create(unit.source_id)
		else:
			_block_model = Ps1EnemyModelScript.create(unit.source_id)

	if _block_model == null:
		mesh.visible = true
		return
	add_child(_block_model)


func _spawn_floating_label(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.outline_size = 8
	label.modulate = color
	var base_y := _get_floating_label_base_y()
	label.position = Vector3(randf_range(-0.2, 0.2), base_y, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		label,
		"position:y",
		base_y + CombatConstants.FLOATING_NUMBER_RISE,
		DebugSettings.scale_battle_duration(CombatConstants.FLOATING_NUMBER_DURATION),
	)
	tween.tween_property(
		label,
		"modulate:a",
		0.0,
		DebugSettings.scale_battle_duration(CombatConstants.FLOATING_NUMBER_DURATION),
	)
	tween.chain().tween_callback(label.queue_free)


func _get_floating_label_base_y() -> float:
	if _block_model == null:
		return FLOATING_LABEL_FALLBACK_Y
	return _get_block_model_top_y() + FLOATING_LABEL_OFFSET


func _get_block_model_top_y() -> float:
	var model := _block_model as Ps1BlockModelScript
	if model == null:
		return FLOATING_LABEL_FALLBACK_Y
	var top := 0.0
	var model_scale := _block_model.scale.y
	for mesh_instance: MeshInstance3D in model.get_mesh_instances():
		if mesh_instance.mesh == null:
			continue
		var half_height := mesh_instance.mesh.get_aabb().size.y * 0.5
		var mesh_top := (mesh_instance.position.y + half_height) * model_scale
		top = maxf(top, mesh_top)
	return top


func _apply_visual_state() -> void:
	if combat_unit == null:
		return

	if _block_model != null:
		_apply_block_visual_state()
		return

	var color: Color = _resolve_unit_color()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if _is_active_turn and not combat_unit.is_ko:
		material.emission_enabled = true
		material.emission = color * 0.35
	mesh.material_override = material


func _apply_block_visual_state() -> void:
	var model := _block_model as Ps1BlockModelScript
	if combat_unit.is_ko:
		rotation.z = deg_to_rad(90.0)
		scale = Vector3.ONE
		model.apply_ko_darken()
		return

	rotation.z = 0.0
	scale = Vector3.ONE * (
		CombatConstants.TURN_ACTIVE_SCALE if _is_active_turn else 1.0
	)
	var tint := _resolve_unit_color()
	if _is_active_turn:
		model.apply_tint(tint, tint * 0.35)
	else:
		model.reset_materials()


func _resolve_unit_color() -> Color:
	if combat_unit.is_ko:
		return Color(0.45, 0.45, 0.45)
	if _is_active_turn:
		return CombatConstants.TURN_HIGHLIGHT_COLOR
	return CombatConstants.ALLY_COLOR if combat_unit.is_ally else CombatConstants.ENEMY_COLOR


func _on_hp_changed(current: int, maximum: int) -> void:
	var ratio := 0.0 if maximum <= 0 else float(current) / float(maximum)
	hp_bar.scale.x = maxf(ratio, 0.05)
	var hp_material := StandardMaterial3D.new()
	hp_material.albedo_color = Color(0.2, 0.85, 0.25) if ratio > 0.35 else Color(0.9, 0.3, 0.2)
	hp_bar.material_override = hp_material


func _on_ko_changed(_is_ko: bool) -> void:
	_apply_visual_state()
