extends SceneTree


func _initialize() -> void:
	var errors: PackedStringArray = []
	errors.append_array(_test_data_files())
	errors.append_array(_test_speaker_meta())
	errors.append_array(_test_story_flags())
	errors.append_array(_test_save_state_roundtrip())
	errors.append_array(_test_new_game_routing())
	errors.append_array(_test_intro_flag_sync())
	errors.append_array(await _test_dialog_releases_control())
	errors.append_array(await _test_goto_area_releases_control())
	errors.append_array(await _test_goto_area_hands_off_to_autoplay())

	if errors.is_empty():
		print("Narrative smoke test passed.")
		quit(0)
	else:
		for message: String in errors:
			push_error(message)
		quit(1)


func _nd() -> Node:
	return get_root().get_node("NarrativeDirector")


func _gs() -> Node:
	return get_root().get_node("GameState")


func _st() -> Node:
	return get_root().get_node("SceneTransition")


func _frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


func _test_data_files() -> PackedStringArray:
	var errors: PackedStringArray = []
	var cutscenes := DataLoader.load_json_object("res://data/cutscenes.json")
	var dialogs := DataLoader.load_json_object("res://data/dialogs.json")
	var actors := DataLoader.load_json_object("res://data/actors.json")
	for required_id: String in [
		"mira_dawn",
		"mira_finds_empty_spot",
		"mira_to_woods",
		"mira_woods_hook",
	]:
		if not cutscenes.has(required_id):
			errors.append("Missing cutscene: %s" % required_id)
	for required_id: String in [
		"orphan_morning_chat",
		"neighbor_testimony",
		"neighbor_blame_response",
		"neighbor_direction_response",
	]:
		if not dialogs.has(required_id):
			errors.append("Missing dialog: %s" % required_id)
	for required_id: String in [
		"mira",
		"orphan_tom",
		"orphan_elsa",
		"neighbor_holt",
		"internal",
	]:
		if not actors.has(required_id):
			errors.append("Missing actor entry: %s" % required_id)
	return errors


func _test_speaker_meta() -> PackedStringArray:
	var errors: PackedStringArray = []
	var nd := _nd()
	var mira_meta: Dictionary = nd.call("get_speaker_meta", "mira")
	if str(mira_meta.get("name", "")) != "Mira":
		errors.append("Speaker meta for 'mira' should resolve to display name 'Mira'.")
	if str(mira_meta.get("portrait", "")).is_empty():
		errors.append("Speaker meta for 'mira' should resolve to a portrait path.")
	var fallback: Dictionary = nd.call("get_speaker_meta", "unknown_speaker")
	if str(fallback.get("name", "")) != "Unknown Speaker":
		errors.append("Speaker meta fallback should capitalize the actor id.")
	return errors


func _test_story_flags() -> PackedStringArray:
	var errors: PackedStringArray = []
	var nd := _nd()
	nd.set_flag("test_flag", true)
	if not nd.get_flag("test_flag"):
		errors.append("Setting a story flag should persist for the session.")
	nd.set_flag("test_flag", false)
	if nd.get_flag("test_flag"):
		errors.append("Clearing a story flag should flip its value.")
	return errors


func _test_save_state_roundtrip() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs := _gs()
	gs.call("start_new_game", 1)
	if str(gs.get("protagonist_character_id")) != "ally_2":
		errors.append("New game should default protagonist to Mira (ally_2).")
	gs.set("story_flags", {"intro_dawn_seen": true, "intro_empty_spot_seen": true})
	gs.set("chapter1_intro_seen", true)
	var save_data: Dictionary = gs.call("build_save_data", Vector3(1.0, 0.0, 2.0), 0.5)
	var state: Dictionary = save_data.get("state", {}) as Dictionary
	if not bool(state.get("chapter1_intro_seen", false)):
		errors.append("chapter1_intro_seen should serialize in save state.")
	if not (state.get("story_flags", {}) as Dictionary).get("intro_dawn_seen", false):
		errors.append("story_flags should serialize in save state.")
	if str(state.get("protagonist_character_id", "")) != "ally_2":
		errors.append("protagonist_character_id should serialize in save state.")
	gs.call("apply_save_dict", save_data)
	if not bool(gs.get("chapter1_intro_seen")):
		errors.append("apply_save_dict should restore chapter1_intro_seen.")
	if not bool((gs.get("story_flags") as Dictionary).get("intro_dawn_seen", false)):
		errors.append("apply_save_dict should restore story_flags.")
	gs.call("reset_party_to_default")
	if bool(gs.get("chapter1_intro_seen")):
		errors.append("reset_party_to_default should clear chapter1_intro_seen.")
	if str(gs.get("protagonist_character_id")) != "ally_2":
		errors.append("reset_party_to_default should keep Mira as protagonist.")
	return errors


