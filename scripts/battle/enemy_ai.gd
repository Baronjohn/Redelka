class_name EnemyAI
extends RefCounted


static func roll_action(actions: Array[EnemyActionData]) -> EnemyActionData:
	if actions.is_empty():
		return null
	var roll := randi_range(1, 100)
	var cumulative := 0
	for action: EnemyActionData in actions:
		cumulative += action.chance
		if roll <= cumulative:
			return action
	return actions[actions.size() - 1]


static func choose_action(
	actor: CombatUnit,
	selected_action: EnemyActionData,
	allies: Array[CombatUnit],
	grid: BattleGrid,
	row_min: int = 0,
	row_max: int = BattleGrid.SIZE - 1,
) -> Dictionary:
	if selected_action == null:
		return {"type": "wait"}

	var living_allies: Array[CombatUnit] = []
	for unit: CombatUnit in allies:
		if unit.can_act():
			living_allies.append(unit)
	if living_allies.is_empty():
		return {"type": "wait"}

	var target := _nearest_unit(actor, living_allies)

	if selected_action.action_type == EnemyActionData.TYPE_DEBUFF:
		var debuff_targets := _allies_in_range(actor, living_allies, grid, selected_action.range_tiles)
		if not debuff_targets.is_empty() and not actor.has_acted:
			return {
				"type": "debuff",
				"action_id": selected_action.id,
				"targets": debuff_targets,
			}
		if not actor.has_moved:
			var destination := _step_toward(actor, target, grid, row_min, row_max)
			if destination != actor.grid_pos:
				return {"type": "move", "cell": destination}
		debuff_targets = _allies_in_range(actor, living_allies, grid, selected_action.range_tiles)
		if not debuff_targets.is_empty() and not actor.has_acted:
			return {
				"type": "debuff",
				"action_id": selected_action.id,
				"targets": debuff_targets,
			}
		return {"type": "wait"}

	if not actor.has_acted and grid.can_attack_cell(
		actor.grid_pos, target.grid_pos, selected_action.range_tiles
	):
		return {
			"type": "attack",
			"action_id": selected_action.id,
			"target_id": target.runtime_id,
		}

	if not actor.has_moved:
		var destination := _step_toward(actor, target, grid, row_min, row_max)
		if destination != actor.grid_pos:
			return {"type": "move", "cell": destination}

	if (
		not actor.has_acted
		and grid.can_attack_cell(actor.grid_pos, target.grid_pos, selected_action.range_tiles)
	):
		return {
			"type": "attack",
			"action_id": selected_action.id,
			"target_id": target.runtime_id,
		}

	return {"type": "wait"}


static func get_action(enemy: EnemyData, action_id: String) -> EnemyActionData:
	for action: EnemyActionData in enemy.actions:
		if action.id == action_id:
			return action
	if not enemy.actions.is_empty():
		return enemy.actions[0]
	return null


static func _allies_in_range(
	actor: CombatUnit,
	allies: Array[CombatUnit],
	grid: BattleGrid,
	range_tiles: int,
) -> Array[CombatUnit]:
	var result: Array[CombatUnit] = []
	for ally: CombatUnit in allies:
		if not ally.can_act():
			continue
		if grid.manhattan(actor.grid_pos, ally.grid_pos) <= range_tiles:
			result.append(ally)
	return result


static func _nearest_unit(source: CombatUnit, targets: Array[CombatUnit]) -> CombatUnit:
	var best: CombatUnit = targets[0]
	var best_distance := 999
	for unit: CombatUnit in targets:
		var distance := absi(source.grid_pos.x - unit.grid_pos.x) + absi(source.grid_pos.y - unit.grid_pos.y)
		if distance < best_distance:
			best_distance = distance
			best = unit
	return best


static func _step_toward(
	actor: CombatUnit,
	target: CombatUnit,
	grid: BattleGrid,
	row_min: int,
	row_max: int,
) -> Vector2i:
	var reachable := grid.get_reachable_cells(
		actor.grid_pos, actor.move_range, actor.runtime_id, row_min, row_max
	)
	if reachable.is_empty():
		return actor.grid_pos

	var best := actor.grid_pos
	var best_distance := absi(actor.grid_pos.x - target.grid_pos.x) + absi(actor.grid_pos.y - target.grid_pos.y)
	for cell: Vector2i in reachable:
		var distance := absi(cell.x - target.grid_pos.x) + absi(cell.y - target.grid_pos.y)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best
