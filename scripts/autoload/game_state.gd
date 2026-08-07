extends Node

enum BattleSource { STANDALONE, EXPLORE }

enum BattleOutcomeCode { NONE = 0, VICTORY = 1, DEFEAT = 2, ESCAPED = 3 }

const DEFAULT_ENCOUNTER_ID: String = "test_4v3"

var battle_source: BattleSource = BattleSource.STANDALONE
var current_encounter_id: String = DEFAULT_ENCOUNTER_ID
var return_area_id: String = "test_room"
var return_position: Vector3 = Vector3.ZERO
var return_rotation_y: float = 0.0
var overworld_enemy_id: String = ""
var defeated_enemy_ids: Array[String] = []
var party_members: Array = []
var inventory: Dictionary = {}
var has_checkpoint: bool = false
var last_battle_outcome: int = BattleOutcomeCode.NONE
var reload_from_checkpoint_on_explore_start: bool = false
var post_battle_contact_immune_until_msec: int = 0
var pending_door_spawn: Dictionary = {}

const POST_BATTLE_CONTACT_IMMUNITY_MS: int = 2500

var _checkpoint: ExploreCheckpointData = ExploreCheckpointData.new()


func ensure_party_initialized(encounter_id: String = DEFAULT_ENCOUNTER_ID) -> void:
	if not party_members.is_empty():
		return
	var encounter := DataLoader.load_encounter(encounter_id)
	inventory = encounter.party_inventory.duplicate()
	var characters := DataLoader.load_characters()
	var weapons := DataLoader.load_weapons()
	for ally_entry: Dictionary in encounter.allies:
		var character_id := str(ally_entry.get("character_id", ""))
		if not characters.has(character_id):
			continue
		var character: CharacterData = characters[character_id]
		var weapon: WeaponData = weapons[character.weapon_id]
		var stats := character.stats.get_bonus(weapon.stat_bonuses)
		var snapshot: PartyMemberSnapshot = PartyMemberSnapshot.new()
		snapshot.character_id = character_id
		snapshot.max_hp = CombatConstants.HP_BASE + stats.vit * CombatConstants.HP_PER_VIT
		snapshot.current_hp = snapshot.max_hp
		snapshot.max_mp = CombatConstants.MP_BASE + stats.res * CombatConstants.MP_PER_RES
		snapshot.current_mp = snapshot.max_mp
		party_members.append(snapshot)


func enter_battle(
	area_id: String,
	return_pos: Vector3,
	return_rot_y: float,
	encounter_id: String,
	enemy_id: String
) -> void:
	battle_source = BattleSource.EXPLORE
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
	match outcome:
		BattleOutcomeCode.VICTORY:
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
	_checkpoint.defeated_enemy_ids = defeated_enemy_ids.duplicate()
	has_checkpoint = true


func load_checkpoint() -> void:
	if not has_checkpoint:
		return
	return_area_id = _checkpoint.area_id
	return_position = _checkpoint.position
	return_rotation_y = _checkpoint.rotation_y
	party_members.clear()
	for member: Variant in _checkpoint.party_members:
		var snapshot := member as PartyMemberSnapshot
		party_members.append(PartyMemberSnapshot.from_dict(snapshot.to_dict()))
	inventory = _checkpoint.inventory.duplicate()
	defeated_enemy_ids = _checkpoint.defeated_enemy_ids.duplicate()
	reload_from_checkpoint_on_explore_start = true


func get_explore_spawn(area: AreaData) -> Dictionary:
	if pending_door_spawn.has("area_id") and str(pending_door_spawn["area_id"]) == area.id:
		var door_spawn := {
			"position": pending_door_spawn["position"] as Vector3,
			"rotation_y": float(pending_door_spawn["rotation_y"]),
		}
		pending_door_spawn = {}
		return door_spawn
	if reload_from_checkpoint_on_explore_start and has_checkpoint:
		reload_from_checkpoint_on_explore_start = false
		return {
			"position": _checkpoint.position,
			"rotation_y": _checkpoint.rotation_y,
		}
	if last_battle_outcome == BattleOutcomeCode.DEFEAT and has_checkpoint:
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
		return spawn
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
	pending_door_spawn = {
		"area_id": area_id,
		"position": spawn_pos,
		"rotation_y": spawn_rot_y,
	}


func reset_party_to_default() -> void:
	party_members.clear()
	inventory.clear()
	defeated_enemy_ids.clear()
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
