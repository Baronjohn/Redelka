extends Node

const PartyStatsHelper = preload("res://scripts/data/party_stats.gd")

enum BattlePhase {
	START,
	TURN_START,
	PLAYER_MAIN,
	PLAYER_ACTION_SUB,
	SELECT_MOVE,
	SELECT_ATTACK_TARGET,
	SELECT_SPELL,
	SELECT_SPELL_TARGET,
	SELECT_SKILL_TARGET,
	SELECT_ITEM,
	SELECT_ITEM_TARGET,
	SELECT_SWITCH_WEAPON,
	ENEMY_TURN,
	BATTLE_END,
}

enum BattleOutcome { NONE, VICTORY, DEFEAT, ESCAPED }

signal log_message(text: String)
signal phase_changed(phase: BattlePhase)
signal turn_order_changed(order: Array[String])
signal battle_finished(outcome: BattleOutcome)

const SAVE_SLOT_PANEL_SCENE: PackedScene = preload("res://scenes/menu/save_slot_panel.tscn")

@export var encounter_id: String = "test_4v3"

@onready var units_root: Node3D = $"../Units"
@onready var tiles_root: Node3D = $"../Battleground/Tiles"
@onready var camera: Camera3D = $"../Camera3D"
@onready var unit_scene: PackedScene = preload("res://scenes/battle/unit.tscn")
@onready var tile_scene: PackedScene = preload("res://scenes/battle/grid_tile.tscn")
@onready var battle_ui: BattleUI = $"../UI/BattleUI"
@onready var result_panel: ResultPanel = $"../UI/ResultPanel"
@onready var level_up_panel: Control = $"../UI/LevelUpPanel"

var _grid := BattleGrid.new()
var _turn_queue := TurnQueue.new()
var _units: Dictionary = {}
var _unit_views: Dictionary = {}
var _tile_views: Dictionary = {}
var _spells: Dictionary = {}
var _items: Dictionary = {}
var _inventory: Dictionary = {}
var _encounter: EncounterData = EncounterData.new()

var _phase: BattlePhase = BattlePhase.START
var _outcome: BattleOutcome = BattleOutcome.NONE
var _current_unit_id: String = ""
var _selected_spell: SpellData = null
var _selected_item_id: String = ""
var _allow_retreat: bool = true
var _scheduled_enemy_removals: Dictionary = {}
var _save_panel: Control = null


func _ready() -> void:
	if GameState.overworld_enemy_id.is_empty():
		GameState.set_standalone_battle(encounter_id)
	battle_ui.action_requested.connect(_on_ui_action_requested)
	battle_ui.sub_action_requested.connect(_on_ui_sub_action_requested)
	battle_ui.wait_requested.connect(_on_ui_wait_requested)
	battle_ui.spell_selected.connect(_on_spell_selected)
	battle_ui.item_selected.connect(_on_item_selected)
	battle_ui.weapon_selected.connect(_on_weapon_selected)
	battle_ui.back_requested.connect(_on_ui_back_requested)
	log_message.connect(battle_ui.append_log)
	turn_order_changed.connect(_on_turn_order_changed)
	result_panel.restart_requested.connect(_on_restart_requested)
	result_panel.continue_requested.connect(_on_continue_requested)
	result_panel.load_save_requested.connect(_on_load_save_requested)
	result_panel.load_autosave_requested.connect(_on_load_autosave_requested)
	result_panel.main_menu_requested.connect(_on_main_menu_requested)
	level_up_panel.allocation_confirmed.connect(_on_level_up_confirmed)
	_position_camera()
	call_deferred("_start_battle")


func _position_camera() -> void:
	# Allies start on row 0 (negative Z); camera sits behind them looking toward enemies.
	camera.position = Vector3(0.0, 11.0, -9.0)
	camera.look_at(Vector3(0.0, 0.0, 1.5), Vector3.UP)


func _start_battle() -> void:
	_load_data()
	_build_tiles()
	_spawn_units()
	_turn_queue.build_queue(_all_units())
	_on_turn_order_changed(_turn_queue.get_display_order())
	_set_phase(BattlePhase.TURN_START)
	await get_tree().create_timer(0.2).timeout
	_begin_next_turn()


