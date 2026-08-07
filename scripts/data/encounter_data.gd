class_name EncounterData
extends RefCounted

var id: String = ""
var display_name: String = ""
var area_texture: String = ""
var allow_retreat: bool = true
var party_inventory: Dictionary = {}
var allies: Array[Dictionary] = []
var enemies: Array[Dictionary] = []


static func from_dict(data: Dictionary) -> EncounterData:
	var encounter := EncounterData.new()
	encounter.id = str(data.get("id", ""))
	encounter.display_name = str(data.get("name", ""))
	encounter.area_texture = str(data.get("area_texture", ""))
	encounter.allow_retreat = bool(data.get("allow_retreat", true))
	encounter.party_inventory = data.get("party_inventory", {}) as Dictionary
	for ally_entry: Variant in data.get("allies", []) as Array:
		encounter.allies.append(ally_entry as Dictionary)
	for enemy_entry: Variant in data.get("enemies", []) as Array:
		encounter.enemies.append(enemy_entry as Dictionary)
	return encounter
