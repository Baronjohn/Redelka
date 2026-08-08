extends Node

const PartyStatsHelper = preload("res://scripts/data/party_stats.gd")
const EquipmentDataScript = preload("res://scripts/data/equipment_data.gd")
const ProgressionConstantsScript = preload("res://scripts/data/progression_constants.gd")
const MasteryConstantsScript = preload("res://scripts/data/mastery_constants.gd")
const PartyFormationScript = preload("res://scripts/data/party_formation.gd")

enum BattleSource { STANDALONE, EXPLORE }

enum BattleOutcomeCode { NONE = 0, VICTORY = 1, DEFEAT = 2, ESCAPED = 3 }

enum Difficulty { EASY = 0, NORMAL = 1, HARD = 2 }

const DEFAULT_ENCOUNTER_ID: String = "test_4v3"
const NEW_GAME_AREA_ID: String = "village_square"
const SAVE_RESOURCE_ITEM_ID: String = "memory_tape"

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
var party_formation: Dictionary = {}
var equipped: Dictionary = {}
var owned_equipment: Dictionary = {}
var weapon_durability: Dictionary = {}
var weapon_loaded_ammo: Dictionary = {}
var difficulty: int = Difficulty.NORMAL
var last_battle_outcome: int = BattleOutcomeCode.NONE
var last_battle_loot: Array[Dictionary] = []
var last_battle_xp: int = 0
var last_level_ups: Array[Dictionary] = []
var pending_level_up_queue: Array[String] = []
var post_battle_contact_immune_until_msec: int = 0
var pending_door_spawn: Dictionary = {}
var pending_load_spawn: Dictionary = {}
var _autosave_after_door_spawn: bool = false
var last_save_error: String = ""

const POST_BATTLE_CONTACT_IMMUNITY_MS: int = 2500

var _characters_cache: Dictionary = {}
var _draft_character_id: String = ""
var _draft_allocated: StatBlock = StatBlock.new()
var _draft_budget: int = 0


func ensure_party_initialized(_encounter_id: String = DEFAULT_ENCOUNTER_ID) -> void:
	if not party_members.is_empty():
		return
	_initialize_equipment_defaults()
	if inventory.is_empty():
		inventory = get_setup_inventory()
	if party_formation.is_empty():
		reset_formation_to_default()
	var characters := _get_characters()
	for character_id: String in get_party_character_ids():
		if not characters.has(character_id):
			continue
		var character: CharacterData = characters[character_id]
		var loadout: Dictionary = get_loadout(character_id)
		var snapshot: PartyMemberSnapshot = PartyMemberSnapshot.new()
		snapshot.character_id = character_id
		var stats := PartyStatsHelper.get_effective_stats(character, loadout, snapshot)
		snapshot.max_hp = CombatConstants.HP_BASE + stats.vit * CombatConstants.HP_PER_VIT
		snapshot.current_hp = snapshot.max_hp
		snapshot.max_mp = CombatConstants.MP_BASE + stats.res * CombatConstants.MP_PER_RES
		snapshot.current_mp = snapshot.max_mp
		_initialize_mastery_defaults(snapshot)
		party_members.append(snapshot)
	ensure_formation_for_party()


func _initialize_equipment_defaults() -> void:
	if not equipped.is_empty():
		return
	var setup := DataLoader.load_new_game_setup()
	owned_equipment = (setup.get("owned_equipment", {}) as Dictionary).duplicate()
	var loadouts: Dictionary = setup.get("loadouts", {}) as Dictionary
	for character_id: String in loadouts.keys():
		equipped[character_id] = _normalize_loadout(loadouts[character_id] as Dictionary)
		for slot_name: String in (equipped[character_id] as Dictionary).keys():
			var item_id := str((equipped[character_id] as Dictionary).get(slot_name, ""))
			if item_id.is_empty():
				continue
			owned_equipment[item_id] = maxi(int(owned_equipment.get(item_id, 0)) - 1, 0)
			if int(owned_equipment[item_id]) <= 0:
				owned_equipment.erase(item_id)
	_initialize_weapon_states_for_party()


func get_loadout(character_id: String) -> Dictionary:
	if equipped.has(character_id):
		return _normalize_loadout(equipped[character_id] as Dictionary)
	return _empty_loadout()


func get_effective_stats(character_id: String) -> StatBlock:
	var characters := _get_characters()
	if not characters.has(character_id):
		return StatBlock.new()
	var character: CharacterData = characters[character_id]
	var snapshot := get_member_snapshot(character_id)
	return PartyStatsHelper.get_effective_stats(character, get_loadout(character_id), snapshot)


func get_equipped_weapon(character_id: String) -> WeaponData:
	return PartyStatsHelper.get_equipped_weapon(get_loadout(character_id))


func get_weapon_status_suffix(character_id: String, slot_name: String) -> String:
	if slot_name != EquipmentDataScript.SLOT_WEAPON:
		return ""
	var weapon_id := str(get_loadout(character_id).get(EquipmentDataScript.SLOT_WEAPON, ""))
	if weapon_id.is_empty():
		return ""
	var weapons := DataLoader.load_weapons()
	if not weapons.has(weapon_id):
		return ""
	var weapon: WeaponData = weapons[weapon_id]
	if weapon.uses_ammo():
		var loaded := get_weapon_loaded_ammo(character_id, weapon_id)
		return " (%d/%d)" % [loaded, weapon.magazine_size]
	if weapon.uses_durability():
		var durability := get_weapon_durability(character_id, weapon_id)
		return " (%d/%d)" % [durability, weapon.durability_max]
	return ""


func get_weapon_durability(character_id: String, weapon_id: String) -> int:
	var per_weapon: Dictionary = _get_durability_map(character_id)
	if per_weapon.has(weapon_id):
		return int(per_weapon[weapon_id])
	var weapons := DataLoader.load_weapons()
	if weapons.has(weapon_id):
		return (weapons[weapon_id] as WeaponData).durability_max
	return 0


