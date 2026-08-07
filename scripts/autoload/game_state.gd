extends Node

const PartyStatsHelper = preload("res://scripts/data/party_stats.gd")
const EquipmentDataScript = preload("res://scripts/data/equipment_data.gd")

enum BattleSource { STANDALONE, EXPLORE }

enum BattleOutcomeCode { NONE = 0, VICTORY = 1, DEFEAT = 2, ESCAPED = 3 }

const DEFAULT_ENCOUNTER_ID: String = "test_4v3"

var battle_source: BattleSource = BattleSource.STANDALONE
var current_encounter_id: String = DEFAULT_ENCOUNTER_ID
var current_area_id: String = "test_room"
var return_area_id: String = "test_room"
var return_position: Vector3 = Vector3.ZERO
var return_rotation_y: float = 0.0
var overworld_enemy_id: String = ""
var defeated_enemy_ids: Array[String] = []
var visited_area_ids: Array[String] = []
var collected_pickup_ids: Array[String] = []
var party_members: Array = []
var inventory: Dictionary = {}
var equipped: Dictionary = {}
var owned_equipment: Dictionary = {}
var has_checkpoint: bool = false
var last_battle_outcome: int = BattleOutcomeCode.NONE
var last_battle_loot: Array[Dictionary] = []
var reload_from_checkpoint_on_explore_start: bool = false
var post_battle_contact_immune_until_msec: int = 0
var pending_door_spawn: Dictionary = {}

const POST_BATTLE_CONTACT_IMMUNITY_MS: int = 2500

var _checkpoint: ExploreCheckpointData = ExploreCheckpointData.new()
var _characters_cache: Dictionary = {}


func ensure_party_initialized(encounter_id: String = DEFAULT_ENCOUNTER_ID) -> void:
	if not party_members.is_empty():
		return
	var encounter := DataLoader.load_encounter(encounter_id)
	inventory = encounter.party_inventory.duplicate()
	_initialize_equipment_defaults()
	var characters := _get_characters()
	for ally_entry: Dictionary in encounter.allies:
		var character_id := str(ally_entry.get("character_id", ""))
		if not characters.has(character_id):
			continue
		var character: CharacterData = characters[character_id]
		var loadout: Dictionary = get_loadout(character_id)
		var stats := PartyStatsHelper.get_effective_stats(character, loadout)
		var snapshot: PartyMemberSnapshot = PartyMemberSnapshot.new()
		snapshot.character_id = character_id
		snapshot.max_hp = CombatConstants.HP_BASE + stats.vit * CombatConstants.HP_PER_VIT
		snapshot.current_hp = snapshot.max_hp
		snapshot.max_mp = CombatConstants.MP_BASE + stats.res * CombatConstants.MP_PER_RES
		snapshot.current_mp = snapshot.max_mp
		party_members.append(snapshot)


func _initialize_equipment_defaults() -> void:
	if not equipped.is_empty():
		return
	var defaults := DataLoader.load_party_equipment_defaults()
	owned_equipment = (defaults.get("owned_pool", {}) as Dictionary).duplicate()
	var loadouts: Dictionary = defaults.get("starting_loadouts", {}) as Dictionary
	for character_id: String in loadouts.keys():
		equipped[character_id] = (loadouts[character_id] as Dictionary).duplicate()
		for slot_name: String in (equipped[character_id] as Dictionary).keys():
			var item_id := str((equipped[character_id] as Dictionary).get(slot_name, ""))
			if item_id.is_empty():
				continue
			owned_equipment[item_id] = maxi(int(owned_equipment.get(item_id, 0)) - 1, 0)
			if int(owned_equipment[item_id]) <= 0:
				owned_equipment.erase(item_id)


func get_loadout(character_id: String) -> Dictionary:
	if equipped.has(character_id):
		return equipped[character_id] as Dictionary
	return {}


func get_effective_stats(character_id: String) -> StatBlock:
	var characters := _get_characters()
	if not characters.has(character_id):
		return StatBlock.new()
	var character: CharacterData = characters[character_id]
	return PartyStatsHelper.get_effective_stats(character, get_loadout(character_id))


func get_equipped_weapon(character_id: String) -> WeaponData:
	return PartyStatsHelper.get_equipped_weapon(get_loadout(character_id))