func _test_new_game_routing() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs := _gs()
	gs.call("start_new_game", 1)
	if bool(gs.get("chapter1_intro_seen")):
		errors.append("New game should leave chapter1_intro_seen unset.")
	if str(gs.get("current_area_id")) != "mira_intake_alcove":
		errors.append("New game should set current_area_id to the intro area.")
	if not gs.call("has_area", "village_square"):
		errors.append("village_square must remain a registered area.")
	gs.set("chapter1_intro_seen", true)
	gs.set("current_area_id", "village_square")
	if str(gs.call("get_effective_current_area_id")) != "village_square":
		errors.append("Once intro seen, get_effective_current_area_id should return the saved area.")
	if str(gs.call("get_effective_current_area_id")) == "mira_intake_alcove":
		errors.append("get_effective_current_area_id must not override the saved area after intro seen.")
	gs.set("chapter1_intro_seen", false)
	if str(gs.call("get_effective_current_area_id")) != "mira_intake_alcove":
		errors.append("Before intro seen, get_effective_current_area_id should return the intro area.")
	gs.call("reset_party_to_default")
	return errors


func _test_intro_flag_sync() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs := _gs()
	var nd := _nd()
	gs.call("start_new_game", 1)
	gs.set("return_area_id", "village_square")
	if str(_st().call("get_explore_target_area_id")) != "mira_intake_alcove":
		errors.append("Before the intro, explore should route to the intro area.")
	nd.call("set_flag", "chapter1_intro_seen", true)
	if not bool(gs.get("chapter1_intro_seen")):
		errors.append("Cutscene flag chapter1_intro_seen should set GameState.chapter1_intro_seen.")
	if str(_st().call("get_explore_target_area_id")) != "village_square":
		errors.append("After the intro, explore should route to return_area_id, not the intro area.")
	var save_data: Dictionary = gs.call("build_save_data", Vector3.ZERO, 0.0)
	var state: Dictionary = save_data["state"] as Dictionary
	state["chapter1_intro_seen"] = false
	gs.call("apply_save_dict", save_data)
	if not bool(gs.get("chapter1_intro_seen")):
		errors.append("Loading a save whose story flag says intro seen should restore it.")
	gs.call("reset_party_to_default")
	return errors


func _test_dialog_releases_control() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs := _gs()
	var nd := _nd()
	gs.call("start_new_game", 1)
	var ended: Array[String] = []
	var on_ended := func(dialog_id: String, _choice_id: String) -> void: ended.append(dialog_id)
	nd.connect("dialog_ended", on_ended)
	nd.call("play_dialog", "orphan_morning_chat", get_root())
	await _frames(2)
	var dialog_ui: Node = nd.get("_dialog_ui")
	if dialog_ui == null or not dialog_ui.is_inside_tree():
		errors.append("play_dialog should instantiate the dialog UI and add it to the tree.")
		nd.disconnect("dialog_ended", on_ended)
		return errors
	if not bool(nd.call("is_dialog_active")):
		errors.append("Dialog should report active while it is showing.")
	if not bool(gs.get("busy_narrative")):
		errors.append("A standalone dialog should block explore input while open.")
	dialog_ui.call("_finish_dialog", "")
	await _frames(1)
	nd.disconnect("dialog_ended", on_ended)
	if ended != ["orphan_morning_chat"]:
		errors.append("dialog_ended should fire once for the finished dialog.")
	if bool(nd.call("is_active")) or bool(gs.get("busy_narrative")):
		errors.append("Finishing a standalone dialog should release narrative control.")
	if bool(nd.call("is_dialog_active")):
		errors.append("Dialog should report inactive once finished.")
	return errors


func _test_goto_area_releases_control() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs := _gs()
	var nd := _nd()
	gs.call("start_new_game", 1)
	gs.set("chapter1_intro_seen", true)
	# Mirror mira_woods_hook's ending: screen faded to black, then goto_area into a room without autoplay.
	nd.set("_active_cutscene_id", "smoke_goto")
	nd.set("_active", true)
	gs.set("busy_narrative", true)
	nd.call("_ensure_theater")
	(nd.get("_theater") as ColorRect).color.a = 1.0
	await nd.call("_step_goto_area", {"area_id": "test_room", "spawn": [0, 0, 0]})
	if bool(gs.get("busy_narrative")) or bool(nd.call("is_active")):
		errors.append("goto_area into an area without a cutscene should release narrative control.")
	var theater: Variant = nd.get("_theater")
	if theater != null and is_instance_valid(theater):
		errors.append("goto_area should clear the black theater overlay when no cutscene takes over.")
	if str(gs.get("current_area_id")) != "test_room":
		errors.append("goto_area should travel to the target area.")
	return errors


func _test_goto_area_hands_off_to_autoplay() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs := _gs()
	var nd := _nd()
	nd.set("_active_cutscene_id", "smoke_goto")
	nd.set("_active", true)
	gs.set("busy_narrative", true)
	await nd.call("_step_goto_area", {"area_id": "mira_woods_edge", "spawn": [0, 0, 6]})
	if str(nd.get("_active_cutscene_id")) != "mira_woods_hook":
		errors.append("mira_woods_edge should autoplay mira_woods_hook after goto_area.")
	if not bool(gs.get("busy_narrative")):
		errors.append("goto_area must not release control while the next area's cutscene runs.")
	nd.call("end_current_cutscene", false)
	if bool(gs.get("busy_narrative")):
		errors.append("Ending the handed-off cutscene should release control.")
	return errors