func get_weapon_loaded_ammo(character_id: String, weapon_id: String) -> int:
	return int(_get_loaded_map(character_id).get(weapon_id, 0))


func can_attack_with_equipped_weapon(character_id: String) -> bool:
	var weapon := get_equipped_weapon(character_id)
	if weapon == null:
		return false
	if weapon.uses_ammo():
		var weapon_id := str(get_loadout(character_id).get(EquipmentDataScript.SLOT_WEAPON, ""))
		return get_weapon_loaded_ammo(character_id, weapon_id) > 0
	if weapon.uses_durability():
		var weapon_id := str(get_loadout(character_id).get(EquipmentDataScript.SLOT_WEAPON, ""))
		return get_weapon_durability(character_id, weapon_id) > 0
	return true


func can_reload_with_ammo(character_id: String, ammo_item_id: String) -> bool:
	var weapon := get_equipped_weapon(character_id)
	if weapon == null or not weapon.uses_ammo():
		return false
	if weapon.ammo_item_id != ammo_item_id:
		return false
	var weapon_id := str(get_loadout(character_id).get(EquipmentDataScript.SLOT_WEAPON, ""))
	if get_weapon_loaded_ammo(character_id, weapon_id) >= weapon.magazine_size:
		return false
	return int(inventory.get(ammo_item_id, 0)) > 0


func reload_equipped_weapon(character_id: String) -> Dictionary:
	var weapon := get_equipped_weapon(character_id)
	if weapon == null or not weapon.uses_ammo():
		return {"ok": false, "message": "No ranged weapon equipped."}
	var weapon_id := str(get_loadout(character_id).get(EquipmentDataScript.SLOT_WEAPON, ""))
	var loaded := get_weapon_loaded_ammo(character_id, weapon_id)
	if loaded >= weapon.magazine_size:
		return {"ok": false, "message": "%s is already fully loaded." % weapon.display_name}
	var available := int(inventory.get(weapon.ammo_item_id, 0))
	if available <= 0:
		return {"ok": false, "message": "No %s available." % _get_loot_item_name(weapon.ammo_item_id)}
	var needed := weapon.magazine_size - loaded
	var transfer := mini(available, needed)
	inventory[weapon.ammo_item_id] = available - transfer
	if int(inventory[weapon.ammo_item_id]) <= 0:
		inventory.erase(weapon.ammo_item_id)
	_set_loaded_ammo(character_id, weapon_id, loaded + transfer)
	return {
		"ok": true,
		"message": "Reloaded %s (%d/%d)." % [weapon.display_name, loaded + transfer, weapon.magazine_size],
	}


func consume_attack_resource(character_id: String) -> Dictionary:
	var weapon := get_equipped_weapon(character_id)
	if weapon == null:
		return {"ok": false, "reason": "no_weapon", "message": "No weapon equipped."}
	var weapon_id := str(get_loadout(character_id).get(EquipmentDataScript.SLOT_WEAPON, ""))
	if weapon.uses_ammo():
		var loaded := get_weapon_loaded_ammo(character_id, weapon_id)
		if loaded <= 0:
			return {"ok": false, "reason": "empty", "message": "%s is out of ammo." % weapon.display_name}
		_set_loaded_ammo(character_id, weapon_id, loaded - 1)
		return {"ok": true, "broke": false, "message": ""}
	if weapon.uses_durability():
		var durability := get_weapon_durability(character_id, weapon_id)
		if durability <= 0:
			return {"ok": false, "reason": "broken", "message": "%s is broken." % weapon.display_name}
		durability -= 1
		if durability <= 0:
			_set_durability(character_id, weapon_id, 0)
			_destroy_equipped_weapon(character_id)
			return {
				"ok": true,
				"broke": true,
				"message": "%s broke!" % weapon.display_name,
			}
		_set_durability(character_id, weapon_id, durability)
		return {"ok": true, "broke": false, "message": ""}
	return {"ok": true, "broke": false, "message": ""}


func get_switchable_weapons(character_id: String) -> Array[String]:
	var result: Array[String] = []
	var weapons := DataLoader.load_weapons()
	for item_id: String in owned_equipment.keys():
		if int(owned_equipment[item_id]) <= 0:
			continue
		if not weapons.has(item_id):
			continue
		if not _item_fits_slot(item_id, EquipmentDataScript.SLOT_WEAPON):
			continue
		if not _find_equipped_location(item_id, "", "").is_empty():
			continue
		result.append(item_id)
	result.sort()
	return result


func switch_weapon(character_id: String, weapon_id: String) -> Dictionary:
	if weapon_id not in get_switchable_weapons(character_id):
		return {"ok": false, "message": "Weapon unavailable."}
	var current_id := str(get_loadout(character_id).get(EquipmentDataScript.SLOT_WEAPON, ""))
	if not current_id.is_empty():
		var unequip_result := unequip_slot(character_id, EquipmentDataScript.SLOT_WEAPON)
		if unequip_result != "Unequipped.":
			return {"ok": false, "message": unequip_result}
	var equip_result := equip_item(character_id, EquipmentDataScript.SLOT_WEAPON, weapon_id)
	if equip_result != "Equipped.":
		return {"ok": false, "message": equip_result}
	return {
		"ok": true,
		"message": "Switched to %s." % _get_loot_item_name(weapon_id),
	}


func get_weapon_mastery_level(character_id: String, weapon_class: String) -> int:
	var entry := _get_weapon_mastery_entry(character_id, weapon_class)
	return int(entry.get("level", 1))


func get_weapon_mastery_xp(character_id: String, weapon_class: String) -> int:
	var entry := _get_weapon_mastery_entry(character_id, weapon_class)
	return int(entry.get("xp", 0))