func get_derived_values(character_id: String) -> Dictionary:
	var characters := _get_characters()
	if not characters.has(character_id):
		return {}
	var character: CharacterData = characters[character_id]
	var stats := get_effective_stats(character_id)
	var weapon := get_equipped_weapon(character_id)
	return PartyStatsHelper.get_derived_values(stats, weapon, character.move_range)


func mark_area_visited(area_id: String) -> void:
	if area_id.is_empty() or area_id in visited_area_ids:
		return
	visited_area_ids.append(area_id)


func is_area_visited(area_id: String) -> bool:
	return area_id in visited_area_ids


func is_area_cleared(area_id: String) -> bool:
	var area := DataLoader.load_area(area_id)
	if area.enemies.is_empty():
		return true
	for enemy_entry: Dictionary in area.enemies:
		var enemy_id := str(enemy_entry.get("id", ""))
		if not is_enemy_defeated(enemy_id):
			return false
	return true


func is_pickup_collected(pickup_id: String) -> bool:
	return pickup_id in collected_pickup_ids


func has_item(item_id: String) -> bool:
	return int(inventory.get(item_id, 0)) > 0


func collect_pickup(pickup_id: String, item_id: String, count: int = 1) -> String:
	if pickup_id.is_empty() or item_id.is_empty():
		return "Invalid pickup."
	if is_pickup_collected(pickup_id):
		return "Already collected."
	var amount := maxi(count, 1)
	if _is_equipment_item(item_id):
		owned_equipment[item_id] = int(owned_equipment.get(item_id, 0)) + amount
	else:
		inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	collected_pickup_ids.append(pickup_id)
	return "Collected %s." % _get_loot_item_name(item_id)


