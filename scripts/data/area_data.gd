class_name AreaData
extends RefCounted

var id: String = ""
var display_name: String = ""
var scene_path: String = ""
var default_spawn: Vector3 = Vector3.ZERO
var checkpoint_spawn: Vector3 = Vector3.ZERO
var default_encounter_id: String = ""
var enemies: Array[Dictionary] = []


static func from_dict(data: Dictionary) -> AreaData:
	var area := new()
	area.id = str(data.get("id", ""))
	area.display_name = str(data.get("name", area.id))
	area.scene_path = str(data.get("scene_path", ""))
	var default_array: Array = data.get("default_spawn", [0, 0, 0]) as Array
	area.default_spawn = _array_to_vector3(default_array)
	var checkpoint_array: Array = data.get("checkpoint_spawn", [0, 0, 0]) as Array
	area.checkpoint_spawn = _array_to_vector3(checkpoint_array)
	area.default_encounter_id = str(data.get("default_encounter_id", "test_4v3"))
	for enemy_entry: Variant in data.get("enemies", []) as Array:
		area.enemies.append(enemy_entry as Dictionary)
	return area


static func _array_to_vector3(values: Array) -> Vector3:
	if values.size() < 3:
		return Vector3.ZERO
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