func _load_data() -> void:
	if GameState.battle_source == GameState.BattleSource.EXPLORE:
		encounter_id = GameState.current_encounter_id
	_encounter = DataLoader.load_encounter(encounter_id)
	_spells = DataLoader.load_spells()
	_items = DataLoader.load_items()
	GameState.ensure_party_initialized(_encounter.id)
	_inventory = GameState.inventory.duplicate()
	_allow_retreat = _encounter.allow_retreat
	var weapons := DataLoader.load_weapons()
	var skills := DataLoader.load_skills()
	var characters := DataLoader.load_characters()
	var enemies := DataLoader.load_enemies()

	for ally_entry: Dictionary in GameState.get_formation_spawn_entries():
		var character_id := str(ally_entry.get("character_id", ""))
		var pos_array: Array = ally_entry.get("position", [0, 0]) as Array
		var pos := Vector2i(int(pos_array[0]), int(pos_array[1]))
		var character: CharacterData = characters[character_id]
		var loadout: Dictionary = GameState.get_loadout(character_id)
		var snapshot := GameState.get_member_snapshot(character_id)
		var weapon: WeaponData = PartyStatsHelper.get_equipped_weapon(loadout)
		if weapon == null:
			push_error("Missing starting weapon for %s." % character_id)
			continue
		var skill: SkillData = null
		if not character.skill_id.is_empty():
			if not skills.has(character.skill_id):
				push_error("Missing skill %s for %s." % [character.skill_id, character_id])
				continue
			skill = skills[character.skill_id]
		var runtime_id := "ally_%s" % character_id
		var effective_stats := PartyStatsHelper.get_effective_stats(character, loadout, snapshot)
		var unit := CombatUnit.from_character_with_stats(
			runtime_id, character, weapon, skill, effective_stats, pos
		)
		_units[runtime_id] = unit
		_grid.set_occupant(pos, runtime_id)

	if GameState.battle_source == GameState.BattleSource.EXPLORE:
		GameState.apply_party_snapshot_to_allies(_ally_units())

	for enemy_entry: Dictionary in _encounter.enemies:
		var enemy_id := str(enemy_entry.get("enemy_id", ""))
		var pos_array: Array = enemy_entry.get("position", [0, 5]) as Array
		var pos := Vector2i(int(pos_array[0]), int(pos_array[1]))
		var enemy: EnemyData = enemies[enemy_id]
		var runtime_id := "enemy_%s" % enemy_id
		var unit := CombatUnit.from_enemy(runtime_id, enemy, pos)
		_units[runtime_id] = unit
		_grid.set_occupant(pos, runtime_id)


func _build_tiles() -> void:
	for y: int in BattleGrid.SIZE:
		for x: int in BattleGrid.SIZE:
			var cell := Vector2i(x, y)
			var tile: StaticBody3D = tile_scene.instantiate()
			tile.cell = cell
			tiles_root.add_child(tile)
			tile.position = _grid.grid_to_world(cell)
			_tile_views[cell] = tile


func _spawn_units() -> void:
	for runtime_id: String in _units.keys():
		var unit: CombatUnit = _units[runtime_id]
		var view: UnitView = unit_scene.instantiate() as UnitView
		units_root.add_child(view)
		view.bind_unit(unit)
		view.position = _grid.grid_to_world(unit.grid_pos) + Vector3(0.0, 0.8, 0.0)
		unit.ko_changed.connect(_on_unit_ko_changed.bind(runtime_id))
		_unit_views[runtime_id] = view


func _begin_next_turn() -> void:
	if _check_battle_end():
		return
	if _turn_queue.peek_current().is_empty():
		_turn_queue.build_queue(_living_units())
	if _turn_queue.peek_current().is_empty():
		_check_battle_end()
		return

	_current_unit_id = _turn_queue.advance()
	if not _units.has(_current_unit_id):
		_begin_next_turn()
		return
	var unit: CombatUnit = _units[_current_unit_id]
	unit.reset_turn_flags()
	_update_turn_highlight()
	turn_order_changed.emit(_turn_queue.get_display_order())
	log_message.emit("%s's turn." % unit.display_name)
	_set_phase(BattlePhase.TURN_START)

	if not unit.can_act():
		await get_tree().create_timer(0.3).timeout
		_begin_next_turn()
		return

	if unit.has_pending_spell():
		await _unleash_pending_spell(unit)
		if _check_battle_end():
			return

	if unit.is_ally:
		_set_phase(BattlePhase.PLAYER_MAIN)
		battle_ui.show_main_menu(unit, _allow_retreat)
	else:
		_set_phase(BattlePhase.ENEMY_TURN)
		await get_tree().create_timer(0.35).timeout
		_run_enemy_turn(unit)


func _run_enemy_turn(actor: CombatUnit) -> void:
	var selected_action := EnemyAI.roll_action(actor.enemy_data.actions)
	var row_bounds := _get_movement_row_bounds(actor)
	var action := EnemyAI.choose_action(
		actor, selected_action, _ally_units(), _grid, row_bounds.x, row_bounds.y
	)
	await _execute_enemy_action(actor, action, selected_action)
	if actor.can_act() and not actor.has_moved:
		var follow_up := EnemyAI.choose_action(
			actor, selected_action, _ally_units(), _grid, row_bounds.x, row_bounds.y
		)
		if str(follow_up.get("type", "")) == "move":
			await _move_unit(actor, follow_up["cell"] as Vector2i)
			var after_move := EnemyAI.choose_action(
				actor, selected_action, _ally_units(), _grid, row_bounds.x, row_bounds.y
			)
			await _execute_enemy_action(actor, after_move, selected_action)
		elif str(follow_up.get("type", "")) in ["attack", "debuff"] and not actor.has_acted:
			await _execute_enemy_action(actor, follow_up, selected_action)
	await get_tree().create_timer(0.25).timeout
	_begin_next_turn()


