class_name DataLoader
extends RefCounted

static func load_json_array(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open JSON: %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		return parsed as Array
	push_error("Invalid JSON array: %s" % path)
	return []


static func load_weapons() -> Dictionary:
	var result: Dictionary = {}
	for entry: Variant in load_json_array("res://data/weapons.json"):
		var weapon := WeaponData.from_dict(entry as Dictionary)
		result[weapon.id] = weapon
	return result


static func load_spells() -> Dictionary:
	var result: Dictionary = {}
	for entry: Variant in load_json_array("res://data/spells.json"):
		var spell := SpellData.from_dict(entry as Dictionary)
		result[spell.id] = spell
	return result


static func load_skills() -> Dictionary:
	var result: Dictionary = {}
	for entry: Variant in load_json_array("res://data/skills.json"):
		var skill := SkillData.from_dict(entry as Dictionary)
		result[skill.id] = skill
	return result


static func load_items() -> Dictionary:
	var result: Dictionary = {}
	for entry: Variant in load_json_array("res://data/items.json"):
		var item := ItemData.from_dict(entry as Dictionary)
		result[item.id] = item
	return result


static func load_characters() -> Dictionary:
	var result: Dictionary = {}
	for entry: Variant in load_json_array("res://data/characters.json"):
		var character := CharacterData.from_dict(entry as Dictionary)
		result[character.id] = character
	return result


static func load_enemies() -> Dictionary:
	var result: Dictionary = {}
	for entry: Variant in load_json_array("res://data/enemies.json"):
		var enemy := EnemyData.from_dict(entry as Dictionary)
		result[enemy.id] = enemy
	return result


static func load_encounter(encounter_id: String) -> EncounterData:
	for entry: Variant in load_json_array("res://data/encounters.json"):
		var data := entry as Dictionary
		if str(data.get("id", "")) == encounter_id:
			return EncounterData.from_dict(data)
	push_error("Encounter not found: %s" % encounter_id)
	return EncounterData.new()


static func load_area(area_id: String) -> AreaData:
	for entry: Variant in load_json_array("res://data/areas.json"):
		var data := entry as Dictionary
		if str(data.get("id", "")) == area_id:
			return AreaData.from_dict(data)
	push_error("Area not found: %s" % area_id)
	return AreaData.new()
