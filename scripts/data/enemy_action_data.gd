class_name EnemyActionData
extends RefCounted

const TYPE_ATTACK: String = "attack"
const TYPE_DEBUFF: String = "debuff"

var id: String = ""
var display_name: String = ""
var action_type: String = TYPE_ATTACK
var chance: int = 0
var range_tiles: int = 1
var damage_min: int = 0
var damage_max: int = 0
var damage_type: String = "physical"
var stat_name: String = ""
var amount: int = 0


static func from_dict(data: Dictionary) -> EnemyActionData:
	var action := EnemyActionData.new()
	action.id = str(data.get("id", ""))
	action.display_name = str(data.get("name", action.id.capitalize()))
	action.action_type = str(data.get("type", TYPE_ATTACK))
	action.chance = int(data.get("chance", 0))
	action.range_tiles = int(data.get("range", 1))
	action.damage_min = int(data.get("damage_min", 0))
	action.damage_max = int(data.get("damage_max", 0))
	action.damage_type = str(data.get("damage_type", "physical"))
	action.stat_name = str(data.get("stat", ""))
	action.amount = int(data.get("amount", 0))
	return action
