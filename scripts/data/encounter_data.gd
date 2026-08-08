class_name EncounterData
extends RefCounted

var id: String = ""
var display_name: String = ""
var area_texture: String = ""
var allow_retreat: bool = true
var enemies: Array[Dictionary] = []
var spell_unlocks: Array[Dictionary] = []


static func from_dict(data: Dictionary) -> EncounterData:
	var encounter := EncounterData.new()
	encounter.id = str(data.get("id", ""))
	encounter.display_name = str(data.get("name", ""))
	encounter.area_texture = str(data.get("area_texture", ""))
	encounter.allow_retreat = bool(data.get("allow_retreat", true))
	for enemy_entry: Variant in data.get("enemies", []) as Array:
		encounter.enemies.append(enemy_entry as Dictionary)
	for unlock_entry: Variant in data.get("spell_unlocks", []) as Array:
		encounter.spell_unlocks.append(unlock_entry as Dictionary)
	return encounter