func get_weapon_mastery_progress(character_id: String, weapon_class: String) -> Dictionary:
	var level := get_weapon_mastery_level(character_id, weapon_class)
	var xp := get_weapon_mastery_xp(character_id, weapon_class)
	return {
		"level": level,
		"xp": xp,
		"xp_to_next": MasteryConstantsScript.weapon_xp_to_next_level(level),
	}


func award_weapon_mastery_xp(
	character_id: String,
	weapon_class: String,
	amount: int = MasteryConstantsScript.MASTERY_XP_PER_USE,
) -> Dictionary:
	var snapshot := get_member_snapshot(character_id)
	if snapshot == null or weapon_class.is_empty():
		return {"ok": false, "message": ""}
	_ensure_mastery_defaults(snapshot)
	var entry: Dictionary = snapshot.weapon_mastery[weapon_class] as Dictionary
	var level := int(entry.get("level", 1))
	if level >= MasteryConstantsScript.WEAPON_MAX_LEVEL:
		return {"ok": true, "message": "", "level_up": false}
	entry["xp"] = int(entry.get("xp", 0)) + amount
	var messages: PackedStringArray = []
	while level < MasteryConstantsScript.WEAPON_MAX_LEVEL:
		var threshold := MasteryConstantsScript.weapon_xp_to_next_level(level)
		if threshold <= 0 or int(entry.get("xp", 0)) < threshold:
			break
		entry["xp"] = int(entry.get("xp", 0)) - threshold
		level += 1
		entry["level"] = level
		messages.append("%s %s mastery reached level %d." % [
			_get_character_name(character_id),
			weapon_class.capitalize(),
			level,
		])
	snapshot.weapon_mastery[weapon_class] = entry
	return {
		"ok": true,
		"message": ", ".join(messages),
		"level_up": not messages.is_empty(),
	}


func get_spell_tier(character_id: String, spell_id: String) -> int:
	var mastery_id := _resolve_spell_mastery_id(spell_id)
	if mastery_id.is_empty():
		return 0
	return int(_get_spell_mastery_entry(character_id, mastery_id).get("tier", 0))


func get_spell_mastery_xp(character_id: String, spell_id: String) -> int:
	var mastery_id := _resolve_spell_mastery_id(spell_id)
	if mastery_id.is_empty():
		return 0
	return int(_get_spell_mastery_entry(character_id, mastery_id).get("xp", 0))


func get_spell_mastery_progress(character_id: String, spell_id: String) -> Dictionary:
	return get_spell_mastery_progress_for_type(character_id, _resolve_spell_mastery_id(spell_id))


func get_spell_mastery_progress_for_type(character_id: String, mastery_id: String) -> Dictionary:
	if mastery_id.is_empty():
		return {"tier": 0, "xp": 0, "xp_to_next": 0}
	var entry := _get_spell_mastery_entry(character_id, mastery_id)
	var tier := int(entry.get("tier", 0))
	return {
		"tier": tier,
		"xp": int(entry.get("xp", 0)),
		"xp_to_next": MasteryConstantsScript.spell_xp_to_next_tier(tier),
	}


func unlock_spell_for_character(character_id: String, spell_id: String) -> String:
	var spells := DataLoader.load_spells()
	if not spells.has(spell_id):
		return "Unknown spell."
	var mastery_id := _resolve_spell_mastery_id(spell_id)
	if mastery_id.is_empty():
		return "Spell has no mastery type."
	var snapshot := get_member_snapshot(character_id)
	if snapshot == null:
		return "Invalid character."
	_ensure_mastery_defaults(snapshot)
	var entry: Dictionary = snapshot.spell_mastery[mastery_id] as Dictionary
	if int(entry.get("tier", 0)) > 0:
		return "%s already knows %s." % [
			_get_character_name(character_id),
			MasteryConstantsScript.get_spell_mastery_display_name(mastery_id),
		]
	entry["tier"] = 1
	entry["xp"] = 0
	snapshot.spell_mastery[mastery_id] = entry
	return "%s learned %s." % [
		_get_character_name(character_id),
		(spells[spell_id] as SpellData).display_name,
	]


func award_spell_mastery_xp(
	character_id: String,
	spell_id: String,
	amount: int = MasteryConstantsScript.MASTERY_XP_PER_USE,
) -> Dictionary:
	var snapshot := get_member_snapshot(character_id)
	if snapshot == null or spell_id.is_empty():
		return {"ok": false, "message": ""}
	var mastery_id := _resolve_spell_mastery_id(spell_id)
	if mastery_id.is_empty():
		return {"ok": false, "message": ""}
	var tier := int(_get_spell_mastery_entry(character_id, mastery_id).get("tier", 0))
	if tier <= 0:
		return {"ok": false, "message": ""}
	var entry: Dictionary = snapshot.spell_mastery[mastery_id] as Dictionary
	var messages: PackedStringArray = []
	entry["xp"] = int(entry.get("xp", 0)) + amount
	while tier < MasteryConstantsScript.SPELL_MAX_TIER:
		var threshold := MasteryConstantsScript.spell_xp_to_next_tier(tier)
		if threshold <= 0 or int(entry.get("xp", 0)) < threshold:
			break
		entry["xp"] = int(entry.get("xp", 0)) - threshold
		tier += 1
		entry["tier"] = tier
		messages.append("%s's %s mastery reached tier %d." % [
			_get_character_name(character_id),
			MasteryConstantsScript.get_spell_mastery_display_name(mastery_id),
			tier,
		])
	snapshot.spell_mastery[mastery_id] = entry
	return {
		"ok": true,
		"message": ", ".join(messages),
		"tier_up": not messages.is_empty(),
	}


func get_unlocked_spells_for_character(character_id: String) -> Array[String]:
	var result: Array[String] = []
	for spell_id: String in DataLoader.load_spells().keys():
		if get_spell_tier(character_id, spell_id) >= 1:
			result.append(spell_id)
	result.sort()
	return result


