class_name BattleGrid
extends RefCounted

const SIZE: int = CombatConstants.GRID_SIZE

var _occupants: Dictionary = {}


func clear() -> void:
	_occupants.clear()


func is_in_bounds(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < SIZE
		and cell.y < SIZE
	)


func get_occupant(cell: Vector2i) -> String:
	if not is_in_bounds(cell):
		return ""
	return str(_occupants.get(cell, ""))


func set_occupant(cell: Vector2i, runtime_id: String) -> void:
	if runtime_id.is_empty():
		_occupants.erase(cell)
	else:
		_occupants[cell] = runtime_id


func move_unit(from_cell: Vector2i, to_cell: Vector2i, runtime_id: String) -> void:
	set_occupant(from_cell, "")
	set_occupant(to_cell, runtime_id)


func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func is_melee_adjacent(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	return chebyshev_distance(from_cell, to_cell) == 1


func is_straight_or_diagonal_line(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var dx := absi(from_cell.x - to_cell.x)
	var dy := absi(from_cell.y - to_cell.y)
	if dx == 0 and dy == 0:
		return false
	return dx == 0 or dy == 0 or dx == dy


func get_line_cells_between(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not is_straight_or_diagonal_line(from_cell, to_cell):
		return cells
	var step := Vector2i(signi(to_cell.x - from_cell.x), signi(to_cell.y - from_cell.y))
	var current := from_cell + step
	while current != to_cell:
		cells.append(current)
		current += step
	return cells


func is_attack_path_clear(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	for cell: Vector2i in get_line_cells_between(from_cell, to_cell):
		if not get_occupant(cell).is_empty():
			return false
	return true


func can_attack_cell(from_cell: Vector2i, to_cell: Vector2i, attack_range: int) -> bool:
	if from_cell == to_cell:
		return false
	if attack_range <= 1:
		return is_melee_adjacent(from_cell, to_cell)
	if not is_straight_or_diagonal_line(from_cell, to_cell):
		return false
	if chebyshev_distance(from_cell, to_cell) > attack_range:
		return false
	return is_attack_path_clear(from_cell, to_cell)


func get_reachable_cells(
	origin: Vector2i,
	move_range: int,
	moving_unit_id: String,
	row_min: int = 0,
	row_max: int = SIZE - 1
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [origin]
	visited[origin] = 0

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var distance: int = int(visited[current])
		if distance > 0 and current.y >= row_min and current.y <= row_max:
			result.append(current)
		if distance >= move_range:
			continue
		for offset: Vector2i in _neighbor_offsets():
			var next: Vector2i = current + offset
			if not is_in_bounds(next):
				continue
			if next.y < row_min or next.y > row_max:
				continue
			if visited.has(next):
				continue
			var occupant := get_occupant(next)
			if not occupant.is_empty() and occupant != moving_unit_id:
				continue
			visited[next] = distance + 1
			queue.append(next)

	return result


func get_cells_in_range(origin: Vector2i, range_tiles: int, include_origin: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in SIZE:
		for x: int in SIZE:
			var cell := Vector2i(x, y)
			var distance := manhattan(origin, cell)
			if distance <= range_tiles and (include_origin or distance > 0):
				result.append(cell)
	return result


func grid_to_world(cell: Vector2i) -> Vector3:
	var offset := float(SIZE - 1) * CombatConstants.TILE_SIZE * 0.5
	return Vector3(
		float(cell.x) * CombatConstants.TILE_SIZE - offset,
		0.0,
		float(cell.y) * CombatConstants.TILE_SIZE - offset
	)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	var offset := float(SIZE - 1) * CombatConstants.TILE_SIZE * 0.5
	var x := int(round((world_pos.x + offset) / CombatConstants.TILE_SIZE))
	var y := int(round((world_pos.z + offset) / CombatConstants.TILE_SIZE))
	return Vector2i(x, y)


func _neighbor_offsets() -> Array[Vector2i]:
	return [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
