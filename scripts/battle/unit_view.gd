class_name UnitView
extends Node3D

const CharacterRigScript = preload("res://scripts/assets/characters/character_rig.gd")
const SurvivorCharacterModelScript = preload("res://scripts/assets/characters/survivor_character_model.gd")
const Ps1BlockModelScript = preload("res://scripts/assets/ps1_block_model.gd")
const Ps1EnemyModelScript = preload("res://scripts/assets/ps1_enemy_model.gd")

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var name_label: Label3D = $Label3D
@onready var hp_bar: MeshInstance3D = $HPBar

const FLOATING_LABEL_OFFSET: float = 0.18
const FLOATING_LABEL_FALLBACK_Y: float = 1.0

var runtime_id: String = ""
var combat_unit: CombatUnit = null
var _is_active_turn: bool = false
var _character_model: Node3D = null
var _moving: bool = false


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


func _process(delta: float) -> void:
	if _character_model is CharacterRigScript:
		_update_rig_animation(_character_model as CharacterRigScript, delta)
	elif _character_model is Ps1BlockModelScript:
		_update_block_animation(_character_model as Ps1BlockModelScript, delta)


func _update_block_animation(model: Ps1BlockModelScript, delta: float) -> void:
	if model.is_action_playing():
		return
	if model.is_chanting():
		model.update_animation(delta, 0.0)
		return
	if _moving:
		model.update_animation(delta, 1.0)
		return
	if combat_unit != null and not combat_unit.is_ko:
		model.update_animation(delta, 0.0)


func _update_rig_animation(model: CharacterRigScript, delta: float) -> void:
	if model.is_action_playing():
		return
	if model.is_chanting():
		model.update_animation(delta, 0.0)
		return
	if _moving:
		model.update_animation(delta, 1.0)
		return
	if combat_unit != null and not combat_unit.is_ko:
		model.update_animation(delta, 0.0)


func play_attack_animation() -> void:
	if _character_model is CharacterRigScript:
		await (_character_model as CharacterRigScript).play_attack()
	elif _character_model is Ps1BlockModelScript:
		await (_character_model as Ps1BlockModelScript).play_attack()


func start_chant_animation() -> void:
	if _character_model is CharacterRigScript:
		(_character_model as CharacterRigScript).set_chanting(true)
	elif _character_model is Ps1BlockModelScript:
		(_character_model as Ps1BlockModelScript).set_chanting(true)


func stop_chant_animation() -> void:
	if _character_model is CharacterRigScript:
		(_character_model as CharacterRigScript).set_chanting(false)
	elif _character_model is Ps1BlockModelScript:
		(_character_model as Ps1BlockModelScript).set_chanting(false)


func play_chant_release_animation() -> void:
	if _character_model is CharacterRigScript:
		await (_character_model as CharacterRigScript).play_chant_release()
	elif _character_model is Ps1BlockModelScript:
		await (_character_model as Ps1BlockModelScript).play_chant_release()


func get_ground_y_offset() -> float:
	if _character_model is CharacterRigScript:
		return CombatConstants.TILE_FLOOR_Y
	return CombatConstants.LEGACY_UNIT_Y


func get_world_position_for_cell(grid_pos: Vector2i, grid: BattleGrid) -> Vector3:
	return grid.grid_to_world(grid_pos) + Vector3(0.0, get_ground_y_offset(), 0.0)


func move_to_world(world_pos: Vector3, instant: bool = false, duration: float = -1.0) -> void:
	if instant:
		position = world_pos
		_moving = false
		return
	var move_duration := duration
	if move_duration < 0.0:
		move_duration = DebugSettings.scale_battle_duration(CombatConstants.UNIT_MOVE_DURATION)
	_moving = true
	SfxManager.play("battle_move", randf_range(0.95, 1.05), -3.0)
	var tween := create_tween()
	tween.tween_property(self, "position", world_pos, move_duration).set_trans(Tween.TRANS_QUAD)
	tween.finished.connect(func() -> void:
		_moving = false
		if _character_model is CharacterRigScript:
			var rig := _character_model as CharacterRigScript
			if not rig.is_chanting():
				rig.update_animation(0.0, 0.0)
		elif _character_model is Ps1BlockModelScript:
			var block_model := _character_model as Ps1BlockModelScript
			if not block_model.is_chanting():
				block_model.update_animation(0.0, 0.0)
	)


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
	if _character_model != null:
		_character_model.queue_free()
		_character_model = null
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
			_character_model = scene.instantiate() as Node3D

	if _character_model == null:
		if unit.is_ally:
			_character_model = SurvivorCharacterModelScript.create(unit.source_id)
		else:
			_character_model = Ps1EnemyModelScript.create(unit.source_id)

	if _character_model == null:
		mesh.visible = true
		return
	add_child(_character_model)


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
	if _character_model == null:
		return FLOATING_LABEL_FALLBACK_Y
	if _character_model is CharacterRigScript:
		return (_character_model as CharacterRigScript).get_model_top_y() + FLOATING_LABEL_OFFSET
	var model := _character_model as Ps1BlockModelScript
	if model == null:
		return FLOATING_LABEL_FALLBACK_Y
	var top := 0.0
	var model_scale := _character_model.scale.y
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

	if _character_model != null:
		_apply_character_visual_state()
		return

	var color: Color = _resolve_unit_color()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if _is_active_turn and not combat_unit.is_ko:
		material.emission_enabled = true
		material.emission = color * 0.35
	mesh.material_override = material


func _apply_character_visual_state() -> void:
	if combat_unit.is_ko:
		rotation.z = deg_to_rad(90.0)
		scale = Vector3.ONE
		if _character_model is CharacterRigScript:
			(_character_model as CharacterRigScript).apply_ko_darken()
		elif _character_model is Ps1BlockModelScript:
			(_character_model as Ps1BlockModelScript).apply_ko_darken()
		return

	rotation.z = 0.0
	scale = Vector3.ONE * (
		CombatConstants.TURN_ACTIVE_SCALE if _is_active_turn else 1.0
	)
	var tint := _resolve_unit_color()
	if _is_active_turn:
		if _character_model is CharacterRigScript:
			(_character_model as CharacterRigScript).apply_tint(tint, tint * 0.35)
		elif _character_model is Ps1BlockModelScript:
			(_character_model as Ps1BlockModelScript).apply_tint(tint, tint * 0.35)
	else:
		if _character_model is CharacterRigScript:
			(_character_model as CharacterRigScript).reset_materials()
		elif _character_model is Ps1BlockModelScript:
			(_character_model as Ps1BlockModelScript).reset_materials()


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
