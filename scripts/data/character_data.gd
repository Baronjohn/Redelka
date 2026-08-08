class_name CharacterData
extends RefCounted

var id: String = ""
var display_name: String = ""
var move_range: int = 2
var skill_id: String = ""
var portrait_path: String = ""
var model_path: String = ""
var description: Dictionary = {}
var level_growth: Dictionary = {}
var stats: StatBlock = StatBlock.new()


static func from_dict(data: Dictionary) -> CharacterData:
	var character := CharacterData.new()
	character.id = str(data.get("id", ""))
	character.display_name = str(data.get("name", ""))
	character.move_range = int(data.get("move_range", 2))
	character.skill_id = str(data.get("skill_id", ""))
	character.portrait_path = str(data.get("portrait_path", ""))
	character.model_path = str(data.get("model_path", ""))
	character.description = (data.get("description", {}) as Dictionary).duplicate()
	character.level_growth = (data.get("level_growth", {}) as Dictionary).duplicate()
	character.stats = StatBlock.from_dict(data.get("stats", {}) as Dictionary)
	return character