func _execute_enemy_action(
	actor: CombatUnit,
	action: Dictionary,
	selected_action: EnemyActionData,
) -> void:
	match str(action.get("type", "wait")):
		"move":
			var cell: Vector2i = action["cell"]
			await _move_unit(actor, cell)
		"attack":
			var attack_action := EnemyAI.get_action(
				actor.enemy_data,
				str(action.get("action_id", selected_action.id if selected_action != null else "")),
			)
			var target: CombatUnit = _units[str(action["target_id"])]
			await _perform_attack(actor, target, attack_action)
		"debuff":
			var debuff_action := EnemyAI.get_action(
				actor.enemy_data,
				str(action.get("action_id", selected_action.id if selected_action != null else "")),
			)
			await _perform_enemy_debuff(actor, debuff_action, action["targets"] as Array)


func _on_ui_action_requested(action: String) -> void:
	var unit: CombatUnit = _units[_current_unit_id]
	match action:
		"move":
			if unit.has_moved:
				log_message.emit("Already moved.")
				return
			_set_phase(BattlePhase.SELECT_MOVE)
			_show_reachable_tiles(unit)
			battle_ui.show_back_only()
		"action":
			_set_phase(BattlePhase.PLAYER_ACTION_SUB)
			battle_ui.show_action_submenu(
				unit,
				_allow_retreat,
				_can_unit_attack(unit),
				_can_unit_switch(unit),
			)


func _on_ui_sub_action_requested(action: String) -> void:
	var unit: CombatUnit = _units[_current_unit_id]
	if unit.has_acted:
		log_message.emit("Already acted.")
		return
	match action:
		"attack":
			if not _can_unit_attack(unit):
				if not GameState.can_attack_with_equipped_weapon(unit.source_id):
					log_message.emit("Cannot attack without a usable weapon.")
				else:
					log_message.emit("No enemies in range.")
				return
			_set_phase(BattlePhase.SELECT_ATTACK_TARGET)
			_show_attack_targets(unit)
			battle_ui.show_back_only()
		"spell":
			if unit.has_pending_spell():
				log_message.emit("Already casting a spell.")
				return
			_set_phase(BattlePhase.SELECT_SPELL)
			battle_ui.show_spell_menu(_build_spell_menu_entries(unit))
		"skill":
			if unit.skill == null:
				log_message.emit("No skill available.")
				return
			if unit.skill.mp_restore > 0:
				_consume_action(unit)
				unit.restore_mp(unit.skill.mp_restore)
				log_message.emit("%s used %s." % [unit.display_name, unit.skill.display_name])
				_end_player_turn_if_done(unit)
				return
			if unit.skill.endure:
				_consume_action(unit)
				unit.set_enduring(true)
				log_message.emit("%s used %s and braced for impact." % [unit.display_name, unit.skill.display_name])
				_end_player_turn_if_done(unit)
				return
			_set_phase(BattlePhase.SELECT_SKILL_TARGET)
			_show_skill_targets(unit)
			battle_ui.show_back_only()
		"item":
			_set_phase(BattlePhase.SELECT_ITEM)
			battle_ui.show_item_menu(_inventory, _items)
		"switch":
			if not _can_unit_switch(unit):
				log_message.emit("No spare weapons available.")
				return
			_set_phase(BattlePhase.SELECT_SWITCH_WEAPON)
			battle_ui.show_weapon_switch_menu(GameState.get_switchable_weapons(unit.source_id))
		"retreat":
			if not _allow_retreat:
				log_message.emit("Retreat unavailable.")
				return
			_consume_action(unit)
			if CombatResolver.resolve_retreat(unit):
				_finish_battle(BattleOutcome.ESCAPED)
			else:
				log_message.emit("Retreat failed.")
				_end_player_turn_if_done(unit)


func _on_ui_back_requested() -> void:
	var unit: CombatUnit = _units[_current_unit_id]
	_clear_highlights()
	match _phase:
		BattlePhase.SELECT_MOVE, BattlePhase.PLAYER_ACTION_SUB:
			_set_phase(BattlePhase.PLAYER_MAIN)
			battle_ui.show_main_menu(unit, _allow_retreat)
		BattlePhase.SELECT_ATTACK_TARGET, BattlePhase.SELECT_SKILL_TARGET:
			_set_phase(BattlePhase.PLAYER_ACTION_SUB)
			battle_ui.show_action_submenu(
				unit,
				_allow_retreat,
				_can_unit_attack(unit),
				_can_unit_switch(unit),
			)
		BattlePhase.SELECT_SPELL:
			_set_phase(BattlePhase.PLAYER_ACTION_SUB)
			battle_ui.show_action_submenu(
				unit,
				_allow_retreat,
				_can_unit_attack(unit),
				_can_unit_switch(unit),
			)
		BattlePhase.SELECT_SPELL_TARGET:
			_selected_spell = null
			_set_phase(BattlePhase.SELECT_SPELL)
			battle_ui.show_spell_menu(_build_spell_menu_entries(unit))
		BattlePhase.SELECT_ITEM:
			_set_phase(BattlePhase.PLAYER_ACTION_SUB)
			battle_ui.show_action_submenu(
				unit,
				_allow_retreat,
				_can_unit_attack(unit),
				_can_unit_switch(unit),
			)
		BattlePhase.SELECT_ITEM_TARGET:
			_selected_item_id = ""
			_set_phase(BattlePhase.SELECT_ITEM)
			battle_ui.show_item_menu(_inventory, _items)
		BattlePhase.SELECT_SWITCH_WEAPON:
			_set_phase(BattlePhase.PLAYER_ACTION_SUB)
			battle_ui.show_action_submenu(
				unit,
				_allow_retreat,
				_can_unit_attack(unit),
				_can_unit_switch(unit),
			)


