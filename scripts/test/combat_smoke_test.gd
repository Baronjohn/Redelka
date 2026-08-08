extends SceneTree

## Headless smoke test for Phase 1 combat data and formulas.

const PartyStatsHelper = preload("res://scripts/data/party_stats.gd")
const ProgressionConstantsScript = preload("res://scripts/data/progression_constants.gd")
const MasteryConstantsScript = preload("res://scripts/data/mastery_constants.gd")
const PartyFormationScript = preload("res://scripts/data/party_formation.gd")


func _get_setup_weapon(character_id: String) -> WeaponData:
	var setup := DataLoader.load_new_game_setup()
	var loadouts: Dictionary = setup.get("loadouts", {}) as Dictionary
	var loadout: Dictionary = loadouts.get(character_id, {}) as Dictionary
	var weapon_id := str(loadout.get("weapon", ""))
	return DataLoader.load_weapons()[weapon_id] as WeaponData


func _initialize() -> void:
	var errors: PackedStringArray = []
	errors.append_array(_test_data_loading())
	errors.append_array(_test_combat_formulas())
	errors.append_array(_test_turn_queue())
	errors.append_array(_test_battle_grid())
	errors.append_array(_test_explore_handoff())
	errors.append_array(_test_character_menu_system())
	errors.append_array(_test_pickups_and_loot())
	errors.append_array(_test_progression())
	errors.append_array(_test_save_load())
	errors.append_array(_test_weapon_durability_and_ammo())
	errors.append_array(_test_mastery_and_spell_tiers())
	errors.append_array(_test_chapter_data())

	if errors.is_empty():
		print("Combat smoke test passed.")
		quit(0)
	else:
		for message: String in errors:
			push_error(message)
		quit(1)


func _test_data_loading() -> PackedStringArray:
	var errors: PackedStringArray = []
	if DataLoader.load_characters().size() != 4:
		errors.append("Expected 4 characters.")
	if DataLoader.load_enemies().size() != 4:
		errors.append("Expected 4 enemies.")
	for enemy: EnemyData in DataLoader.load_enemies().values():
		if enemy.actions.is_empty():
			errors.append("Enemy %s should define actions." % enemy.id)
		if enemy.get_action_chance_total() != 100:
			errors.append("Enemy %s action chances should total 100." % enemy.id)
		if enemy.dex <= 0:
			errors.append("Enemy %s should define positive DEX." % enemy.id)
	if DataLoader.load_spells().size() < 1:
		errors.append("Expected at least 1 spell.")
	var setup := DataLoader.load_new_game_setup()
	if not setup.has("loadouts"):
		errors.append("New game setup should define loadouts.")
	if DataLoader.load_items().size() < 6:
		errors.append("Expected merged item definitions from split JSON files.")
	var attributes := DataLoader.load_attributes()
	if attributes.get("primary_attributes", []).size() != 8:
		errors.append("attributes.json should define 8 primary attributes.")
	var default_formation := DataLoader.load_default_formation()
	if default_formation.size() != 4:
		errors.append("formation.json should define 4 starting positions.")
	for cell: Vector2i in default_formation.values():
		if not PartyFormationScript.is_valid_cell(cell):
			errors.append("Default formation positions must use the first two rows.")
	var encounter := DataLoader.load_encounter("test_4v3")
	if encounter.enemies.size() != 3:
		errors.append("Encounter test_4v3 has wrong enemy count.")
	return errors


