class_name SpellData
extends RefCounted

var id: String = ""
var display_name: String = ""
var mastery_id: String = ""
var tier_base: int = 0
var damage_type: String = "physical"
var mp_cost: int = 0
var range_tiles: int = 1
var targets: String = "enemy"
var healing: bool = false


static func from_dict(data: Dictionary) -> SpellData:
	var spell := SpellData.new()
	spell.id = str(data.get("id", ""))
	spell.display_name = str(data.get("name", ""))
	spell.mastery_id = str(data.get("mastery_id", ""))
	spell.tier_base = int(data.get("tier_base", 0))
	spell.damage_type = str(data.get("damage_type", "physical"))
	spell.mp_cost = int(data.get("mp_cost", 0))
	spell.range_tiles = int(data.get("range", 1))
	spell.targets = str(data.get("targets", "enemy"))
	spell.healing = bool(data.get("healing", false))
	return spell
