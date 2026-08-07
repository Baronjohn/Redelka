extends SceneTree

## Headless smoke test for Phase 1 combat data and formulas.


func _initialize() -> void:
	var errors: PackedStringArray = []
	errors.append_array(_test_data_loading())
	errors.append_array(_test_combat_formulas())
	errors.append_array(_test_turn_queue())
	errors.append_array(_test_battle_grid())
	errors.append_array(_test_explore_handoff())

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
	if DataLoader.load_enemies().size() != 3:
		errors.append("Expected 3 enemies.")
	if DataLoader.load_spells().size() < 3:
		errors.append("Expected at least 3 spells.")
	var encounter := DataLoader.load_encounter("test_4v3")
	if encounter.allies.size() != 4 or encounter.enemies.size() != 3:
		errors.append("Encounter test_4v3 has wrong unit counts.")
	return errors


func _test_combat_formulas() -> PackedStringArray:
	var errors: PackedStringArray = []
	var characters := DataLoader.load_characters()
	var weapons := DataLoader.load_weapons()
	var skills := DataLoader.load_skills()
	var bran: CharacterData = characters["ally_1"]
	var unit := CombatUnit.from_character(
		"ally_1",
		bran,
		weapons[bran.weapon_id],
		skills[bran.skill_id],
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

	var attack := CombatResolver.resolve_physical_attack(unit, enemy)
	if not attack.has("hit") or not attack.has("damage"):
		errors.append("Physical attack result missing keys.")

	var firebolt: SpellData = DataLoader.load_spells()["firebolt"]
	var spell := CombatResolver.resolve_spell(unit, enemy, firebolt)
	if not spell.has("amount"):
		errors.append("Spell result missing amount.")

	if not CombatResolver.resolve_retreat(unit) in [true, false]:
		errors.append("Retreat must return bool.")
	return errors


func _test_turn_queue() -> PackedStringArray:
	var errors: PackedStringArray = []
	var units: Array[CombatUnit] = []
	var characters := DataLoader.load_characters()
	var weapons := DataLoader.load_weapons()
	var skills := DataLoader.load_skills()
	for character: CharacterData in characters.values():
		units.append(
			CombatUnit.from_character(
				character.id,
				character,
				weapons[character.weapon_id],
				skills[character.skill_id],
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
	if room_encounter.enemies.size() != 1:
		errors.append("Encounter test_room_wretch should have one enemy.")

	gs.call("reset_party_to_default")
	if int(gs.get("party_members").size()) != 4:
		errors.append("Party init should create four members.")

	gs.call("enter_battle", "test_room", Vector3(1, 0, 2), 0.5, "test_room_wretch", "room_wretch")
	if int(gs.get("battle_source")) != 1:
		errors.append("Battle source should be EXPLORE after enter_battle.")
	if str(gs.get("current_encounter_id")) != "test_room_wretch":
		errors.append("Encounter id not stored for explore battle.")

	gs.call("save_checkpoint", "test_room", Vector3(2, 0, -8), 0.0)
	if not bool(gs.get("has_checkpoint")):
		errors.append("Checkpoint should exist after save.")

	var bran_snapshot = gs.call("get_member_snapshot", "ally_1")
	if bran_snapshot == null:
		errors.append("Expected ally_1 in party snapshot.")
		return errors

	var saved_hp: int = bran_snapshot.current_hp
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
	var restored = gs.call("get_member_snapshot", "ally_1")
	if restored == null or restored.current_hp != saved_hp:
		errors.append("Defeat with checkpoint should restore saved party HP.")

	gs.call("reset_party_to_default")
	return errors