func _test_combat_formulas() -> PackedStringArray:
	var errors: PackedStringArray = []
	var characters := DataLoader.load_characters()
	var skills := DataLoader.load_skills()
	var bran: CharacterData = characters["ally_1"]
	var bran_skill: SkillData = null
	if not bran.skill_id.is_empty() and skills.has(bran.skill_id):
		bran_skill = skills[bran.skill_id]
	var unit := CombatUnit.from_character(
		"ally_1",
		bran,
		_get_setup_weapon("ally_1"),
		bran_skill,
		Vector2i(0, 0)
	)
	var enemy := CombatUnit.from_enemy(
		"enemy_1",
		DataLoader.load_enemies()["enemy_1"],
		Vector2i(2, 4)
	)

	var hit := CombatResolver.physical_hit_chance(unit, enemy)
	if hit < CombatConstants.HIT_FLOOR or hit > CombatConstants.HIT_CEILING:
		errors.append("Physical hit chance out of bounds.")
	var ally_vs_enemy_hit := CombatConstants.BASE_HIT + float(unit.stats.dex)
	if absf(hit - ally_vs_enemy_hit) > 0.01:
		errors.append("Allies attacking enemies should ignore enemy DEX evasion.")
	var enemy_vs_ally_hit := CombatResolver.physical_hit_chance(enemy, unit)
	var expected_enemy_hit := (
		CombatConstants.BASE_HIT
		+ float(enemy.enemy_data.dex)
		- (float(unit.stats.dex) + float(unit.stats.luk) * CombatConstants.LUK_WEIGHT)
	)
	expected_enemy_hit = clampf(expected_enemy_hit, CombatConstants.HIT_FLOOR, CombatConstants.HIT_CEILING)
	if absf(enemy_vs_ally_hit - expected_enemy_hit) > 0.01:
		errors.append("Enemy attacks should use enemy DEX against ally evasion.")

	var attack := CombatResolver.resolve_physical_attack(unit, enemy)
	if not attack.has("hit") or not attack.has("damage"):
		errors.append("Physical attack result missing keys.")

	var firebolt: SpellData = DataLoader.load_spells()["firebolt"]
	var spell := CombatResolver.resolve_spell(unit, enemy, firebolt)
	if not spell.has("amount"):
		errors.append("Spell result missing amount.")

	var endure_skill: SkillData = skills["endure"]
	if not endure_skill.endure:
		errors.append("Endure skill should be flagged as endure.")
	var mira: CharacterData = characters["ally_2"]
	var enduring_unit := CombatUnit.from_character(
		"ally_2",
		mira,
		_get_setup_weapon("ally_2"),
		endure_skill,
		Vector2i.ZERO,
	)
	enduring_unit.current_hp = 100
	enduring_unit.set_enduring(true)
	enduring_unit.apply_damage(20)
	if enduring_unit.current_hp != 90:
		errors.append("Endure should halve incoming damage.")
	if enduring_unit.is_enduring:
		errors.append("Endure should clear after taking damage.")

	if not CombatResolver.resolve_retreat(unit) in [true, false]:
		errors.append("Retreat must return bool.")

	var howl := EnemyActionData.new()
	howl.stat_name = "str"
	howl.amount = -3
	var debuff_target := CombatUnit.from_character(
		"ally_1",
		bran,
		_get_setup_weapon("ally_1"),
		bran_skill,
		Vector2i.ZERO,
	)
	debuff_target.stats.str = 12
	var debuff_result := CombatResolver.resolve_enemy_debuff(howl, [debuff_target])
	if not bool(debuff_result.get("ok", false)):
		errors.append("Enemy debuff should reduce ally stats.")
	if debuff_target.stats.str != 9:
		errors.append("Howl should reduce ally STR by 3.")
	return errors


func _test_turn_queue() -> PackedStringArray:
	var errors: PackedStringArray = []
	var units: Array[CombatUnit] = []
	var characters := DataLoader.load_characters()
	var skills := DataLoader.load_skills()
	for character: CharacterData in characters.values():
		var skill: SkillData = null
		if not character.skill_id.is_empty() and skills.has(character.skill_id):
			skill = skills[character.skill_id]
		units.append(
			CombatUnit.from_character(
				character.id,
				character,
				_get_setup_weapon(character.id),
				skill,
				Vector2i.ZERO
			)
		)
	var queue := TurnQueue.new()
	queue.build_queue(units)
	if queue.peek_current().is_empty():
		errors.append("Turn queue should not be empty.")
	if queue.get_display_order().size() < units.size():
		errors.append("Turn queue order too short.")
	return errors


func _test_battle_grid() -> PackedStringArray:
	var errors: PackedStringArray = []
	var grid := BattleGrid.new()
	grid.set_occupant(Vector2i(0, 0), "a")
	grid.set_occupant(Vector2i(4, 4), "b")
	var reachable := grid.get_reachable_cells(Vector2i(0, 0), 2, "a")
	if reachable.is_empty():
		errors.append("Reachable cells should not be empty from origin.")
	if grid.get_occupant(Vector2i(0, 0)) != "a":
		errors.append("Grid occupancy mismatch.")

	if not grid.is_melee_adjacent(Vector2i(0, 0), Vector2i(1, 1)):
		errors.append("Melee should allow diagonal adjacency.")
	if grid.can_attack_cell(Vector2i(0, 0), Vector2i(2, 0), 1):
		errors.append("Melee should not reach two tiles away.")

	grid.set_occupant(Vector2i(1, 0), "blocker")
	if grid.can_attack_cell(Vector2i(0, 0), Vector2i(3, 0), 3):
		errors.append("Ranged attack should be blocked by intervening unit.")
	if not grid.can_attack_cell(Vector2i(0, 0), Vector2i(3, 0), 3):
		pass
	grid.set_occupant(Vector2i(1, 0), "")
	if not grid.can_attack_cell(Vector2i(0, 0), Vector2i(3, 0), 3):
		errors.append("Clear ranged straight line should be valid.")
	if grid.can_attack_cell(Vector2i(0, 0), Vector2i(2, 1), 3):
		errors.append("Ranged attack should require straight or diagonal path.")

	grid.set_occupant(Vector2i(1, 3), "enemy")
	var ally_reach := grid.get_reachable_cells(Vector2i(1, 1), 3, "ally", 0, 2)
	for cell: Vector2i in ally_reach:
		if cell.y >= 3:
			errors.append("Allies should not move into enemy rows.")
	return errors