func get_effective_spell_stats(character_id: String, spell_id: String) -> Dictionary:
	var spells := DataLoader.load_spells()
	if not spells.has(spell_id):
		return {"tier": 0, "tier_base": 0, "mp_cost": 0}
	var spell: SpellData = spells[spell_id]
	var tier := get_spell_tier(character_id, spell_id)
	if tier <= 0:
		return {"tier": 0, "tier_base": spell.tier_base, "mp_cost": spell.mp_cost}
	var power_mult := MasteryConstantsScript.get_spell_power_multiplier(tier)
	var mp_mult := MasteryConstantsScript.get_spell_mp_multiplier(tier)
	return {
		"tier": tier,
		"tier_base": maxi(int(round(float(spell.tier_base) * power_mult)), 1),
		"mp_cost": maxi(int(round(float(spell.mp_cost) * mp_mult)), 1),
	}


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


func get_save_resource_display_name() -> String:
	return _get_loot_item_name(SAVE_RESOURCE_ITEM_ID)


func can_manual_save() -> bool:
	return get_manual_save_block_reason().is_empty()


func get_manual_save_block_reason() -> String:
	if difficulty != Difficulty.HARD:
		return ""
	if has_item(SAVE_RESOURCE_ITEM_ID):
		return ""
	return "You need %s to save." % get_save_resource_display_name()


func _consume_inventory_item(item_id: String) -> void:
	var count := int(inventory.get(item_id, 0)) - 1
	if count <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = count


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


func roll_encounter_xp(encounter_id: String) -> int:
	var total := 0
	var encounter := DataLoader.load_encounter(encounter_id)
	var enemies := DataLoader.load_enemies()
	for enemy_entry: Dictionary in encounter.enemies:
		var enemy_type_id := str(enemy_entry.get("enemy_id", ""))
		if not enemies.has(enemy_type_id):
			continue
		total += (enemies[enemy_type_id] as EnemyData).xp_reward
	return total


func grant_xp_to_party(amount: int) -> Array[Dictionary]:
	last_level_ups.clear()
	pending_level_up_queue.clear()
	if amount <= 0:
		return last_level_ups
	var characters := _get_characters()
	for member: Variant in party_members:
		var snapshot := member as PartyMemberSnapshot
		if not characters.has(snapshot.character_id):
			continue
		var character: CharacterData = characters[snapshot.character_id]
		var old_level := snapshot.level
		snapshot.xp += amount
		while snapshot.level < ProgressionConstantsScript.LEVEL_CAP:
			var required := ProgressionConstantsScript.xp_required_for_level(snapshot.level)
			if snapshot.xp < required:
				break
			snapshot.xp -= required
			snapshot.level += 1
			snapshot.unspent_stat_points += ProgressionConstantsScript.POINTS_PER_LEVEL
			_recalculate_member_caps(snapshot.character_id)
			snapshot.current_hp = snapshot.max_hp
			snapshot.current_mp = snapshot.max_mp
			if snapshot.is_ko:
				snapshot.is_ko = false
		if snapshot.level > old_level:
			var levels_gained := snapshot.level - old_level
			last_level_ups.append({
				"character_id": snapshot.character_id,
				"name": character.display_name,
				"old_level": old_level,
				"new_level": snapshot.level,
				"auto_growth": PartyStatsHelper.get_level_growth_for_levels(character, levels_gained),
			})
			if snapshot.unspent_stat_points > 0:
				pending_level_up_queue.append(snapshot.character_id)
	return last_level_ups


func begin_level_up_allocation(character_id: String) -> void:
	var snapshot := get_member_snapshot(character_id)
	if snapshot == null:
		return
	_draft_character_id = character_id
	_draft_allocated = StatBlock.new()
	_draft_budget = snapshot.unspent_stat_points


func draft_allocate_stat(stat_name: String) -> void:
	if _draft_budget <= 0:
		return
	_draft_allocated.add_stat(stat_name, 1)
	_draft_budget -= 1


func draft_deallocate_stat(stat_name: String) -> void:
	if _draft_allocated.get_stat(stat_name) <= 0:
		return
	_draft_allocated.add_stat(stat_name, -1)
	_draft_budget += 1


func reset_draft_allocation() -> void:
	_draft_allocated = StatBlock.new()
	var snapshot := get_member_snapshot(_draft_character_id)
	if snapshot != null:
		_draft_budget = snapshot.unspent_stat_points


func confirm_draft_allocation() -> String:
	var snapshot := get_member_snapshot(_draft_character_id)
	if snapshot == null:
		return ""
	if _draft_budget > 0:
		return ""
	snapshot.allocated_stats.add_block(_draft_allocated)
	snapshot.unspent_stat_points = 0
	_recalculate_member_caps(_draft_character_id)
	var confirmed_id := _draft_character_id
	if confirmed_id in pending_level_up_queue:
		pending_level_up_queue.erase(confirmed_id)
	_draft_character_id = ""
	_draft_allocated = StatBlock.new()
	_draft_budget = 0
	return confirmed_id


func has_pending_level_ups() -> bool:
	return not pending_level_up_queue.is_empty()


func peek_level_up_character() -> String:
	if pending_level_up_queue.is_empty():
		return ""
	return pending_level_up_queue[0]


func get_draft_allocated_stats() -> StatBlock:
	return _draft_allocated


func get_draft_remaining_points() -> int:
	return _draft_budget


func get_level_up_entry(character_id: String) -> Dictionary:
	for entry_variant: Variant in last_level_ups:
		var entry := entry_variant as Dictionary
		if str(entry.get("character_id", "")) == character_id:
			return entry
	return {}


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
	if item.item_type == "ammo":
		if not can_reload_with_ammo(target_character_id, item_id):
			return "Cannot reload with this ammo."
		var reload_result: Dictionary = reload_equipped_weapon(target_character_id)
		return str(reload_result.get("message", "Reload failed."))
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
		var equipped_location := _find_equipped_location(item_id, character_id, slot_name)
		if equipped_location.is_empty():
			return "Item not owned."
		unequip_slot(
			str(equipped_location.get("character_id", "")),
			str(equipped_location.get("slot_name", "")),
		)
	if int(owned_equipment.get(item_id, 0)) <= 0:
		return "Item not owned."
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
	if slot_name == EquipmentDataScript.SLOT_WEAPON:
		_ensure_weapon_state(character_id, item_id)
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


