class_name PartyStats
extends RefCounted

const EquipmentDataScript = preload("res://scripts/data/equipment_data.gd")


static func aggregate_bonuses(
	loadout: Dictionary,
	weapons: Dictionary,
	equipment: Dictionary
) -> Dictionary:
	var bonuses: Dictionary = {}
	for slot_name: String in EquipmentDataScript.ALL_SLOTS:
		var item_id := str(loadout.get(slot_name, ""))
		if item_id.is_empty():
			continue
		var slot_bonuses: Dictionary = {}
		if slot_name == EquipmentDataScript.SLOT_WEAPON and weapons.has(item_id):
			slot_bonuses = (weapons[item_id] as WeaponData).stat_bonuses
		elif equipment.has(item_id):
			slot_bonuses = equipment[item_id].stat_bonuses
		for stat_name: String in slot_bonuses.keys():
			bonuses[stat_name] = int(bonuses.get(stat_name, 0)) + int(slot_bonuses[stat_name])
	return bonuses


static func get_effective_stats(character: CharacterData, loadout: Dictionary) -> StatBlock:
	var weapons := DataLoader.load_weapons()
	var equipment := DataLoader.load_equipment()
	var bonuses := aggregate_bonuses(loadout, weapons, equipment)
	return character.stats.get_bonus(bonuses)


static func get_equipped_weapon(loadout: Dictionary) -> WeaponData:
	var weapon_id := str(loadout.get(EquipmentDataScript.SLOT_WEAPON, ""))
	if weapon_id.is_empty():
		return null
	var weapons := DataLoader.load_weapons()
	if not weapons.has(weapon_id):
		return null
	return weapons[weapon_id] as WeaponData


static func get_derived_values(stats: StatBlock, weapon: WeaponData, move_range: int) -> Dictionary:
	var damage_min := 0
	var damage_max := 0
	var attack_range := 1
	if weapon != null:
		damage_min = weapon.damage_min
		damage_max = weapon.damage_max
		attack_range = weapon.attack_range
	var max_hp := CombatConstants.HP_BASE + stats.vit * CombatConstants.HP_PER_VIT
	var max_mp := CombatConstants.MP_BASE + stats.res * CombatConstants.MP_PER_RES
	var hit_mod := CombatConstants.BASE_HIT + float(stats.dex)
	var vit_mitigation := int(float(stats.vit) * CombatConstants.VIT_WEIGHT)
	var retreat_chance := CombatConstants.RETREAT_BASE + float(stats.agi) + float(stats.luk) * 0.5
	return {
		"max_hp": max_hp,
		"max_mp": max_mp,
		"damage_min": damage_min,
		"damage_max": damage_max,
		"attack_range": attack_range,
		"hit_mod": hit_mod,
		"vit_mitigation": vit_mitigation,
		"move_range": move_range,
		"retreat_chance": retreat_chance,
	}