func _test_explore_handoff() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs: Node = get_root().get_node("GameState")
	var area := DataLoader.load_area("test_room")
	if area.id != "test_room":
		errors.append("Area test_room failed to load.")
	if area.enemies.is_empty():
		errors.append("Area test_room should define enemies.")

	var room_encounter := DataLoader.load_encounter("test_room_wretch")
	if room_encounter.enemies.size() != 3:
		errors.append("Encounter test_room_wretch should have three enemies.")

	gs.call("reset_party_to_default")
	if int(gs.get("party_members").size()) != 4:
		errors.append("Party init should create four members.")

	gs.call("enter_battle", "test_room", Vector3(1, 0, 2), 0.5, "test_room_wretch", "room_wretch")
	if int(gs.get("battle_source")) != 1:
		errors.append("Battle source should be EXPLORE after enter_battle.")
	if str(gs.get("current_encounter_id")) != "test_room_wretch":
		errors.append("Encounter id not stored for explore battle.")

	gs.call("save_to_slot", 1, Vector3(2, 0, -8), 0.0)
	var slot_meta: Dictionary = SaveManager.get_slot_metadata(1)
	if slot_meta.is_empty():
		errors.append("Manual save should write slot metadata.")

	var bran_snapshot = gs.call("get_member_snapshot", "ally_1")
	if bran_snapshot == null:
		errors.append("Expected ally_1 in party snapshot.")
		return errors

	gs.call("resolve_battle", 1)
	if not bool(gs.call("is_enemy_defeated", "room_wretch")):
		errors.append("Victory should mark overworld enemy defeated.")

	gs.call("enter_battle", "test_room", Vector3(5, 0, -2), 0.0, "test_room_wretch", "room_wretch")
	gs.call("resolve_battle", 3)
	if not bool(gs.call("is_post_battle_contact_immune")):
		errors.append("Retreat should grant post-battle contact immunity.")
	var escaped_spawn: Dictionary = gs.call("get_explore_spawn", area)
	if (escaped_spawn["position"] as Vector3).distance_to(Vector3(5, 0, -2)) > 0.01:
		errors.append("Retreat spawn should restore battle return position.")

	var adjacent_area := DataLoader.load_area("adjacent_room")
	if adjacent_area.id != "adjacent_room":
		errors.append("Adjacent room area should load from areas.json.")

	gs.call("travel_to_area", "adjacent_room", Vector3(-8, 0, 0), -1.5707964)
	var door_spawn: Dictionary = gs.call("get_explore_spawn", adjacent_area)
	if (door_spawn["position"] as Vector3).distance_to(Vector3(-8, 0, 0)) > 0.01:
		errors.append("Door travel should spawn at target door position.")

	bran_snapshot.current_hp = 1
	gs.call("resolve_battle", 2)
	var after_defeat = gs.call("get_member_snapshot", "ally_1")
	if after_defeat == null or after_defeat.current_hp != 1:
		errors.append("Defeat should not restore party from removed session checkpoint.")

	gs.call("reset_party_to_default")
	return errors