func _on_ui_wait_requested() -> void:
	var unit: CombatUnit = _units[_current_unit_id]
	unit.has_moved = true
	unit.has_acted = true
	log_message.emit("%s waits." % unit.display_name)
	_clear_highlights()
	battle_ui.hide_menus()
	_begin_next_turn()


func _unhandled_input(event: InputEvent) -> void:
	if _phase == BattlePhase.BATTLE_END or _phase == BattlePhase.ENEMY_TURN:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if battle_ui.is_pointer_over_interactive_ui(mouse_event.position):
		return

	var hit := _raycast_at(mouse_event.position)
	if hit.is_empty():
		return

	var collider: Node = hit.collider as Node
	if collider is GridTile:
		_on_tile_clicked((collider as GridTile).cell)
		get_viewport().set_input_as_handled()
		return

	var unit_view := _collider_to_unit_view(collider)
	if unit_view != null:
		_on_unit_clicked(unit_view.runtime_id)
		get_viewport().set_input_as_handled()


func _raycast_at(screen_pos: Vector2) -> Dictionary:
	if camera == null:
		return {}
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_parent().get_world_3d().direct_space_state.intersect_ray(query)


func _collider_to_unit_view(collider: Node) -> UnitView:
	if collider is UnitView:
		return collider as UnitView
	if collider.get_parent() is UnitView:
		return collider.get_parent() as UnitView
	return null


func _on_tile_clicked(cell: Vector2i) -> void:
	match _phase:
		BattlePhase.SELECT_MOVE:
			var unit: CombatUnit = _units[_current_unit_id]
			var reachable := grid_reachable(unit)
			if cell not in reachable:
				return
			_apply_player_move(unit, cell)
		BattlePhase.SELECT_ATTACK_TARGET, BattlePhase.SELECT_SPELL_TARGET, BattlePhase.SELECT_SKILL_TARGET, BattlePhase.SELECT_ITEM_TARGET:
			var occupant_id := _grid.get_occupant(cell)
			if occupant_id.is_empty() or not _units.has(occupant_id):
				return
			_on_unit_clicked(occupant_id)


func _apply_player_move(unit: CombatUnit, cell: Vector2i) -> void:
	_move_unit_to_cell(unit, cell)
	log_message.emit("%s moved." % unit.display_name)
	_clear_highlights()
	_set_phase(BattlePhase.PLAYER_MAIN)
	battle_ui.show_main_menu(unit, _allow_retreat)


func _move_unit_to_cell(unit: CombatUnit, cell: Vector2i) -> void:
	var from := unit.grid_pos
	_grid.move_unit(from, cell, unit.runtime_id)
	unit.grid_pos = cell
	unit.has_moved = true
	var view: UnitView = _unit_views[unit.runtime_id] as UnitView
	view.move_to_world(_grid.grid_to_world(cell) + Vector3(0.0, 0.8, 0.0))


func _on_unit_clicked(runtime_id: String) -> void:
	var target: CombatUnit = _units[runtime_id]
	var actor: CombatUnit = _units[_current_unit_id]
	match _phase:
		BattlePhase.SELECT_ATTACK_TARGET:
			if target.is_ally or target.is_ko:
				return
			if not _can_attack(actor, target):
				return
			await _perform_attack(actor, target)
			_clear_highlights()
			_end_player_turn_if_done(actor)
		BattlePhase.SELECT_SPELL_TARGET:
			if _selected_spell == null:
				return
			if not _is_valid_spell_target(actor, target, _selected_spell):
				return
			_begin_spell_cast(actor, target, _selected_spell)
			get_viewport().set_input_as_handled()
		BattlePhase.SELECT_SKILL_TARGET:
			if target.is_ally or target.is_ko:
				return
			if _grid.manhattan(actor.grid_pos, target.grid_pos) > actor.skill.range_tiles:
				return
			await _perform_skill(actor, target)
			_clear_highlights()
			_end_player_turn_if_done(actor)
		BattlePhase.SELECT_ITEM_TARGET:
			if not _is_valid_item_target(actor, target, _selected_item_id):
				return
			await _perform_item(actor, target, _selected_item_id)
			_selected_item_id = ""
			_clear_highlights()
			_end_player_turn_if_done(actor)