func roll_encounter_loot(encounter_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var encounter := DataLoader.load_encounter(encounter_id)
	var enemies := DataLoader.load_enemies()
	for enemy_entry: Dictionary in encounter.enemies:
		var enemy_type_id := str(enemy_entry.get("enemy_id", ""))
		if not enemies.has(enemy_type_id):
			continue
		var enemy: EnemyData = enemies[enemy_type_id]
		for drop_entry: Dictionary in enemy.drops:
			var item_id := str(drop_entry.get("item_id", ""))
			var chance := float(drop_entry.get("chance", 0.0))
			var drop_count := maxi(int(drop_entry.get("count", 1)), 1)
			if item_id.is_empty() or chance <= 0.0:
				continue
			if randf() * 100.0 >= chance:
				continue
			_grant_loot_item(item_id, drop_count)
			result.append({
				"enemy_name": enemy.display_name,
				"item_id": item_id,
				"item_name": _get_loot_item_name(item_id),
				"count": drop_count,
			})
	return result


func use_item_outside_battle(item_id: String, target_character_id: String) -> String:
	if not inventory.has(item_id) or int(inventory[item_id]) <= 0:
		return "Item unavailable."
	var items := DataLoader.load_items()
	if not items.has(item_id):
		return "Unknown item."
	var item: ItemData = items[item_id]
	var snapshot := get_member_snapshot(target_character_id)
	if snapshot == null:
		return "Invalid target."
	if item.revive:
		if not snapshot.is_ko:
			return "Target is not KO."
		snapshot.is_ko = false
		snapshot.current_hp = mini(item.heal_amount, snapshot.max_hp)
	else:
		if snapshot.is_ko:
			return "Cannot heal a KO ally."
		if snapshot.current_hp >= snapshot.max_hp:
			return "Target is already at full HP."
		snapshot.current_hp = mini(snapshot.current_hp + item.heal_amount, snapshot.max_hp)
	inventory[item_id] = int(inventory[item_id]) - 1
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	return "Used %s." % item.display_name


func equip_item(character_id: String, slot_name: String, item_id: String) -> String:
	if not EquipmentDataScript.ALL_SLOTS.has(slot_name):
		return "Invalid slot."
	if item_id.is_empty():
		return unequip_slot(character_id, slot_name)
	if not _item_fits_slot(item_id, slot_name):
		return "Item does not fit this slot."
	if int(owned_equipment.get(item_id, 0)) <= 0:
		return "Item not owned."
	if _is_item_equipped_by_other(character_id, item_id):
		return "Item is equipped by another party member."
	if not equipped.has(character_id):
		equipped[character_id] = _empty_loadout()
	var loadout: Dictionary = equipped[character_id] as Dictionary
	var previous_id := str(loadout.get(slot_name, ""))
	if previous_id == item_id:
		return "Already equipped."
	loadout[slot_name] = item_id
	equipped[character_id] = loadout
	if not previous_id.is_empty():
		owned_equipment[previous_id] = int(owned_equipment.get(previous_id, 0)) + 1
	owned_equipment[item_id] = maxi(int(owned_equipment.get(item_id, 0)) - 1, 0)
	if int(owned_equipment[item_id]) <= 0:
		owned_equipment.erase(item_id)
	_recalculate_member_caps(character_id)
	return "Equipped."


func unequip_slot(character_id: String, slot_name: String) -> String:
	if not equipped.has(character_id):
		return "Nothing equipped."
	var loadout: Dictionary = equipped[character_id] as Dictionary
	var previous_id := str(loadout.get(slot_name, ""))
	if previous_id.is_empty():
		return "Slot is empty."
	loadout[slot_name] = ""
	equipped[character_id] = loadout
	owned_equipment[previous_id] = int(owned_equipment.get(previous_id, 0)) + 1
	_recalculate_member_caps(character_id)
	return "Unequipped."


func get_owned_items_for_slot(slot_name: String, character_id: String = "") -> Array[String]:
	var result: Array[String] = []
	if slot_name == EquipmentDataScript.SLOT_WEAPON:
		var weapons := DataLoader.load_weapons()
		for weapon_id: String in owned_equipment.keys():
			if int(owned_equipment[weapon_id]) <= 0:
				continue
			if not character_id.is_empty() and _is_item_equipped_by_other(character_id, weapon_id):
				continue
			if weapons.has(weapon_id):
				result.append(weapon_id)
		return result
	var equipment := DataLoader.load_equipment()
	for equipment_id: String in owned_equipment.keys():
		if int(owned_equipment[equipment_id]) <= 0:
			continue
		if not character_id.is_empty() and _is_item_equipped_by_other(character_id, equipment_id):
			continue
		if not equipment.has(equipment_id):
			continue
		var piece = equipment[equipment_id]
		if slot_name.begins_with("accessory") and piece.slot == "accessory":
			result.append(equipment_id)
		elif piece.slot == slot_name:
			result.append(equipment_id)
	return result


func get_equipped_item_name(character_id: String, slot_name: String) -> String:
	var item_id := str(get_loadout(character_id).get(slot_name, ""))
	if item_id.is_empty():
		return "(Empty)"
	if slot_name == EquipmentDataScript.SLOT_WEAPON:
		var weapons := DataLoader.load_weapons()
		if weapons.has(item_id):
			return (weapons[item_id] as WeaponData).display_name
		return item_id
	var equipment := DataLoader.load_equipment()
	if equipment.has(item_id):
		return equipment[item_id].display_name
	return item_id


func enter_battle(
	area_id: String,
	return_pos: Vector3,
	return_rot_y: float,
	encounter_id: String,
	enemy_id: String
) -> void:
	battle_source = BattleSource.EXPLORE
	current_area_id = area_id
	return_area_id = area_id
	return_position = return_pos
	return_rotation_y = return_rot_y
	current_encounter_id = encounter_id
	overworld_enemy_id = enemy_id
	last_battle_outcome = BattleOutcomeCode.NONE
	reload_from_checkpoint_on_explore_start = false


func update_party_from_battle(allies: Array[CombatUnit], battle_inventory: Dictionary) -> void:
	party_members.clear()
	for unit: CombatUnit in allies:
		party_members.append(PartyMemberSnapshot.from_combat_unit(unit))
	inventory = battle_inventory.duplicate()


func apply_party_snapshot_to_allies(allies: Array[CombatUnit]) -> void:
	for unit: CombatUnit in allies:
		var snapshot := get_member_snapshot(unit.source_id)
		if snapshot != null:
			snapshot.apply_to_combat_unit(unit)


func get_member_snapshot(character_id: String) -> PartyMemberSnapshot:
	for member: Variant in party_members:
		var snapshot := member as PartyMemberSnapshot
		if snapshot.character_id == character_id:
			return snapshot
	return null


func resolve_battle(outcome: int) -> void:
	last_battle_outcome = outcome
	last_battle_loot.clear()
	match outcome:
		BattleOutcomeCode.VICTORY:
			last_battle_loot = roll_encounter_loot(current_encounter_id)
			if not overworld_enemy_id.is_empty() and overworld_enemy_id not in defeated_enemy_ids:
				defeated_enemy_ids.append(overworld_enemy_id)
			reload_from_checkpoint_on_explore_start = false
			_begin_post_battle_explore()
		BattleOutcomeCode.ESCAPED:
			reload_from_checkpoint_on_explore_start = false
			_begin_post_battle_explore()
		BattleOutcomeCode.DEFEAT:
			if has_checkpoint:
				load_checkpoint()
			else:
				reload_from_checkpoint_on_explore_start = false
				reset_party_to_default()
	overworld_enemy_id = ""


func save_checkpoint(area_id: String, position: Vector3, rotation_y: float) -> void:
	_checkpoint.area_id = area_id
	_checkpoint.position = position
	_checkpoint.rotation_y = rotation_y
	_checkpoint.party_members.clear()
	for member: Variant in party_members:
		var snapshot := member as PartyMemberSnapshot
		_checkpoint.party_members.append(PartyMemberSnapshot.from_dict(snapshot.to_dict()))
	_checkpoint.inventory = inventory.duplicate()
	_checkpoint.equipped = equipped.duplicate(true)
	_checkpoint.owned_equipment = owned_equipment.duplicate()
	_checkpoint.defeated_enemy_ids = defeated_enemy_ids.duplicate()
	_checkpoint.visited_area_ids = visited_area_ids.duplicate()
	_checkpoint.collected_pickup_ids = collected_pickup_ids.duplicate()
	has_checkpoint = true


func load_checkpoint() -> void:
	if not has_checkpoint:
		return
	return_area_id = _checkpoint.area_id
	current_area_id = _checkpoint.area_id
	return_position = _checkpoint.position
	return_rotation_y = _checkpoint.rotation_y
	party_members.clear()
	for member: Variant in _checkpoint.party_members:
		var snapshot := member as PartyMemberSnapshot
		party_members.append(PartyMemberSnapshot.from_dict(snapshot.to_dict()))
	inventory = _checkpoint.inventory.duplicate()
	equipped = _checkpoint.equipped.duplicate(true)
	owned_equipment = _checkpoint.owned_equipment.duplicate()
	defeated_enemy_ids = _checkpoint.defeated_enemy_ids.duplicate()
	visited_area_ids = _checkpoint.visited_area_ids.duplicate()
	collected_pickup_ids = _checkpoint.collected_pickup_ids.duplicate()
	reload_from_checkpoint_on_explore_start = true


func get_explore_spawn(area: AreaData) -> Dictionary:
	if pending_door_spawn.has("area_id") and str(pending_door_spawn["area_id"]) == area.id:
		var door_spawn := {
			"position": pending_door_spawn["position"] as Vector3,
			"rotation_y": float(pending_door_spawn["rotation_y"]),
		}
		pending_door_spawn = {}
		current_area_id = area.id
		return door_spawn
	if reload_from_checkpoint_on_explore_start and has_checkpoint:
		reload_from_checkpoint_on_explore_start = false
		current_area_id = _checkpoint.area_id
		return {
			"position": _checkpoint.position,
			"rotation_y": _checkpoint.rotation_y,
		}
	if last_battle_outcome == BattleOutcomeCode.DEFEAT and has_checkpoint:
		current_area_id = _checkpoint.area_id
		return {
			"position": _checkpoint.position,
			"rotation_y": _checkpoint.rotation_y,
		}
	if last_battle_outcome in [BattleOutcomeCode.VICTORY, BattleOutcomeCode.ESCAPED]:
		var spawn := {
			"position": return_position,
			"rotation_y": return_rotation_y,
		}
		last_battle_outcome = BattleOutcomeCode.NONE
		current_area_id = return_area_id
		return spawn
	current_area_id = area.id
	return {
		"position": area.default_spawn,
		"rotation_y": 0.0,
	}


func is_post_battle_contact_immune() -> bool:
	return Time.get_ticks_msec() < post_battle_contact_immune_until_msec


func _begin_post_battle_explore() -> void:
	post_battle_contact_immune_until_msec = Time.get_ticks_msec() + POST_BATTLE_CONTACT_IMMUNITY_MS


func travel_to_area(area_id: String, spawn_pos: Vector3, spawn_rot_y: float) -> void:
	return_area_id = area_id
	current_area_id = area_id
	pending_door_spawn = {
		"area_id": area_id,
		"position": spawn_pos,
		"rotation_y": spawn_rot_y,
	}


func reset_party_to_default() -> void:
	party_members.clear()
	inventory.clear()
	equipped.clear()
	owned_equipment.clear()
	defeated_enemy_ids.clear()
	visited_area_ids.clear()
	collected_pickup_ids.clear()
	has_checkpoint = false
	_checkpoint = ExploreCheckpointData.new()
	ensure_party_initialized(DEFAULT_ENCOUNTER_ID)


func is_enemy_defeated(enemy_id: String) -> bool:
	return enemy_id in defeated_enemy_ids


func set_standalone_battle(encounter_id: String = DEFAULT_ENCOUNTER_ID) -> void:
	battle_source = BattleSource.STANDALONE
	current_encounter_id = encounter_id
	overworld_enemy_id = ""
	last_battle_outcome = BattleOutcomeCode.NONE
	reload_from_checkpoint_on_explore_start = false


func _recalculate_member_caps(character_id: String) -> void:
	var snapshot := get_member_snapshot(character_id)
	if snapshot == null:
		return
	var derived := get_derived_values(character_id)
	snapshot.max_hp = int(derived.get("max_hp", snapshot.max_hp))
	snapshot.max_mp = int(derived.get("max_mp", snapshot.max_mp))
	snapshot.current_hp = mini(snapshot.current_hp, snapshot.max_hp)
	snapshot.current_mp = mini(snapshot.current_mp, snapshot.max_mp)


func _is_item_equipped_by_other(character_id: String, item_id: String) -> bool:
	for other_id: String in equipped.keys():
		if other_id == character_id:
			continue
		var loadout: Dictionary = equipped[other_id] as Dictionary
		for slot_name: String in loadout.keys():
			if str(loadout.get(slot_name, "")) == item_id:
				return true
	return false


func _empty_loadout() -> Dictionary:
	return {
		EquipmentDataScript.SLOT_WEAPON: "",
		EquipmentDataScript.SLOT_ARMOR: "",
		EquipmentDataScript.SLOT_HELMET: "",
		EquipmentDataScript.SLOT_ACCESSORY_1: "",
		EquipmentDataScript.SLOT_ACCESSORY_2: "",
	}


func _get_characters() -> Dictionary:
	if _characters_cache.is_empty():
		_characters_cache = DataLoader.load_characters()
	return _characters_cache


func _item_fits_slot(item_id: String, slot_name: String) -> bool:
	if slot_name == EquipmentDataScript.SLOT_WEAPON:
		return DataLoader.load_weapons().has(item_id)
	var equipment := DataLoader.load_equipment()
	if not equipment.has(item_id):
		return false
	var piece = equipment[item_id]
	if slot_name.begins_with("accessory"):
		return piece.slot == "accessory"
	return piece.slot == slot_name


func _is_equipment_item(item_id: String) -> bool:
	return DataLoader.load_weapons().has(item_id) or DataLoader.load_equipment().has(item_id)


func _grant_loot_item(item_id: String, count: int) -> void:
	if _is_equipment_item(item_id):
		owned_equipment[item_id] = int(owned_equipment.get(item_id, 0)) + count
	else:
		inventory[item_id] = int(inventory.get(item_id, 0)) + count


func _get_loot_item_name(item_id: String) -> String:
	var items := DataLoader.load_items()
	if items.has(item_id):
		return (items[item_id] as ItemData).display_name
	var weapons := DataLoader.load_weapons()
	if weapons.has(item_id):
		return (weapons[item_id] as WeaponData).display_name
	var equipment := DataLoader.load_equipment()
	if equipment.has(item_id):
		return equipment[item_id].display_name
	return item_id