func _test_character_menu_system() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs: Node = get_root().get_node("GameState")
	gs.call("reset_party_to_default")

	var equipment := DataLoader.load_equipment()
	if equipment.is_empty():
		errors.append("Equipment data should load.")

	var setup := DataLoader.load_new_game_setup()
	if not setup.has("loadouts"):
		errors.append("New game setup should define loadouts.")

	var loadout: Dictionary = gs.call("get_loadout", "ally_1")
	if str(loadout.get("weapon", "")).is_empty():
		errors.append("Ally 1 should start with a weapon equipped.")

	var effective: StatBlock = gs.call("get_effective_stats", "ally_1")
	if effective.str <= 0:
		errors.append("Effective stats should include equipment bonuses.")

	var use_result: String = gs.call("use_item_outside_battle", "heal_potion", "ally_1")
	if use_result.is_empty():
		errors.append("Out-of-battle item use should return a message.")

	gs.call("mark_area_visited", "test_room")
	if not bool(gs.call("is_area_visited", "test_room")):
		errors.append("Visited area tracking should work.")

	if bool(gs.call("is_area_cleared", "test_room")):
		errors.append("Uncleared test room should not report cleared before enemies defeated.")

	if not bool(gs.call("is_area_cleared", "test_room")):
		var defeated: Array = gs.get("defeated_enemy_ids")
		defeated.append("room_wretch")
		gs.set("defeated_enemy_ids", defeated)
		if not bool(gs.call("is_area_cleared", "test_room")):
			errors.append("Test room should clear after its enemy is defeated.")

	var adjacent := DataLoader.load_area("adjacent_room")
	if adjacent.map_position.x <= 0.0:
		errors.append("Adjacent room should define custom map layout.")

	var weapon_candidates: Array = gs.call("get_owned_items_for_slot", "weapon", "ally_2")
	if "iron_sword" not in weapon_candidates:
		errors.append("Equipped weapons should be equippable by other party members.")

	var transfer_result: String = gs.call("equip_item", "ally_2", "weapon", "iron_sword")
	if transfer_result != "Equipped.":
		errors.append("Weapon transfer between allies should succeed.")
	if str(gs.call("get_loadout", "ally_2").get("weapon", "")) != "iron_sword":
		errors.append("Transferred weapon should appear on the target ally.")
	if not str(gs.call("get_loadout", "ally_1").get("weapon", "")).is_empty():
		errors.append("Weapon transfer should unequip the previous wearer.")

	var unequip_result: String = gs.call("unequip_slot", "ally_2", "weapon")
	if unequip_result != "Unequipped.":
		errors.append("Unequip should succeed after transfer.")
	if int(gs.get("owned_equipment").get("iron_sword", 0)) != 1:
		errors.append("Unequipped weapon should return to the owned pool.")

	var duplicate_candidates: Array = gs.call(
		"get_equipment_candidates_for_slot",
		"ally_1",
		"accessory_1",
	)
	var equipped_labels := 0
	var pool_labels := 0
	for candidate_variant: Variant in duplicate_candidates:
		var candidate: Dictionary = candidate_variant as Dictionary
		if str(candidate.get("item_id", "")) != "power_ring":
			continue
		match str(candidate.get("source", "")):
			"current":
				equipped_labels += 1
			"pool":
				pool_labels += 1
	if equipped_labels != 1:
		errors.append("Accessory slot should show exactly one equipped Power Ring.")
	if pool_labels != 1:
		errors.append("Accessory slot should show exactly one spare Power Ring in the pool.")

	var second_slot_candidates: Array = gs.call(
		"get_equipment_candidates_for_slot",
		"ally_1",
		"accessory_2",
	)
	equipped_labels = 0
	pool_labels = 0
	for candidate_variant: Variant in second_slot_candidates:
		var candidate: Dictionary = candidate_variant as Dictionary
		if str(candidate.get("item_id", "")) != "power_ring":
			continue
		match str(candidate.get("source", "")):
			"current":
				equipped_labels += 1
			"pool":
				pool_labels += 1
			"equipped":
				if (
					str(candidate.get("owner_id", "")) == "ally_1"
					and str(candidate.get("owner_slot", "")) == "accessory_1"
				):
					equipped_labels += 1
	if equipped_labels != 1:
		errors.append("Second accessory slot should show the Power Ring from the first slot.")
	if pool_labels != 1:
		errors.append("Second accessory slot should show the spare Power Ring in the pool.")

	var spawn_entries: Array = gs.call("get_formation_spawn_entries")
	if spawn_entries.size() != 4:
		errors.append("Formation should provide one spawn entry per party member.")
	var used_cells: Dictionary = {}
	for entry_variant: Variant in spawn_entries:
		var entry: Dictionary = entry_variant as Dictionary
		var pos_array: Array = entry.get("position", []) as Array
		if pos_array.size() < 2:
			errors.append("Formation spawn entry missing position.")
			continue
		var cell := Vector2i(int(pos_array[0]), int(pos_array[1]))
		if cell.y < PartyFormationScript.ROW_MIN or cell.y > PartyFormationScript.ROW_MAX:
			errors.append("Formation battle spawn positions must use the first two rows.")
		var cell_key := "%d,%d" % [cell.x, cell.y]
		if used_cells.has(cell_key):
			errors.append("Formation should allow only one character per tile.")
		used_cells[cell_key] = true
	if gs.call("get_formation_position", "ally_1") != Vector2i(5, 0):
		errors.append("Default formation should store menu coordinates for battle-left spawn.")
	var ally_1_spawn: Vector2i = Vector2i(-1, -1)
	for entry_variant: Variant in spawn_entries:
		var entry: Dictionary = entry_variant as Dictionary
		if str(entry.get("character_id", "")) != "ally_1":
			continue
		var pos_array: Array = entry.get("position", []) as Array
		ally_1_spawn = Vector2i(int(pos_array[0]), int(pos_array[1]))
	if ally_1_spawn != Vector2i(0, 0):
		errors.append("Menu X should mirror once when converting to battle spawn coordinates.")

	var move_result: Dictionary = gs.call("set_formation_position", "ally_1", Vector2i(3, 1))
	if not bool(move_result.get("ok", false)):
		errors.append("Moving a character to a valid tile should succeed.")
	if gs.call("get_formation_position", "ally_1") != Vector2i(3, 1):
		errors.append("Formation position should update for the selected character.")

	var blocked_result: Dictionary = gs.call("set_formation_position", "ally_1", Vector2i(3, 5))
	if bool(blocked_result.get("ok", false)):
		errors.append("Formation should reject tiles outside the first two rows.")

	gs.call("reset_party_to_default")
	return errors