func get_equipment_candidates_for_slot(character_id: String, slot_name: String) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var loadout := get_loadout(character_id)
	var equipped_id := str(loadout.get(slot_name, ""))
	if not equipped_id.is_empty():
		candidates.append({
			"item_id": equipped_id,
			"source": "current",
		})
	var pool_counts: Dictionary = owned_equipment.duplicate()
	for item_id: String in pool_counts.keys():
		if not _item_fits_slot(item_id, slot_name):
			continue
		var count := int(pool_counts[item_id])
		for _i: int in range(count):
			candidates.append({
				"item_id": item_id,
				"source": "pool",
			})
	for owner_id: String in equipped.keys():
		var owner_loadout: Dictionary = _normalize_loadout(equipped[owner_id] as Dictionary)
		for equipped_slot: String in owner_loadout.keys():
			if owner_id == character_id and equipped_slot == slot_name:
				continue
			var item_id := str(owner_loadout.get(equipped_slot, ""))
			if item_id.is_empty() or not _item_fits_slot(item_id, slot_name):
				continue
			candidates.append({
				"item_id": item_id,
				"source": "equipped",
				"owner_id": owner_id,
				"owner_slot": equipped_slot,
			})
	return candidates


func get_owned_items_for_slot(slot_name: String, character_id: String = "") -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	for item_id: String in owned_equipment.keys():
		if int(owned_equipment[item_id]) <= 0:
			continue
		if not _item_fits_slot(item_id, slot_name):
			continue
		if seen.has(item_id):
			continue
		result.append(item_id)
		seen[item_id] = true
	for owner_id: String in equipped.keys():
		var loadout: Dictionary = _normalize_loadout(equipped[owner_id] as Dictionary)
		for equipped_slot: String in loadout.keys():
			if owner_id == character_id and equipped_slot == slot_name:
				continue
			var item_id := str(loadout.get(equipped_slot, ""))
			if item_id.is_empty() or seen.has(item_id):
				continue
			if not _item_fits_slot(item_id, slot_name):
				continue
			result.append(item_id)
			seen[item_id] = true
	result.sort()
	return result


func get_item_equipped_by(item_id: String) -> String:
	var location := _find_equipped_location(item_id, "", "")
	return str(location.get("character_id", ""))


func get_equipped_item_name(character_id: String, slot_name: String) -> String:
	var item_id := str(get_loadout(character_id).get(slot_name, ""))
	if item_id.is_empty():
		return "(Empty)"
	if slot_name == EquipmentDataScript.SLOT_WEAPON:
		var weapons := DataLoader.load_weapons()
		if weapons.has(item_id):
			var weapon_name := (weapons[item_id] as WeaponData).display_name
			return weapon_name + get_weapon_status_suffix(character_id, slot_name)
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


func update_party_from_battle(allies: Array[CombatUnit], battle_inventory: Dictionary) -> void:
	var updated: Array = []
	for unit: CombatUnit in allies:
		var existing := get_member_snapshot(unit.source_id)
		updated.append(PartyMemberSnapshot.from_combat_unit(unit, existing))
	party_members = updated
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
	last_battle_xp = 0
	last_level_ups.clear()
	pending_level_up_queue.clear()
	match outcome:
		BattleOutcomeCode.VICTORY:
			last_battle_loot = roll_encounter_loot(current_encounter_id)
			last_battle_xp = roll_encounter_xp(current_encounter_id)
			if last_battle_xp > 0:
				grant_xp_to_party(last_battle_xp)
			_apply_encounter_spell_unlocks(current_encounter_id)
			if not overworld_enemy_id.is_empty() and overworld_enemy_id not in defeated_enemy_ids:
				defeated_enemy_ids.append(overworld_enemy_id)
			_begin_post_battle_explore()
		BattleOutcomeCode.ESCAPED:
			_begin_post_battle_explore()
		BattleOutcomeCode.DEFEAT:
			pass
	overworld_enemy_id = ""


func start_new_game(new_difficulty: int) -> void:
	reset_party_to_default()
	difficulty = new_difficulty
	current_area_id = NEW_GAME_AREA_ID
	return_area_id = NEW_GAME_AREA_ID
	var area := DataLoader.load_area(NEW_GAME_AREA_ID)
	return_position = area.default_spawn
	return_rotation_y = 0.0
	pending_load_spawn = {}
	pending_door_spawn = {}
	_autosave_after_door_spawn = false
	last_battle_outcome = BattleOutcomeCode.NONE
	battle_source = BattleSource.EXPLORE


func to_save_state_dict(player_position: Vector3, player_rotation_y: float) -> Dictionary:
	var members: Array = []
	for member: Variant in party_members:
		var snapshot := member as PartyMemberSnapshot
		members.append(snapshot.to_dict())
	return {
		"difficulty": difficulty,
		"current_area_id": current_area_id,
		"return_area_id": return_area_id,
		"return_position": [player_position.x, player_position.y, player_position.z],
		"return_rotation_y": player_rotation_y,
		"defeated_enemy_ids": defeated_enemy_ids.duplicate(),
		"visited_area_ids": visited_area_ids.duplicate(),
		"collected_pickup_ids": collected_pickup_ids.duplicate(),
		"party_members": members,
		"party_formation": PartyFormationScript.serialize_positions(party_formation),
		"formation_coord_space": "menu",
		"inventory": inventory.duplicate(),
		"equipped": equipped.duplicate(true),
		"owned_equipment": owned_equipment.duplicate(),
		"weapon_durability": _duplicate_nested_int_dict(weapon_durability),
		"weapon_loaded_ammo": _duplicate_nested_int_dict(weapon_loaded_ammo),
	}