func _on_spell_selected(spell_id: String) -> void:
	_selected_spell = _spells[spell_id] as SpellData
	_set_phase(BattlePhase.SELECT_SPELL_TARGET)
	battle_ui.show_back_only()
	log_message.emit("Select target for %s." % _selected_spell.display_name)
	_show_spell_targets(_units[_current_unit_id], _selected_spell)


func _on_item_selected(item_id: String) -> void:
	var item: ItemData = _items[item_id]
	if item.item_type == "ammo":
		await _perform_ammo_reload(_units[_current_unit_id], item_id)
		return
	if int(_inventory.get(item_id, 0)) <= 0:
		return
	_selected_item_id = item_id
	_set_phase(BattlePhase.SELECT_ITEM_TARGET)
	battle_ui.show_back_only()
	log_message.emit("Select target for %s." % item.display_name)
	_show_item_targets(_units[_current_unit_id], item)


func _on_turn_order_changed(order: Array[String]) -> void:
	battle_ui.update_turn_order(order, _units)
	battle_ui.update_ally_status(_ally_units(), _current_unit_id)


func _move_unit(unit: CombatUnit, cell: Vector2i) -> void:
	_move_unit_to_cell(unit, cell)
	log_message.emit("%s moved." % unit.display_name)
	await get_tree().create_timer(0.2).timeout


func _begin_spell_cast(caster: CombatUnit, target: CombatUnit, spell: SpellData) -> void:
	var effective_stats: Dictionary = GameState.get_effective_spell_stats(caster.source_id, spell.id)
	var mp_cost := int(effective_stats.get("mp_cost", spell.mp_cost))
	if not caster.spend_mp(mp_cost):
		log_message.emit("Not enough MP.")
		return
	caster.set_pending_spell(spell.id, target.runtime_id)
	_consume_action(caster)
	log_message.emit(
		"%s begins casting %s on %s." % [caster.display_name, spell.display_name, target.display_name]
	)
	_selected_spell = null
	_clear_highlights()
	battle_ui.hide_menus()
	_begin_next_turn()


func _unleash_pending_spell(caster: CombatUnit) -> void:
	var spell_id: String = caster.pending_spell_id
	var target_id: String = caster.pending_spell_target_id
	caster.clear_pending_spell()
	if not _spells.has(spell_id):
		return
	var spell: SpellData = _spells[spell_id] as SpellData
	if not _units.has(target_id):
		log_message.emit("%s's %s fizzled." % [caster.display_name, spell.display_name])
		await get_tree().create_timer(0.25).timeout
		return
	var target: CombatUnit = _units[target_id]
	if not _is_valid_spell_target(caster, target, spell):
		log_message.emit("%s's %s fizzled." % [caster.display_name, spell.display_name])
		await get_tree().create_timer(0.25).timeout
		return
	log_message.emit("%s unleashes %s!" % [caster.display_name, spell.display_name])
	_apply_spell_effect(caster, target, spell)
	await get_tree().create_timer(0.25).timeout
	_check_battle_end()


func _apply_spell_effect(caster: CombatUnit, target: CombatUnit, spell: SpellData) -> void:
	var effective_stats: Dictionary = GameState.get_effective_spell_stats(caster.source_id, spell.id)
	var tier_base := int(effective_stats.get("tier_base", spell.tier_base))
	var result := CombatResolver.resolve_spell(caster, target, spell, tier_base)
	log_message.emit(str(result["message"]))
	if result["hit"]:
		if spell.healing:
			target.heal(int(result["amount"]))
		else:
			target.apply_damage(int(result["amount"]))
			_handle_combat_damage(target)
	if caster.is_ally:
		var xp_result: Dictionary = GameState.award_spell_mastery_xp(caster.source_id, spell.id)
		if not str(xp_result.get("message", "")).is_empty():
			log_message.emit(str(xp_result.get("message", "")))


func _on_weapon_selected(weapon_id: String) -> void:
	var unit: CombatUnit = _units[_current_unit_id]
	if unit.has_acted:
		log_message.emit("Already acted.")
		return
	var switch_result: Dictionary = GameState.switch_weapon(unit.source_id, weapon_id)
	log_message.emit(str(switch_result.get("message", "Switch failed.")))
	if not bool(switch_result.get("ok", false)):
		return
	_consume_action(unit)
	_sync_ally_weapon_stats(unit)
	await get_tree().create_timer(0.25).timeout
	_end_player_turn_if_done(unit)


func _perform_ammo_reload(actor: CombatUnit, item_id: String) -> void:
	if actor.has_acted:
		log_message.emit("Already acted.")
		return
	var item: ItemData = _items[item_id]
	if item.item_type != "ammo":
		return
	if not GameState.can_reload_with_ammo(actor.source_id, item_id):
		log_message.emit("Cannot reload with this ammo.")
		return
	_consume_action(actor)
	var reload_result: Dictionary = GameState.reload_equipped_weapon(actor.source_id)
	log_message.emit(str(reload_result.get("message", "Reload failed.")))
	if bool(reload_result.get("ok", false)):
		_inventory = GameState.inventory.duplicate()
		_sync_ally_weapon_stats(actor)
	await get_tree().create_timer(0.25).timeout
	_end_player_turn_if_done(actor)