func _test_pickups_and_loot() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs: Node = get_root().get_node("GameState")
	gs.call("reset_party_to_default")

	var area := DataLoader.load_area("test_room")
	if area.pickups.is_empty():
		errors.append("Test room should define pickups.")

	var enemies := DataLoader.load_enemies()
	var wretch: EnemyData = enemies["enemy_2"]
	if wretch.drops.is_empty():
		errors.append("Wretch should define loot drops.")

	if bool(gs.call("has_item", "adjacent_room_key")):
		errors.append("Party should not start with adjacent room key.")

	var potion_before := int(gs.get("inventory").get("heal_potion", 0))
	var collect_result: String = gs.call("collect_pickup", "smoke_potion_pickup", "heal_potion", 1)
	if collect_result.is_empty():
		errors.append("Pickup collection should return a message.")
	if int(gs.get("inventory").get("heal_potion", 0)) != potion_before + 1:
		errors.append("Consumable pickup should increase inventory count.")

	var duplicate_result: String = gs.call("collect_pickup", "smoke_potion_pickup", "heal_potion", 1)
	if duplicate_result != "Already collected.":
		errors.append("Duplicate pickup should be rejected.")
	if int(gs.get("inventory").get("heal_potion", 0)) != potion_before + 1:
		errors.append("Duplicate pickup should not increase inventory count.")

	var helm_before := int(gs.get("owned_equipment").get("iron_helm", 0))
	gs.call("collect_pickup", "smoke_equip_pickup", "iron_helm", 1)
	if int(gs.get("owned_equipment").get("iron_helm", 0)) != helm_before + 1:
		errors.append("Equipment pickup should increase owned equipment pool.")

	gs.get("inventory")["adjacent_room_key"] = 1
	if not bool(gs.call("has_item", "adjacent_room_key")):
		errors.append("has_item should detect key items in inventory.")

	gs.call("save_to_slot", 1, Vector3(2, 0, -8), 0.0)
	gs.set("inventory", {})
	gs.set("collected_pickup_ids", [])
	if not bool(gs.call("load_from_slot", 1)):
		errors.append("Load from slot should restore saved game state.")
	if not bool(gs.call("is_pickup_collected", "smoke_potion_pickup")):
		errors.append("Loaded save should restore collected pickup ids.")
	if not bool(gs.call("has_item", "adjacent_room_key")):
		errors.append("Loaded save should restore key item inventory.")

	seed(0)
	var got_loot := false
	for _attempt: int in range(32):
		gs.call("reset_party_to_default")
		var loot: Array = gs.call("roll_encounter_loot", "test_room_wretch")
		if not loot.is_empty():
			got_loot = true
			break
	if not got_loot:
		errors.append("Encounter loot roll should eventually grant drops.")

	gs.call("reset_party_to_default")
	return errors


func _test_progression() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs: Node = get_root().get_node("GameState")
	gs.call("reset_party_to_default")

	var enemies := DataLoader.load_enemies()
	if (enemies["enemy_2"] as EnemyData).xp_reward <= 0:
		errors.append("Enemy should define xp_reward.")

	var characters := DataLoader.load_characters()
	var bran_char: CharacterData = characters["ally_1"]
	if bran_char.level_growth.is_empty():
		errors.append("Character should define level_growth.")

	var encounter_xp: int = gs.call("roll_encounter_xp", "test_room_wretch")
	if encounter_xp < 100:
		errors.append("Explore encounter XP should reach level-up threshold.")

	var bran := gs.call("get_member_snapshot", "ally_1") as PartyMemberSnapshot
	var old_level := bran.level
	gs.call("grant_xp_to_party", 200)
	if bran.level <= old_level:
		errors.append("200 XP should level ally_1.")
	if bran.unspent_stat_points != ProgressionConstantsScript.POINTS_PER_LEVEL:
		errors.append("Single level-up should grant four stat points.")
	if not bool(gs.call("has_pending_level_ups")):
		errors.append("Level-up should queue stat allocation after XP grant.")

	var progression_before := PartyStatsHelper.get_progression_stats(bran_char, bran)
	gs.call("begin_level_up_allocation", "ally_1")
	for _i: int in range(ProgressionConstantsScript.POINTS_PER_LEVEL):
		gs.call("draft_allocate_stat", "str")
	if str(gs.call("confirm_draft_allocation")).is_empty():
		errors.append("Confirm should succeed when all points are allocated.")
	if bran.unspent_stat_points != 0:
		errors.append("Confirm should clear unspent stat points.")
	if bran.allocated_stats.str != ProgressionConstantsScript.POINTS_PER_LEVEL:
		errors.append("Confirmed allocation should update allocated_stats.")

	var progression_after := PartyStatsHelper.get_progression_stats(bran_char, bran)
	if progression_after.str <= progression_before.str:
		errors.append("Confirmed allocation should increase progression stats.")

	gs.call("grant_xp_to_party", 200)
	bran.current_hp = 1
	var pre_confirm_max_hp := bran.max_hp
	gs.call("begin_level_up_allocation", "ally_1")
	for _i: int in range(ProgressionConstantsScript.POINTS_PER_LEVEL):
		gs.call("draft_allocate_stat", "vit")
	gs.call("confirm_draft_allocation")
	if bran.current_hp != bran.max_hp:
		errors.append("Level-up heal should restore HP after stat allocation is confirmed.")
	if bran.max_hp <= pre_confirm_max_hp:
		errors.append("Level-up heal should apply after final allocated stats update max HP.")

	bran.unspent_stat_points = ProgressionConstantsScript.POINTS_PER_LEVEL
	gs.call("begin_level_up_allocation", "ally_1")
	gs.call("draft_allocate_stat", "str")
	if not str(gs.call("confirm_draft_allocation")).is_empty():
		errors.append("Confirm should fail while points remain unspent.")

	bran.unspent_stat_points = ProgressionConstantsScript.POINTS_PER_LEVEL
	gs.call("begin_level_up_allocation", "ally_1")
	gs.call("draft_allocate_stat", "vit")
	gs.call("reset_draft_allocation")
	for _i: int in range(ProgressionConstantsScript.POINTS_PER_LEVEL):
		gs.call("draft_allocate_stat", "dex")
	gs.call("confirm_draft_allocation")
	if bran.allocated_stats.dex != ProgressionConstantsScript.POINTS_PER_LEVEL:
		errors.append("Reset draft should discard prior draft points.")
	if bran.allocated_stats.vit != 0:
		errors.append("Reset draft should not commit discarded draft points.")

	var effective: StatBlock = gs.call("get_effective_stats", "ally_1")
	if effective.str <= bran_char.stats.str:
		errors.append("Effective stats should reflect progression and equipment.")

	gs.call("reset_party_to_default")
	gs.set("current_encounter_id", "test_4v3")
	gs.call("grant_xp_to_party", 200)
	if not bool(gs.call("has_pending_level_ups")):
		errors.append("Victory XP grant should queue stat allocation.")
	gs.call("resolve_battle", GameState.BattleOutcomeCode.VICTORY)
	if not bool(gs.call("has_pending_level_ups")):
		errors.append("Victory resolve should keep pending level-ups while points remain unspent.")
	gs.call("resolve_battle", GameState.BattleOutcomeCode.VICTORY)
	if not bool(gs.call("has_pending_level_ups")):
		errors.append("Duplicate resolve_battle should not clear pending level-up queue.")

	gs.call("reset_party_to_default")
	return errors


