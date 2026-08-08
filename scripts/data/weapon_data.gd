class_name WeaponData
extends RefCounted

var id: String = ""
var display_name: String = ""
var weapon_class: String = ""
var damage_type: String = "physical"
var attack_range: int = 1
var durability_max: int = 0
var ammo_item_id: String = ""
var magazine_size: int = 0
var stat_bonuses: Dictionary = {}


static func from_dict(data: Dictionary) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.id = str(data.get("id", ""))
	weapon.display_name = str(data.get("name", ""))
	weapon.weapon_class = str(data.get("weapon_class", ""))
	weapon.damage_type = str(data.get("damage_type", "physical"))
	weapon.attack_range = int(data.get("attack_range", 1))
	weapon.durability_max = int(data.get("durability_max", 0))
	weapon.ammo_item_id = str(data.get("ammo_item_id", ""))
	weapon.magazine_size = int(data.get("magazine_size", 0))
	weapon.stat_bonuses = data.get("stat_bonuses", {}) as Dictionary
	return weapon


func uses_durability() -> bool:
	return durability_max > 0


func uses_ammo() -> bool:
	return not ammo_item_id.is_empty() and magazine_size > 0
