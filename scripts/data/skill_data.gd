class_name SkillData
extends RefCounted

var id: String = ""
var display_name: String = ""
var character_id: String = ""
var damage_bonus: int = 0
var mp_cost: int = 0
var range_tiles: int = 1
var description: String = ""
var mp_restore: int = 0


static func from_dict(data: Dictionary) -> SkillData:
	var skill := SkillData.new()
	skill.id = str(data.get("id", ""))
	skill.display_name = str(data.get("name", ""))
	skill.character_id = str(data.get("character_id", ""))
	skill.damage_bonus = int(data.get("damage_bonus", 0))
	skill.mp_cost = int(data.get("mp_cost", 0))
	skill.range_tiles = int(data.get("range", 1))
	skill.description = str(data.get("description", ""))
	skill.mp_restore = int(data.get("mp_restore", 0))
	return skill