func _perform_attack(
	attacker: CombatUnit,
	defender: CombatUnit,
	enemy_action: EnemyActionData = null,
) -> void:
	var broke := false
	var break_message := ""
	if attacker.is_ally:
		if not GameState.can_attack_with_equipped_weapon(attacker.source_id):
			log_message.emit("Cannot attack without a usable weapon.")
			return
		var resource_result: Dictionary = GameState.consume_attack_resource(attacker.source_id)
		if not bool(resource_result.get("ok", false)):
			log_message.emit(str(resource_result.get("message", "Cannot attack.")))
			return
		broke = bool(resource_result.get("broke", false))
		break_message = str(resource_result.get("message", ""))
	_consume_action(attacker)
	var mastery_level := 1
	var weapon_class := ""
	if attacker.is_ally and attacker.weapon != null:
		weapon_class = attacker.weapon.weapon_class
		mastery_level = GameState.get_weapon_mastery_level(attacker.source_id, weapon_class)
	var result := CombatResolver.resolve_physical_attack(attacker, defender, mastery_level, enemy_action)
	log_message.emit(str(result["message"]))
	if result["hit"]:
		var hit_count := int(result.get("hit_count", 1))
		for _hit_index: int in range(maxi(hit_count, 1)):
			defender.apply_damage(int(result["damage"]))
		_handle_combat_damage(defender)
	if attacker.is_ally and not weapon_class.is_empty():
		var xp_result: Dictionary = GameState.award_weapon_mastery_xp(attacker.source_id, weapon_class)
		if not str(xp_result.get("message", "")).is_empty():
			log_message.emit(str(xp_result.get("message", "")))
	if broke:
		log_message.emit(break_message)
		_sync_ally_weapon_stats(attacker)
	await get_tree().create_timer(0.25).timeout
	_check_battle_end()


func _perform_enemy_debuff(
	actor: CombatUnit,
	action: EnemyActionData,
	targets: Array,
) -> void:
	_consume_action(actor)
	var target_units: Array[CombatUnit] = []
	for target_variant: Variant in targets:
		target_units.append(target_variant as CombatUnit)
	var result := CombatResolver.resolve_enemy_debuff(action, target_units)
	if str(result.get("message", "")).is_empty():
		log_message.emit("%s used %s, but it had no effect." % [actor.display_name, action.display_name])
	else:
		log_message.emit("%s used %s. %s" % [actor.display_name, action.display_name, str(result["message"])])
	await get_tree().create_timer(0.25).timeout
	_check_battle_end()


func _perform_skill(attacker: CombatUnit, defender: CombatUnit) -> void:
	_consume_action(attacker)
	var result := CombatResolver.resolve_skill(attacker, defender)
	log_message.emit(str(result["message"]))
	if bool(result["hit"]) and int(result.get("damage", 0)) > 0:
		defender.apply_damage(int(result["damage"]))
		_handle_combat_damage(defender)
	await get_tree().create_timer(0.25).timeout
	_check_battle_end()


func _perform_item(actor: CombatUnit, target: CombatUnit, item_id: String) -> void:
	var item: ItemData = _items[item_id]
	if int(_inventory.get(item_id, 0)) <= 0:
		return
	_consume_action(actor)
	_inventory[item_id] = int(_inventory[item_id]) - 1
	if item.revive and target.is_ko:
		target.revive_with_hp(item.heal_amount)
		log_message.emit("%s revived %s." % [actor.display_name, target.display_name])
	elif not target.is_ko:
		target.heal(item.heal_amount)
		log_message.emit("%s used %s on %s." % [actor.display_name, item.display_name, target.display_name])
	else:
		log_message.emit("Revive failed.")
	await get_tree().create_timer(0.25).timeout


func _consume_action(unit: CombatUnit) -> void:
	unit.has_acted = true


func _end_player_turn_if_done(unit: CombatUnit) -> void:
	_clear_highlights()
	battle_ui.hide_menus()
	if unit.has_moved and unit.has_acted:
		_begin_next_turn()
	elif unit.has_acted:
		_set_phase(BattlePhase.PLAYER_MAIN)
		battle_ui.show_main_menu(unit, _allow_retreat)
	else:
		_set_phase(BattlePhase.PLAYER_MAIN)
		battle_ui.show_main_menu(unit, _allow_retreat)
		if not unit.has_moved:
			log_message.emit("You may still move.")


func _show_reachable_tiles(unit: CombatUnit) -> void:
	_clear_highlights()
	for cell: Vector2i in grid_reachable(unit):
		_tile_views[cell].set_move_highlight(true)


func _show_attack_targets(unit: CombatUnit) -> void:
	_clear_highlights()
	for enemy: CombatUnit in _enemy_units():
		if enemy.is_ko:
			continue
		if _can_attack(unit, enemy):
			_tile_views[enemy.grid_pos].set_target_highlight(true)


func _can_attack(attacker: CombatUnit, target: CombatUnit) -> bool:
	return _grid.can_attack_cell(attacker.grid_pos, target.grid_pos, attacker.attack_range)