func _test_save_load() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs: Node = get_root().get_node("GameState")
	gs.call("reset_party_to_default")
	gs.call("start_new_game", GameState.Difficulty.NORMAL)
	gs.set("current_area_id", "test_room")
	gs.set("return_position", Vector3(3, 0, 4))
	gs.set("return_rotation_y", 1.25)
	gs.get("inventory")["heal_potion"] = 5

	var save_data: Dictionary = gs.call("build_save_data", Vector3(3, 0, 4), 1.25)
	gs.get("inventory")["heal_potion"] = 0
	if not bool(gs.call("apply_save_dict", save_data)):
		errors.append("apply_save_dict should restore saved state.")
	if int(gs.get("inventory").get("heal_potion", 0)) != 5:
		errors.append("Save roundtrip should restore inventory.")
	gs.get("party_formation")["ally_1"] = Vector2i(2, 1)
	var formation_save: Dictionary = gs.call("build_save_data", Vector3(3, 0, 4), 1.25)
	gs.call("reset_formation_to_default")
	if bool(gs.call("apply_save_dict", formation_save)):
		if gs.call("get_formation_position", "ally_1") != Vector2i(2, 1):
			errors.append("Save roundtrip should restore party formation.")
	else:
		errors.append("apply_save_dict should restore saved formation.")

	if not bool(gs.call("save_to_slot", 7, Vector3(1, 0, 2), 0.0)):
		errors.append("save_to_slot should write a manual save.")
	var slot_meta: Dictionary = SaveManager.get_slot_metadata(7)
	if slot_meta.is_empty() or int(slot_meta.get("party_level", 0)) < 1:
		errors.append("Manual save metadata should include party level.")
	if int(slot_meta.get("difficulty", -1)) != GameState.Difficulty.NORMAL:
		errors.append("Manual save metadata should include difficulty.")

	gs.set("difficulty", GameState.Difficulty.NORMAL)
	if bool(gs.call("save_autosave", Vector3(1, 0, 1), 0.0)):
		errors.append("Autosave should be disabled outside Easy difficulty.")

	gs.set("difficulty", GameState.Difficulty.EASY)
	if not bool(gs.call("save_autosave", Vector3(2, 0, 2), 0.0)):
		errors.append("Autosave should succeed on Easy difficulty.")
	if not SaveManager.has_autosave():
		errors.append("Autosave file should exist after writing.")
	if not bool(gs.call("save_autosave", Vector3(4, 0, 4), 0.0)):
		errors.append("Autosave overwrite should succeed.")

	var corrupt_path: String = SaveManager.slot_path(8)
	SaveManager.write_save(corrupt_path, {"broken": true})
	if SaveManager.get_slot_read_status(8) != SaveManager.SaveReadStatus.INVALID:
		errors.append("Invalid save structure should be detected.")
	if bool(gs.call("load_from_slot", 8)):
		errors.append("Invalid save should not load.")
	if str(gs.get("last_save_error")).is_empty():
		errors.append("Failed load should set last_save_error.")

	var corrupt_file := FileAccess.open(SaveManager.slot_path(10), FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{not json")
	if SaveManager.get_slot_read_status(10) != SaveManager.SaveReadStatus.CORRUPT:
		errors.append("Corrupt JSON save should be detected.")

	gs.call("start_new_game", GameState.Difficulty.HARD)
	if bool(gs.call("save_to_slot", 9, Vector3(1, 0, 1), 0.0)):
		errors.append("Hard save should require Memory Tape.")
	gs.get("inventory")["memory_tape"] = 1
	if not bool(gs.call("save_to_slot", 9, Vector3(1, 0, 1), 0.0)):
		errors.append("Hard save should succeed with Memory Tape.")
	if int(gs.get("inventory").get("memory_tape", 0)) != 0:
		errors.append("Hard save should consume Memory Tape.")

	gs.call("reset_party_to_default")
	return errors


func _test_weapon_durability_and_ammo() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs: Node = get_root().get_node("GameState")
	gs.call("reset_party_to_default")

	var weapons := DataLoader.load_weapons()
	var sword: WeaponData = weapons["iron_sword"]
	var bow: WeaponData = weapons["short_bow"]
	if not sword.uses_durability():
		errors.append("Melee weapons should use durability.")
	if not bow.uses_ammo():
		errors.append("Ranged weapons should use ammo.")
	if bow.ammo_item_id != "arrow":
		errors.append("Short bow should consume arrows.")

	if int(gs.call("get_weapon_loaded_ammo", "ally_3", "short_bow")) != bow.magazine_size:
		errors.append("Equipped bow should start fully loaded.")

	var ammo_attack: Dictionary = gs.call("consume_attack_resource", "ally_3")
	if not bool(ammo_attack.get("ok", false)):
		errors.append("Bow attack should consume loaded ammo.")
	var loaded_after_attack := int(gs.call("get_weapon_loaded_ammo", "ally_3", "short_bow"))
	if loaded_after_attack != bow.magazine_size - 1:
		errors.append("Bow ammo should decrement by one per attack.")

	gs.get("weapon_loaded_ammo")["ally_3"]["short_bow"] = 0
	if bool(gs.call("can_attack_with_equipped_weapon", "ally_3")):
		errors.append("Empty bow should disable attacks.")

	gs.get("inventory")["arrow"] = 4
	var reload_result: Dictionary = gs.call("reload_equipped_weapon", "ally_3")
	if not bool(reload_result.get("ok", false)):
		errors.append("Reload should succeed with arrows in inventory.")
	if int(gs.call("get_weapon_loaded_ammo", "ally_3", "short_bow")) != mini(bow.magazine_size, 4):
		errors.append("Reload should transfer available arrows into the magazine.")
	if int(gs.get("inventory").get("arrow", 0)) != 0:
		errors.append("Reload should consume inventory arrows.")

	gs.get("inventory")["arrow"] = 2
	if not bool(gs.call("can_reload_with_ammo", "ally_3", "arrow")):
		errors.append("Partially loaded bow should accept more arrows.")
	gs.get("inventory")["arrow"] = 10
	var outside_reload: String = gs.call("use_item_outside_battle", "arrow", "ally_3")
	if outside_reload.is_empty():
		errors.append("Outside battle ammo use should return a message.")
	if int(gs.call("get_weapon_loaded_ammo", "ally_3", "short_bow")) != bow.magazine_size:
		errors.append("Outside battle reload should fill the magazine.")

	gs.get("weapon_durability")["ally_1"]["iron_sword"] = 1
	var break_result: Dictionary = gs.call("consume_attack_resource", "ally_1")
	if not bool(break_result.get("ok", false)) or not bool(break_result.get("broke", false)):
		errors.append("Final durability hit should break the weapon.")
	if bool(gs.call("can_attack_with_equipped_weapon", "ally_1")):
		errors.append("Broken weapon should disable attacks.")
	if not str(gs.call("get_loadout", "ally_1").get("weapon", "")).is_empty():
		errors.append("Broken weapon should be unequipped.")

	var suffix: String = gs.call("get_weapon_status_suffix", "ally_3", "weapon")
	if not suffix.contains("/"):
		errors.append("Weapon status suffix should show ammo counts.")

	gs.get("owned_equipment")["iron_sword"] = 1
	var switch_result: Dictionary = gs.call("switch_weapon", "ally_1", "iron_sword")
	if not bool(switch_result.get("ok", false)):
		errors.append("Switch weapon should succeed with a spare weapon.")
	if str(gs.call("get_loadout", "ally_1").get("weapon", "")) != "iron_sword":
		errors.append("Switch weapon should equip the selected weapon.")

	var save_data: Dictionary = gs.call("build_save_data", Vector3.ZERO, 0.0)
	gs.call("reset_party_to_default")
	if not bool(gs.call("apply_save_dict", save_data)):
		errors.append("Save roundtrip should restore weapon durability and ammo state.")
	if int(gs.call("get_weapon_loaded_ammo", "ally_3", "short_bow")) != bow.magazine_size:
		errors.append("Save roundtrip should restore loaded ammo.")
	if str(gs.call("get_loadout", "ally_1").get("weapon", "")) != "iron_sword":
		errors.append("Save roundtrip should restore switched weapon.")

	gs.call("reset_party_to_default")
	return errors


func _test_mastery_and_spell_tiers() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs: Node = get_root().get_node("GameState")
	gs.call("reset_party_to_default")

	if int(gs.call("get_weapon_mastery_level", "ally_1", "sword")) != 1:
		errors.append("Weapon mastery should start at level 1.")
	if int(gs.call("get_spell_tier", "ally_4", "firebolt")) != 0:
		errors.append("Spells should start locked at tier 0.")
	if not (gs.call("get_unlocked_spells_for_character", "ally_4") as Array).is_empty():
		errors.append("Locked characters should have no unlocked spells.")

	var unlock_message: String = gs.call("unlock_spell_for_character", "ally_4", "firebolt")
	if unlock_message.is_empty():
		errors.append("Spell unlock should return a message.")
	if int(gs.call("get_spell_tier", "ally_4", "firebolt")) != 1:
		errors.append("Unlock should set spell tier to 1.")

	for _i: int in range(25):
		var weapon_xp: Dictionary = gs.call("award_weapon_mastery_xp", "ally_1", "sword")
		if not bool(weapon_xp.get("ok", false)):
			errors.append("Weapon mastery XP award should succeed.")
	if int(gs.call("get_weapon_mastery_level", "ally_1", "sword")) != 2:
		errors.append("25 weapon uses should reach mastery level 2.")

	seed(42)
	var combo_stats := StatBlock.new()
	combo_stats.dex = 80
	combo_stats.luk = 80
	var saw_combo := false
	for _attempt: int in range(64):
		if MasteryConstantsScript.resolve_combo_hit_count(3, combo_stats) >= 2:
			saw_combo = true
			break
	if not saw_combo:
		errors.append("High DEX/LUK should eventually proc combo hits at mastery 3.")

	for _i: int in range(25):
		gs.call("award_spell_mastery_xp", "ally_4", "firebolt")
	if int(gs.call("get_spell_tier", "ally_4", "firebolt")) != 2:
		errors.append("25 spell uses should reach tier 2.")
	for _i: int in range(50):
		gs.call("award_spell_mastery_xp", "ally_4", "firebolt")
	if int(gs.call("get_spell_tier", "ally_4", "firebolt")) != 3:
		errors.append("75 total spell uses should reach tier 3.")

	var effective: Dictionary = gs.call("get_effective_spell_stats", "ally_4", "firebolt")
	if int(effective.get("tier", 0)) != 3:
		errors.append("Effective spell stats should reflect current tier.")
	if int(effective.get("mp_cost", 0)) <= int(DataLoader.load_spells()["firebolt"].mp_cost):
		errors.append("Higher spell tiers should increase MP cost.")
	if int(effective.get("tier_base", 0)) <= int(DataLoader.load_spells()["firebolt"].tier_base):
		errors.append("Higher spell tiers should increase spell power.")

	gs.call("reset_party_to_default")
	gs.set("current_encounter_id", "test_4v3")
	gs.call("resolve_battle", GameState.BattleOutcomeCode.VICTORY)
	if int(gs.call("get_spell_tier", "ally_4", "firebolt")) != 1:
		errors.append("Encounter victory should unlock configured spells.")

	for _i: int in range(25):
		gs.call("award_weapon_mastery_xp", "ally_1", "sword")
	var save_data: Dictionary = gs.call("build_save_data", Vector3.ZERO, 0.0)
	gs.call("reset_party_to_default")
	if not bool(gs.call("apply_save_dict", save_data)):
		errors.append("Save roundtrip should restore mastery state.")
	if int(gs.call("get_weapon_mastery_level", "ally_1", "sword")) != 2:
		errors.append("Save roundtrip should restore weapon mastery level.")
	var fire_progress: Dictionary = gs.call(
		"get_spell_mastery_progress_for_type",
		"ally_4",
		"fire",
	)
	if int(fire_progress.get("tier", 0)) != 1:
		errors.append("Save roundtrip should restore unlocked spell mastery tier.")
	var bran_snapshot := gs.call("get_member_snapshot", "ally_1") as PartyMemberSnapshot
	if bran_snapshot == null or not (bran_snapshot.weapon_mastery as Dictionary).has("sword"):
		errors.append("Save roundtrip should restore weapon mastery map.")

	gs.call("reset_party_to_default")
	return errors


func _test_chapter_data() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs: Node = get_root().get_node("GameState")
	var chapter_ids: Array[String] = [
		"village_square",
		"old_chapel",
		"weavers_cottage",
		"granary",
		"root_cellar",
	]
	for area_id: String in chapter_ids:
		var area := DataLoader.load_area(area_id)
		if area.id != area_id:
			errors.append("Chapter area %s failed to load." % area_id)
		if area.scene_path.is_empty():
			errors.append("Chapter area %s should define scene_path." % area_id)
		if area.map_connections.is_empty() and area_id != "village_square":
			errors.append("Chapter area %s should connect to the hub." % area_id)

	var items := DataLoader.load_items()
	if not items.has("cellar_key"):
		errors.append("cellar_key item should exist for chapter gate.")

	var enemies := DataLoader.load_enemies()
	if not enemies.has("pale_warden"):
		errors.append("pale_warden mini-boss should exist.")

	var ambush := DataLoader.load_encounter("cottage_closet_ambush")
	if ambush.enemies.size() < 2:
		errors.append("Closet ambush encounter should include multiple enemies.")

	var warden := DataLoader.load_encounter("chapel_warden")
	var has_warden := false
	for enemy_entry: Dictionary in warden.enemies:
		if str(enemy_entry.get("enemy_id", "")) == "pale_warden":
			has_warden = true
			break
	if not has_warden:
		errors.append("Chapel encounter should include pale_warden.")

	gs.call("start_new_game", GameState.Difficulty.NORMAL)
	if str(gs.get("current_area_id")) != "village_square":
		errors.append("New game should start in village_square.")

	var square := DataLoader.load_area("village_square")
	if square.map_connections.size() < 4:
		errors.append("Village square hub should connect to four rooms.")

	gs.call("reset_party_to_default")
	return errors
