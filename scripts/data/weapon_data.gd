class_name WeaponData
extends RefCounted

var id: String = ""
var display_name: String = ""
var weapon_class: String = ""
var damage_min: int = 0
var damage_max: int = 0
var damage_type: String = "physical"
var attack_range: int = 1
var stat_bonuses: Dictionary = {}


static func from_dict(data: Dictionary) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.id = str(data.get("id", ""))
	weapon.display_name = str(data.get("name", ""))
	weapon.weapon_class = str(data.get("weapon_class", ""))
	weapon.damage_min = int(data.get("damage_min", 0))
	weapon.damage_max = int(data.get("damage_max", 0))
	weapon.damage_type = str(data.get("damage_type", "physical"))
	weapon.attack_range = int(data.get("attack_range", 1))
	weapon.stat_bonuses = data.get("stat_bonuses", {}) as Dictionary
	return weapon