func build_save_data(player_position: Vector3, player_rotation_y: float) -> Dictionary:
	var state := to_save_state_dict(player_position, player_rotation_y)
	return {
		"meta": SaveManager.build_meta(state),
		"state": state,
	}


func apply_save_dict(save_data: Dictionary) -> bool:
	var state := save_data.get("state", {}) as Dictionary
	if state.is_empty():
		return false
	difficulty = int(state.get("difficulty", Difficulty.NORMAL))
	current_area_id = str(state.get("current_area_id", NEW_GAME_AREA_ID))
	return_area_id = str(state.get("return_area_id", current_area_id))
	var pos_array: Array = state.get("return_position", [0, 0, 0]) as Array
	return_position = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
	return_rotation_y = float(state.get("return_rotation_y", 0.0))
	defeated_enemy_ids.clear()
	for enemy_id: Variant in state.get("defeated_enemy_ids", []) as Array:
		defeated_enemy_ids.append(str(enemy_id))
	visited_area_ids.clear()
	for area_id: Variant in state.get("visited_area_ids", []) as Array:
		visited_area_ids.append(str(area_id))
	collected_pickup_ids.clear()
	for pickup_id: Variant in state.get("collected_pickup_ids", []) as Array:
		collected_pickup_ids.append(str(pickup_id))
	party_members.clear()
	for member_data: Variant in state.get("party_members", []) as Array:
		var snapshot := PartyMemberSnapshot.from_dict(member_data as Dictionary)
		_ensure_mastery_defaults(snapshot)
		party_members.append(snapshot)
	inventory = (state.get("inventory", {}) as Dictionary).duplicate()
	party_formation = PartyFormationScript.parse_positions(
		state.get("party_formation", {}) as Dictionary
	)
	if str(state.get("formation_coord_space", "battle")) != "menu":
		var migrated: Dictionary = {}
		for character_id: String in party_formation.keys():
			migrated[character_id] = PartyFormationScript.battle_to_menu(party_formation[character_id])
		party_formation = migrated
	if party_formation.is_empty():
		reset_formation_to_default()
	ensure_formation_for_party()
	equipped = (state.get("equipped", {}) as Dictionary).duplicate(true)
	for character_id: String in equipped.keys():
		equipped[character_id] = _normalize_loadout(equipped[character_id] as Dictionary)
	owned_equipment = (state.get("owned_equipment", {}) as Dictionary).duplicate()
	weapon_durability = _restore_nested_int_dict(state.get("weapon_durability", {}))
	weapon_loaded_ammo = _restore_nested_int_dict(state.get("weapon_loaded_ammo", {}))
	pending_load_spawn = {
		"area_id": current_area_id,
		"position": return_position,
		"rotation_y": return_rotation_y,
	}
	pending_door_spawn = {}
	_autosave_after_door_spawn = false
	last_battle_outcome = BattleOutcomeCode.NONE
	battle_source = BattleSource.EXPLORE
	last_battle_loot.clear()
	last_battle_xp = 0
	last_level_ups.clear()
	pending_level_up_queue.clear()
	_draft_character_id = ""
	_draft_allocated = StatBlock.new()
	_draft_budget = 0
	return true


func save_to_slot(slot: int, player_position: Vector3, player_rotation_y: float) -> bool:
	last_save_error = ""
	var block_reason := get_manual_save_block_reason()
	if not block_reason.is_empty():
		last_save_error = block_reason
		return false
	var save_data := build_save_data(player_position, player_rotation_y)
	if not SaveManager.write_slot(slot, save_data):
		last_save_error = "Failed to write save file."
		return false
	if difficulty == Difficulty.HARD:
		_consume_inventory_item(SAVE_RESOURCE_ITEM_ID)
	return true


func save_autosave(player_position: Vector3, player_rotation_y: float) -> bool:
	last_save_error = ""
	if difficulty != Difficulty.EASY:
		return false
	var save_data := build_save_data(player_position, player_rotation_y)
	if not SaveManager.write_autosave(save_data):
		last_save_error = "Failed to write autosave."
		return false
	return true


func load_from_slot(slot: int) -> bool:
	last_save_error = ""
	var read_result := SaveManager.read_slot_detailed(slot)
	var status: int = int(read_result.get("status", SaveManager.SaveReadStatus.MISSING))
	if status != SaveManager.SaveReadStatus.OK:
		last_save_error = str(read_result.get("message", "Failed to load save."))
		return false
	return apply_save_dict(read_result.get("data", {}) as Dictionary)


func load_autosave() -> bool:
	last_save_error = ""
	var read_result := SaveManager.read_autosave_detailed()
	var status: int = int(read_result.get("status", SaveManager.SaveReadStatus.MISSING))
	if status != SaveManager.SaveReadStatus.OK:
		last_save_error = str(read_result.get("message", "Failed to load autosave."))
		return false
	return apply_save_dict(read_result.get("data", {}) as Dictionary)


func consume_autosave_after_door_spawn() -> bool:
	if not _autosave_after_door_spawn:
		return false
	_autosave_after_door_spawn = false
	return difficulty == Difficulty.EASY


func get_explore_spawn(area: AreaData) -> Dictionary:
	if pending_load_spawn.has("area_id") and str(pending_load_spawn["area_id"]) == area.id:
		var load_spawn := {
			"position": pending_load_spawn["position"] as Vector3,
			"rotation_y": float(pending_load_spawn["rotation_y"]),
		}
		pending_load_spawn = {}
		current_area_id = area.id
		return load_spawn
	if pending_door_spawn.has("area_id") and str(pending_door_spawn["area_id"]) == area.id:
		var door_spawn := {
			"position": pending_door_spawn["position"] as Vector3,
			"rotation_y": float(pending_door_spawn["rotation_y"]),
		}
		pending_door_spawn = {}
		current_area_id = area.id
		return door_spawn
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
	if difficulty == Difficulty.EASY:
		_autosave_after_door_spawn = true


