class_name TurnQueue
extends RefCounted

var _entries: Array[String] = []
var _index: int = 0


func build_queue(units: Array[CombatUnit]) -> void:
	_entries.clear()
	_index = 0
	var living: Array[CombatUnit] = []
	for unit: CombatUnit in units:
		if unit.can_act():
			living.append(unit)
	if living.is_empty():
		return

	var average_agi := _average_agility(living)
	var weighted: Array[Dictionary] = []
	for unit: CombatUnit in living:
		if unit.is_ko:
			continue
		var weight := unit.get_agility()
		weighted.append({"id": unit.runtime_id, "weight": weight})
		if float(unit.get_agility()) >= average_agi * CombatConstants.EXTRA_TURN_AGI_FACTOR:
			weighted.append({"id": unit.runtime_id, "weight": weight - 1})

	weighted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["weight"]) > int(b["weight"])
	)

	for entry: Dictionary in weighted:
		_entries.append(str(entry["id"]))


func peek_current() -> String:
	if _entries.is_empty():
		return ""
	return _entries[_index % _entries.size()]


func advance() -> String:
	if _entries.is_empty():
		return ""
	var current := peek_current()
	_index = (_index + 1) % _entries.size()
	return current


func get_display_order() -> Array[String]:
	var order: Array[String] = []
	if _entries.is_empty():
		return order
	for i: int in _entries.size():
		order.append(_entries[(_index + i) % _entries.size()])
	return order


func _average_agility(units: Array[CombatUnit]) -> float:
	if units.is_empty():
		return 1.0
	var total := 0
	for unit: CombatUnit in units:
		total += unit.get_agility()
	return float(total) / float(units.size())
