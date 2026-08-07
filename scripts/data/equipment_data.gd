class_name EquipmentData
extends RefCounted

const SLOT_WEAPON: String = "weapon"
const SLOT_ARMOR: String = "armor"
const SLOT_HELMET: String = "helmet"
const SLOT_ACCESSORY_1: String = "accessory_1"
const SLOT_ACCESSORY_2: String = "accessory_2"

const ALL_SLOTS: Array[String] = [
	SLOT_WEAPON,
	SLOT_ARMOR,
	SLOT_HELMET,
	SLOT_ACCESSORY_1,
	SLOT_ACCESSORY_2,
]

var id: String = ""
var display_name: String = ""
var slot: String = ""
var stat_bonuses: Dictionary = {}


static func from_dict(data: Dictionary) -> RefCounted:
	var equipment := new()
	equipment.id = str(data.get("id", ""))
	equipment.display_name = str(data.get("name", ""))
	equipment.slot = str(data.get("slot", ""))
	equipment.stat_bonuses = data.get("stat_bonuses", {}) as Dictionary
	return equipment


static func slot_label(slot_name: String) -> String:
	match slot_name:
		SLOT_WEAPON:
			return "Weapon"
		SLOT_ARMOR:
			return "Armor"
		SLOT_HELMET:
			return "Helmet"
		SLOT_ACCESSORY_1, SLOT_ACCESSORY_2:
			return "Accessory"
		_:
			return slot_name.capitalize()
