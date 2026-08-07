class_name CharacterData
extends RefCounted

var id: String = ""
var display_name: String = ""
var move_range: int = 2
var weapon_id: String = ""
var skill_id: String = ""
var stats: StatBlock = StatBlock.new()


static func from_dict(data: Dictionary) -> CharacterData:
	var character := CharacterData.new()
	character.id = str(data.get("id", ""))
	character.display_name = str(data.get("name", ""))
	character.move_range = int(data.get("move_range", 2))
	character.weapon_id = str(data.get("weapon_id", ""))
	character.skill_id = str(data.get("skill_id", ""))
	character.stats = StatBlock.from_dict(data.get("stats", {}) as Dictionary)
	return character