func _can_unit_attack(unit: CombatUnit) -> bool:
	if unit.is_ally and not GameState.can_attack_with_equipped_weapon(unit.source_id):
		return false
	return _has_attack_target(unit)


func _can_unit_switch(unit: CombatUnit) -> bool:
	return not GameState.get_switchable_weapons(unit.source_id).is_empty()


func _build_spell_menu_entries(unit: CombatUnit) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for spell_id: String in GameState.get_unlocked_spells_for_character(unit.source_id):
		if not _spells.has(spell_id):
			continue
		var spell: SpellData = _spells[spell_id] as SpellData
		var effective_stats: Dictionary = GameState.get_effective_spell_stats(unit.source_id, spell_id)
		entries.append({
			"spell_id": spell_id,
			"label": "%s T%d (MP %d)" % [
				spell.display_name,
				int(effective_stats.get("tier", 1)),
				int(effective_stats.get("mp_cost", spell.mp_cost)),
			],
		})
	return entries


func _sync_ally_weapon_stats(unit: CombatUnit) -> void:
	var characters := DataLoader.load_characters()
	if not characters.has(unit.source_id):
		return
	var character: CharacterData = characters[unit.source_id]
	var loadout: Dictionary = GameState.get_loadout(unit.source_id)
	var snapshot := GameState.get_member_snapshot(unit.source_id)
	var weapon: WeaponData = PartyStatsHelper.get_equipped_weapon(loadout)
	var effective_stats := PartyStatsHelper.get_effective_stats(character, loadout, snapshot)
	unit.weapon = weapon
	unit.stats = effective_stats
	unit.attack_range = weapon.attack_range if weapon != null else 1


func _has_attack_target(unit: CombatUnit) -> bool:
	for enemy: CombatUnit in _enemy_units():
		if enemy.is_ko:
			continue
		if _can_attack(unit, enemy):
			return true
	return false


func _show_skill_targets(unit: CombatUnit) -> void:
	_clear_highlights()
	for enemy: CombatUnit in _enemy_units():
		if enemy.is_ko:
			continue
		if _grid.manhattan(unit.grid_pos, enemy.grid_pos) <= unit.skill.range_tiles:
			_tile_views[enemy.grid_pos].set_target_highlight(true)


func _show_spell_targets(caster: CombatUnit, spell: SpellData) -> void:
	_clear_highlights()
	for unit: CombatUnit in _all_units():
		if not _is_valid_spell_target(caster, unit, spell):
			continue
		_tile_views[unit.grid_pos].set_target_highlight(true)


func _show_item_targets(actor: CombatUnit, item: ItemData) -> void:
	_clear_highlights()
	for ally: CombatUnit in _ally_units():
		if not _is_valid_item_target(actor, ally, item.id):
			continue
		_tile_views[ally.grid_pos].set_target_highlight(true)


func _clear_highlights() -> void:
	for tile: StaticBody3D in _tile_views.values():
		tile.reset_highlight()


func grid_reachable(unit: CombatUnit) -> Array[Vector2i]:
	var row_bounds := _get_movement_row_bounds(unit)
	return _grid.get_reachable_cells(
		unit.grid_pos, unit.move_range, unit.runtime_id, row_bounds.x, row_bounds.y
	)


func _get_movement_row_bounds(unit: CombatUnit) -> Vector2i:
	# Allies advance toward +y; enemies advance toward -y.
	# Units may not enter an opponent's row or move past it.
	if unit.is_ally:
		var front_enemy_row := BattleGrid.SIZE
		for enemy: CombatUnit in _enemy_units():
			front_enemy_row = mini(front_enemy_row, enemy.grid_pos.y)
		if front_enemy_row >= BattleGrid.SIZE:
			return Vector2i(0, BattleGrid.SIZE - 1)
		return Vector2i(0, front_enemy_row - 1)

	var front_ally_row := -1
	for ally: CombatUnit in _ally_units():
		front_ally_row = maxi(front_ally_row, ally.grid_pos.y)
	if front_ally_row < 0:
		return Vector2i(0, BattleGrid.SIZE - 1)
	return Vector2i(front_ally_row + 1, BattleGrid.SIZE - 1)


func _is_valid_spell_target(_caster: CombatUnit, target: CombatUnit, spell: SpellData) -> bool:
	if spell.healing:
		return target.is_ally and not target.is_ko
	if spell.targets == "enemy":
		return not target.is_ally and not target.is_ko
	return false


func _is_valid_item_target(actor: CombatUnit, target: CombatUnit, item_id: String) -> bool:
	var item: ItemData = _items[item_id]
	if not target.is_ally:
		return false
	if _grid.manhattan(actor.grid_pos, target.grid_pos) > item.range_tiles:
		return false
	if item.revive:
		return target.is_ko
	return not target.is_ko


