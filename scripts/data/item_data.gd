class_name ItemData
extends RefCounted

var id: String = ""
var display_name: String = ""
var item_type: String = "consumable"
var heal_amount: int = 0
var revive: bool = false
var range_tiles: int = 1
var targets: String = "ally"


static func from_dict(data: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.id = str(data.get("id", ""))
	item.display_name = str(data.get("name", ""))
	item.item_type = str(data.get("type", "consumable"))
	item.heal_amount = int(data.get("heal_amount", 0))
	item.revive = bool(data.get("revive", false))
	item.range_tiles = int(data.get("range", 1))
	item.targets = str(data.get("targets", "ally"))
	return item
