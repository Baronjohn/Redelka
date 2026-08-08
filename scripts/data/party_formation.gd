class_name PartyFormation
extends RefCounted

const ROW_MIN: int = 0
const ROW_MAX: int = 1


static func menu_to_battle(cell: Vector2i) -> Vector2i:
	return Vector2i(CombatConstants.GRID_SIZE - 1 - cell.x, cell.y)


static func battle_to_menu(cell: Vector2i) -> Vector2i:
	return menu_to_battle(cell)


static func is_valid_cell(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < CombatConstants.GRID_SIZE
		and cell.y >= ROW_MIN
		and cell.y <= ROW_MAX
	)


static func parse_positions(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for character_id: String in raw.keys():
		var pos_array: Array = raw[character_id] as Array
		if pos_array.size() < 2:
			continue
		var cell := Vector2i(int(pos_array[0]), int(pos_array[1]))
		if is_valid_cell(cell):
			result[character_id] = cell
	return result


static func serialize_positions(formation: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for character_id: String in formation.keys():
		var cell: Vector2i = formation[character_id]
		result[character_id] = [cell.x, cell.y]
	return result


static func find_character_at(formation: Dictionary, cell: Vector2i) -> String:
	for character_id: String in formation.keys():
		if formation[character_id] == cell:
			return character_id
	return ""


static func assign_position(
	formation: Dictionary,
	character_id: String,
	cell: Vector2i,
) -> Dictionary:
	if character_id.is_empty():
		return {"ok": false, "message": "No character selected."}
	if not is_valid_cell(cell):
		return {"ok": false, "message": "Only the first two rows can be used."}
	var updated := formation.duplicate()
	var occupant := find_character_at(updated, cell)
	var previous: Vector2i = updated.get(character_id, Vector2i(-1, -1))
	if occupant == character_id:
		return {"ok": true, "message": "%s is already there." % character_id, "formation": updated}
	if not occupant.is_empty() and previous.x >= 0:
		updated[occupant] = previous
	elif not occupant.is_empty():
		updated.erase(occupant)
	updated[character_id] = cell
	return {"ok": true, "message": "Formation updated.", "formation": updated}


static func clear_position(formation: Dictionary, character_id: String) -> Dictionary:
	var updated := formation.duplicate()
	updated.erase(character_id)
	return updated


static func build_spawn_entries(formation: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for character_id: String in formation.keys():
		var menu_cell: Vector2i = formation[character_id]
		var battle_cell := menu_to_battle(menu_cell)
		entries.append({
			"character_id": character_id,
			"position": [battle_cell.x, battle_cell.y],
		})
	return entries