func reset_party_to_default() -> void:
	party_members.clear()
	inventory.clear()
	party_formation.clear()
	equipped.clear()
	owned_equipment.clear()
	weapon_durability.clear()
	weapon_loaded_ammo.clear()
	defeated_enemy_ids.clear()
	visited_area_ids.clear()
	collected_pickup_ids.clear()
	difficulty = Difficulty.NORMAL
	last_battle_xp = 0
	last_level_ups.clear()
	pending_level_up_queue.clear()
	pending_load_spawn = {}
	pending_door_spawn = {}
	_autosave_after_door_spawn = false
	_draft_character_id = ""
	_draft_allocated = StatBlock.new()
	_draft_budget = 0
	inventory = get_setup_inventory()
	reset_formation_to_default()
	ensure_party_initialized(DEFAULT_ENCOUNTER_ID)


func get_setup_inventory() -> Dictionary:
	var setup := DataLoader.load_new_game_setup()
	return (setup.get("inventory", {}) as Dictionary).duplicate()


func get_party_character_ids() -> Array[String]:
	var setup := DataLoader.load_new_game_setup()
	var result: Array[String] = []
	for character_id: Variant in setup.get("party", []) as Array:
		result.append(str(character_id))
	return result


func get_default_formation() -> Dictionary:
	return DataLoader.load_default_formation()


func reset_formation_to_default() -> void:
	party_formation = get_default_formation().duplicate()


func ensure_formation_for_party() -> void:
	var defaults := get_default_formation()
	var used_cells: Dictionary = {}
	for character_id: String in get_party_character_ids():
		if party_formation.has(character_id):
			var cell: Vector2i = party_formation[character_id]
			var cell_key := "%d,%d" % [cell.x, cell.y]
			if PartyFormationScript.is_valid_cell(cell) and not used_cells.has(cell_key):
				used_cells[cell_key] = character_id
				continue
		if defaults.has(character_id):
			var default_cell: Vector2i = defaults[character_id]
			var default_key := "%d,%d" % [default_cell.x, default_cell.y]
			if PartyFormationScript.is_valid_cell(default_cell) and not used_cells.has(default_key):
				party_formation[character_id] = default_cell
				used_cells[default_key] = character_id
				continue
		for y: int in range(PartyFormationScript.ROW_MIN, PartyFormationScript.ROW_MAX + 1):
			var placed := false
			for x: int in CombatConstants.GRID_SIZE:
				var fallback := Vector2i(x, y)
				var fallback_key := "%d,%d" % [fallback.x, fallback.y]
				if used_cells.has(fallback_key):
					continue
				party_formation[character_id] = fallback
				used_cells[fallback_key] = character_id
				placed = true
				break
			if placed:
				break


func get_formation_spawn_entries() -> Array[Dictionary]:
	ensure_formation_for_party()
	return PartyFormationScript.build_spawn_entries(party_formation)


func get_formation_position(character_id: String) -> Vector2i:
	if party_formation.has(character_id):
		return party_formation[character_id]
	return Vector2i(-1, -1)


func set_formation_position(character_id: String, cell: Vector2i) -> Dictionary:
	var result := PartyFormationScript.assign_position(party_formation, character_id, cell)
	if bool(result.get("ok", false)):
		party_formation = result.get("formation", party_formation) as Dictionary
	return result


func clear_formation_position(character_id: String) -> void:
	party_formation = PartyFormationScript.clear_position(party_formation, character_id)


func get_formation_character_at(cell: Vector2i) -> String:
	return PartyFormationScript.find_character_at(party_formation, cell)


func is_enemy_defeated(enemy_id: String) -> bool:
	return enemy_id in defeated_enemy_ids


func set_standalone_battle(encounter_id: String = DEFAULT_ENCOUNTER_ID) -> void:
	battle_source = BattleSource.STANDALONE
	current_encounter_id = encounter_id
	overworld_enemy_id = ""
	last_battle_outcome = BattleOutcomeCode.NONE


func _recalculate_member_caps(character_id: String) -> void:
	var snapshot := get_member_snapshot(character_id)
	if snapshot == null:
		return
	var derived := get_derived_values(character_id)
	snapshot.max_hp = int(derived.get("max_hp", snapshot.max_hp))
	snapshot.max_mp = int(derived.get("max_mp", snapshot.max_mp))
	snapshot.current_hp = mini(snapshot.current_hp, snapshot.max_hp)
	snapshot.current_mp = mini(snapshot.current_mp, snapshot.max_mp)


func _find_equipped_location(item_id: String, skip_character_id: String, skip_slot: String) -> Dictionary:
	for owner_id: String in equipped.keys():
		var loadout: Dictionary = _normalize_loadout(equipped[owner_id] as Dictionary)
		for slot_name: String in loadout.keys():
			if owner_id == skip_character_id and slot_name == skip_slot:
				continue
			if str(loadout.get(slot_name, "")) == item_id:
				return {"character_id": owner_id, "slot_name": slot_name}
	return {}


func _normalize_loadout(loadout: Dictionary) -> Dictionary:
	var normalized := _empty_loadout()
	for slot_name: String in EquipmentDataScript.ALL_SLOTS:
		normalized[slot_name] = str(loadout.get(slot_name, ""))
	return normalized


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


func _initialize_weapon_states_for_party() -> void:
	for character_id: String in equipped.keys():
		var weapon_id := str(get_loadout(character_id).get(EquipmentDataScript.SLOT_WEAPON, ""))
		if weapon_id.is_empty():
			continue
		_ensure_weapon_state(character_id, weapon_id)