func _check_battle_end() -> bool:
	var allies_alive := false
	for unit: CombatUnit in _ally_units():
		if unit.can_act():
			allies_alive = true
			break
	var enemies_alive := false
	for unit: CombatUnit in _enemy_units():
		if unit.can_act():
			enemies_alive = true
			break
	if not enemies_alive:
		_finish_battle(BattleOutcome.VICTORY)
		return true
	if not allies_alive:
		_finish_battle(BattleOutcome.DEFEAT)
		return true
	return false


func _finish_battle(outcome: BattleOutcome) -> void:
	if _phase == BattlePhase.BATTLE_END:
		return
	_outcome = outcome
	GameState.update_party_from_battle(_ally_units(), _inventory)
	GameState.resolve_battle(outcome)
	_set_phase(BattlePhase.BATTLE_END)
	_current_unit_id = ""
	_update_turn_highlight()
	battle_ui.hide_menus()
	_clear_highlights()
	var from_explore := GameState.battle_source == GameState.BattleSource.EXPLORE
	result_panel.show_result(outcome, from_explore)
	battle_finished.emit(outcome)


func _on_restart_requested() -> void:
	get_tree().reload_current_scene()


func _on_continue_requested() -> void:
	if GameState.has_pending_level_ups():
		_show_next_level_up()
		return
	SceneTransition.go_to_explore()


func _show_next_level_up() -> void:
	result_panel.visible = false
	var character_id := GameState.peek_level_up_character()
	level_up_panel.show_level_up(character_id)


func _on_level_up_confirmed() -> void:
	if GameState.has_pending_level_ups():
		_show_next_level_up()
	else:
		SceneTransition.go_to_explore()


func _on_load_save_requested() -> void:
	_open_load_panel()


func _on_load_autosave_requested() -> void:
	if GameState.load_autosave():
		await SceneTransition.go_to_explore()
	else:
		_open_load_panel(GameState.last_save_error)


func _on_main_menu_requested() -> void:
	await SceneTransition.go_to_main_menu()


func _open_load_panel(error_message: String = "") -> void:
	if _save_panel == null:
		_save_panel = SAVE_SLOT_PANEL_SCENE.instantiate() as Control
		$"../UI".add_child(_save_panel)
		_save_panel.load_completed.connect(_on_battle_save_loaded)
		_save_panel.closed.connect(func() -> void: _save_panel.visible = false)
	_save_panel.open_load_mode(true)
	if not error_message.is_empty():
		_save_panel.show_error(error_message)


func _on_battle_save_loaded() -> void:
	await SceneTransition.go_to_explore()


func _set_phase(new_phase: BattlePhase) -> void:
	_phase = new_phase
	phase_changed.emit(new_phase)


func _update_turn_highlight() -> void:
	for runtime_id: String in _unit_views.keys():
		var view: UnitView = _unit_views[runtime_id] as UnitView
		view.set_turn_active(runtime_id == _current_unit_id)
	battle_ui.update_ally_status(_ally_units(), _current_unit_id)


func _on_unit_ko_changed(is_ko: bool, runtime_id: String) -> void:
	if is_ko:
		_schedule_enemy_removal(runtime_id)


func _handle_combat_damage(unit: CombatUnit) -> void:
	if unit.is_ko and not unit.is_ally:
		_schedule_enemy_removal(unit.runtime_id)


func _schedule_enemy_removal(runtime_id: String) -> void:
	if _scheduled_enemy_removals.has(runtime_id):
		return
	if not _units.has(runtime_id):
		return
	var unit: CombatUnit = _units[runtime_id]
	if unit.is_ally or not unit.is_ko:
		return
	_scheduled_enemy_removals[runtime_id] = true
	var timer := get_tree().create_timer(CombatConstants.ENEMY_REMOVE_DELAY)
	timer.timeout.connect(_remove_enemy_from_board.bind(runtime_id), CONNECT_ONE_SHOT)


func _remove_enemy_from_board(runtime_id: String) -> void:
	_scheduled_enemy_removals.erase(runtime_id)
	if not _units.has(runtime_id):
		return
	var unit: CombatUnit = _units[runtime_id]
	if not unit.is_ko or unit.is_ally:
		return
	_grid.set_occupant(unit.grid_pos, "")
	if _unit_views.has(runtime_id):
		var view: UnitView = _unit_views[runtime_id] as UnitView
		view.queue_free()
		_unit_views.erase(runtime_id)
	_units.erase(runtime_id)
	_update_turn_highlight()
	_check_battle_end()


func _all_units() -> Array[CombatUnit]:
	var list: Array[CombatUnit] = []
	for unit: CombatUnit in _units.values():
		list.append(unit)
	return list


func _living_units() -> Array[CombatUnit]:
	var list: Array[CombatUnit] = []
	for unit: CombatUnit in _units.values():
		if unit.can_act():
			list.append(unit)
	return list


func _ally_units() -> Array[CombatUnit]:
	var list: Array[CombatUnit] = []
	for unit: CombatUnit in _units.values():
		if unit.is_ally:
			list.append(unit)
	return list


func _enemy_units() -> Array[CombatUnit]:
	var list: Array[CombatUnit] = []
	for unit: CombatUnit in _units.values():
		if not unit.is_ally:
			list.append(unit)
	return list