func _ensure_weapon_state(character_id: String, weapon_id: String) -> void:
	var weapons := DataLoader.load_weapons()
	if not weapons.has(weapon_id):
		return
	var weapon: WeaponData = weapons[weapon_id]
	if weapon.uses_durability():
		var durability_map := _get_durability_map(character_id)
		if not durability_map.has(weapon_id):
			durability_map[weapon_id] = weapon.durability_max
	if weapon.uses_ammo():
		var loaded_map := _get_loaded_map(character_id)
		if not loaded_map.has(weapon_id):
			loaded_map[weapon_id] = weapon.magazine_size


func _get_durability_map(character_id: String) -> Dictionary:
	if not weapon_durability.has(character_id):
		weapon_durability[character_id] = {}
	return weapon_durability[character_id] as Dictionary


func _get_loaded_map(character_id: String) -> Dictionary:
	if not weapon_loaded_ammo.has(character_id):
		weapon_loaded_ammo[character_id] = {}
	return weapon_loaded_ammo[character_id] as Dictionary


func _set_durability(character_id: String, weapon_id: String, value: int) -> void:
	_get_durability_map(character_id)[weapon_id] = maxi(value, 0)


func _set_loaded_ammo(character_id: String, weapon_id: String, value: int) -> void:
	_get_loaded_map(character_id)[weapon_id] = maxi(value, 0)


func _destroy_equipped_weapon(character_id: String) -> void:
	if not equipped.has(character_id):
		return
	var loadout: Dictionary = equipped[character_id] as Dictionary
	var weapon_id := str(loadout.get(EquipmentDataScript.SLOT_WEAPON, ""))
	if weapon_id.is_empty():
		return
	loadout[EquipmentDataScript.SLOT_WEAPON] = ""
	equipped[character_id] = loadout
	_get_durability_map(character_id).erase(weapon_id)
	_get_loaded_map(character_id).erase(weapon_id)


func _duplicate_nested_int_dict(source: Dictionary) -> Dictionary:
	var copy: Dictionary = {}
	for character_id: Variant in source.keys():
		var inner := source[character_id] as Dictionary
		copy[str(character_id)] = inner.duplicate()
	return copy


func _restore_nested_int_dict(source: Variant) -> Dictionary:
	var restored: Dictionary = {}
	if source == null or not source is Dictionary:
		return restored
	for character_id: Variant in (source as Dictionary).keys():
		var inner: Variant = (source as Dictionary)[character_id]
		if inner is Dictionary:
			restored[str(character_id)] = (inner as Dictionary).duplicate()
	return restored


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


func _get_character_name(character_id: String) -> String:
	var characters := _get_characters()
	if characters.has(character_id):
		return (characters[character_id] as CharacterData).display_name
	return character_id


func _initialize_mastery_defaults(snapshot: PartyMemberSnapshot) -> void:
	snapshot.weapon_mastery.clear()
	for weapon_class: String in MasteryConstantsScript.WEAPON_CLASSES:
		snapshot.weapon_mastery[weapon_class] = {"level": 1, "xp": 0}
	snapshot.spell_mastery.clear()
	for mastery_id: String in MasteryConstantsScript.SPELL_MASTERY_TYPES:
		snapshot.spell_mastery[mastery_id] = {"tier": 0, "xp": 0}


func _ensure_mastery_defaults(snapshot: PartyMemberSnapshot) -> void:
	_migrate_spell_mastery(snapshot)
	for weapon_class: String in MasteryConstantsScript.WEAPON_CLASSES:
		if not snapshot.weapon_mastery.has(weapon_class):
			snapshot.weapon_mastery[weapon_class] = {"level": 1, "xp": 0}
	for mastery_id: String in MasteryConstantsScript.SPELL_MASTERY_TYPES:
		if not snapshot.spell_mastery.has(mastery_id):
			snapshot.spell_mastery[mastery_id] = {"tier": 0, "xp": 0}


func _migrate_spell_mastery(snapshot: PartyMemberSnapshot) -> void:
	for spell_id: String in DataLoader.load_spells().keys():
		if not snapshot.spell_mastery.has(spell_id):
			continue
		var mastery_id := _resolve_spell_mastery_id(spell_id)
		if mastery_id.is_empty():
			snapshot.spell_mastery.erase(spell_id)
			continue
		if not snapshot.spell_mastery.has(mastery_id):
			snapshot.spell_mastery[mastery_id] = (snapshot.spell_mastery[spell_id] as Dictionary).duplicate()
		snapshot.spell_mastery.erase(spell_id)
	for legacy_id: String in ["mend", "arc_bolt"]:
		snapshot.spell_mastery.erase(legacy_id)


func _resolve_spell_mastery_id(spell_id: String) -> String:
	var spells := DataLoader.load_spells()
	if not spells.has(spell_id):
		return ""
	return (spells[spell_id] as SpellData).mastery_id


func _get_weapon_mastery_entry(character_id: String, weapon_class: String) -> Dictionary:
	var snapshot := get_member_snapshot(character_id)
	if snapshot == null:
		return {"level": 1, "xp": 0}
	_ensure_mastery_defaults(snapshot)
	if snapshot.weapon_mastery.has(weapon_class):
		return snapshot.weapon_mastery[weapon_class] as Dictionary
	return {"level": 1, "xp": 0}


func _get_spell_mastery_entry(character_id: String, mastery_id: String) -> Dictionary:
	var snapshot := get_member_snapshot(character_id)
	if snapshot == null or mastery_id.is_empty():
		return {"tier": 0, "xp": 0}
	_ensure_mastery_defaults(snapshot)
	if snapshot.spell_mastery.has(mastery_id):
		return snapshot.spell_mastery[mastery_id] as Dictionary
	return {"tier": 0, "xp": 0}


func _apply_encounter_spell_unlocks(encounter_id: String) -> void:
	var encounter := DataLoader.load_encounter(encounter_id)
	for unlock_entry: Dictionary in encounter.spell_unlocks:
		var character_id := str(unlock_entry.get("character_id", ""))
		var spell_id := str(unlock_entry.get("spell_id", ""))
		if character_id.is_empty() or spell_id.is_empty():
			continue
		unlock_spell_for_character(character_id, spell_id)
