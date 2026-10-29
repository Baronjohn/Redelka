extends SceneTree


func _initialize() -> void:
	var errors: PackedStringArray = []
	errors.append_array(_test_data_files())
	errors.append_array(_test_speaker_meta())
	errors.append_array(_test_story_flags())
	errors.append_array(_test_save_state_roundtrip())
	errors.append_array(_test_new_game_routing())
	errors.append_array(_test_intro_flag_sync())
	errors.append_array(_test_intro_content_links())
	errors.append_array(_test_intro_scenes())
	errors.append_array(_test_party_starts_with_mira())
	errors.append_array(_test_objective_and_items())
	errors.append_array(await _test_play_cutscene_inlines_steps())
	errors.append_array(await _test_choice_flags_and_chaining())
	errors.append_array(await _test_examinable_gating())
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
		"title_redelka",
		"title_chapter",
		"mira_dawn",
		"mira_talk_tom",
		"mira_finds_empty_spot",
		"mira_holt",
		"mira_lane_enter",
		"mira_lane_shutter",
		"mira_lane_footprints",
		"mira_woods_hook",
		"mira_finds_bird",
	]:
		if not cutscenes.has(required_id):
			errors.append("Missing cutscene: %s" % required_id)
	for required_id: String in [
		"orphan_morning_chat",
		"neighbor_testimony",
		"neighbor_blame_response",
		"neighbor_direction_response",
		"neighbor_who_response",
		"neighbor_testimony_tail",
		"elsa_blame",
		"elsa_blame_tail",
		"lane_shutter",
	]:
		if not dialogs.has(required_id):
			errors.append("Missing dialog: %s" % required_id)
	for required_id: String in [
		"mira",
		"orphan_tom",
		"orphan_elsa",
		"neighbor_holt",
		"tall_man",
		"lane_voice",
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


## Every dialog, cutscene, speaker, item and flag the intro refers to must exist.
func _test_intro_content_links() -> PackedStringArray:
	var errors: PackedStringArray = []
	var cutscenes := DataLoader.load_json_object("res://data/cutscenes.json")
	var dialogs := DataLoader.load_json_object("res://data/dialogs.json")
	var actors := DataLoader.load_json_object("res://data/actors.json")
	var items := DataLoader.load_items()
	for dialog_id: String in dialogs.keys():
		var dialog := dialogs[dialog_id] as Dictionary
		var lines := dialog.get("lines", []) as Array
		for line: Dictionary in lines:
			var speaker := str(line.get("speaker", ""))
			if not actors.has(speaker):
				errors.append("Dialog %s uses unknown speaker %s." % [dialog_id, speaker])
		var next_id := str(dialog.get("next", ""))
		if not next_id.is_empty() and not dialogs.has(next_id):
			errors.append("Dialog %s chains to missing dialog %s." % [dialog_id, next_id])
		for group: Dictionary in dialog.get("choices", []) as Array:
			var after_line := int(group.get("after_line", -1))
			if after_line < 0 or after_line >= lines.size():
				errors.append("Dialog %s shows choices after line %d, which does not exist." % [dialog_id, after_line])
			for option: Dictionary in group.get("options", []) as Array:
				var option_next := str(option.get("next", ""))
				if not option_next.is_empty() and not dialogs.has(option_next):
					errors.append("Dialog %s option %s points to missing %s." % [dialog_id, option.get("id"), option_next])
				if str(option.get("flag", "")).is_empty():
					errors.append("Dialog %s option %s should record a story flag." % [dialog_id, option.get("id")])
	for cutscene_id: String in cutscenes.keys():
		var steps := (cutscenes[cutscene_id] as Dictionary).get("steps", []) as Array
		for step: Dictionary in steps:
			match str(step.get("type", "")):
				"play_dialog":
					if not dialogs.has(str(step.get("dialog_id", ""))):
						errors.append("Cutscene %s plays missing dialog %s." % [cutscene_id, step.get("dialog_id")])
				"play_cutscene":
					if not cutscenes.has(str(step.get("cutscene_id", ""))):
						errors.append("Cutscene %s inlines missing cutscene %s." % [cutscene_id, step.get("cutscene_id")])
				"give_item":
					if not items.has(str(step.get("item_id", ""))):
						errors.append("Cutscene %s gives unknown item %s." % [cutscene_id, step.get("item_id")])
				"actor_say":
					if not actors.has(str(step.get("speaker", ""))):
						errors.append("Cutscene %s uses unknown speaker %s." % [cutscene_id, step.get("speaker")])
				"flag_branch":
					var goto := int(step.get("goto", -1))
					if goto < 0 or goto >= steps.size():
						errors.append("Cutscene %s flag_branch jumps out of range (%d)." % [cutscene_id, goto])
	for actor_id: String in actors.keys():
		var model := str((actors[actor_id] as Dictionary).get("model", ""))
		if not model.is_empty() and not ResourceLoader.exists(model):
			errors.append("Actor %s model is missing: %s" % [actor_id, model])
	if not items.has("wooden_bird") or str(items["wooden_bird"].get("item_type")) != "key":
		errors.append("The wooden bird should be a key item.")
	elif str(items["wooden_bird"].get("description")).is_empty():
		errors.append("The wooden bird should carry its description text.")
	return errors


## The three intro areas load, and the ids their nodes reference resolve.
func _test_intro_scenes() -> PackedStringArray:
	var errors: PackedStringArray = []
	var cutscenes := DataLoader.load_json_object("res://data/cutscenes.json")
	var expected := {
		"mira_intake_alcove": ["mira_dawn", "mira_talk_tom", "mira_finds_empty_spot", "mira_holt"],
		"mira_chapel_lane": ["mira_lane_enter", "mira_lane_shutter", "mira_lane_footprints"],
		"mira_woods_edge": ["mira_woods_hook", "mira_finds_bird"],
	}
	for area_id: String in expected.keys():
		var area := DataLoader.load_area(area_id)
		if area.id != area_id:
			errors.append("Intro area %s should be registered in areas.json." % area_id)
			continue
		var packed := load(area.scene_path) as PackedScene
		if packed == null:
			errors.append("Intro scene for %s should load." % area_id)
			continue
		var state := packed.get_state()
		var found: Array[String] = []
		for node_index: int in state.get_node_count():
			for prop_index: int in state.get_node_property_count(node_index):
				var prop_name := state.get_node_property_name(node_index, prop_index)
				var value: Variant = state.get_node_property_value(node_index, prop_index)
				if prop_name == "cutscene_id":
					found.append(str(value))
					if not cutscenes.has(str(value)):
						errors.append("%s references missing cutscene %s." % [area_id, value])
				elif prop_name == "target_area_id" and not bool(_gs().call("has_area", str(value))):
					errors.append("%s has a door to unknown area %s." % [area_id, value])
		for cutscene_id: String in expected[area_id]:
			if not found.has(cutscene_id):
				errors.append("%s should wire cutscene %s." % [area_id, cutscene_id])
	return errors


func _test_party_starts_with_mira() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs := _gs()
	gs.call("start_new_game", 1)
	var ids: Array = gs.call("get_party_character_ids")
	if ids != ["ally_2"]:
		errors.append("A new game should start with Mira alone; got %s." % [ids])
	var spawns: Array = gs.call("get_formation_spawn_entries")
	if spawns.size() != 1:
		errors.append("Battle formation should only hold current members; got %d entries." % spawns.size())
	if (gs.get("owned_equipment") as Dictionary).has("iron_sword"):
		errors.append("Recruits' gear should not be in Mira's stock before they join.")
	if int((gs.get("inventory") as Dictionary).get("arrow", 0)) != 0:
		errors.append("Owen's arrows should arrive with Owen, not at the start.")
	if not bool(gs.call("add_party_member", "ally_3")):
		errors.append("add_party_member should recruit Owen.")
	if bool(gs.call("add_party_member", "ally_3")):
		errors.append("Recruiting someone already in the party should be refused.")
	if str((gs.call("get_loadout", "ally_3") as Dictionary).get("weapon", "")) != "short_bow":
		errors.append("A recruit should arrive with the loadout from setup.json.")
	if int((gs.get("inventory") as Dictionary).get("arrow", 0)) != 6:
		errors.append("A recruit should bring their join_inventory items.")
	if (gs.call("get_formation_spawn_entries") as Array).size() != 2:
		errors.append("A recruit should get a battle formation cell.")
	var save_data: Dictionary = gs.call("build_save_data", Vector3.ZERO, 0.0)
	gs.call("start_new_game", 1)
	gs.call("apply_save_dict", save_data)
	if gs.call("get_party_character_ids") != ["ally_2", "ally_3"]:
		errors.append("The recruited roster should survive a save roundtrip.")
	gs.call("reset_party_to_default")
	return errors


func _test_objective_and_items() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs := _gs()
	var nd := _nd()
	gs.call("start_new_game", 1)
	nd.call("_execute_step", {"type": "set_objective", "text": "Talk to Tom."})
	if str(gs.get("current_objective")) != "Talk to Tom.":
		errors.append("set_objective should update GameState.current_objective.")
	var save_data: Dictionary = gs.call("build_save_data", Vector3.ZERO, 0.0)
	gs.call("set_objective", "")
	gs.call("apply_save_dict", save_data)
	if str(gs.get("current_objective")) != "Talk to Tom.":
		errors.append("The objective should survive a save roundtrip.")
	nd.call("_execute_step", {"type": "give_item", "item_id": "wooden_bird", "silent": true})
	if not bool(gs.call("has_item", "wooden_bird")):
		errors.append("give_item should add the item to the inventory.")
	nd.call("_execute_step", {"type": "party_join", "character_id": "ally_1"})
	if not bool(gs.call("is_party_member", "ally_1")):
		errors.append("party_join should recruit the character.")
	gs.call("reset_party_to_default")
	if not str(gs.get("current_objective")).is_empty():
		errors.append("reset_party_to_default should clear the objective.")
	return errors


func _test_play_cutscene_inlines_steps() -> PackedStringArray:
	var errors: PackedStringArray = []
	var nd := _nd()
	nd.set("_cutscene_script", [{"type": "play_cutscene", "cutscene_id": "title_chapter"}, {"type": "wait"}])
	nd.set("_cutscene_index", 1)
	nd.call("_step_play_cutscene", {"cutscene_id": "title_chapter"})
	var script: Array = nd.get("_cutscene_script")
	var title_steps := ((DataLoader.load_json_object("res://data/cutscenes.json")["title_chapter"] as Dictionary)
		.get("steps", []) as Array)
	if script.size() != 2 + title_steps.size():
		errors.append("play_cutscene should splice the target's steps into the running script.")
	elif str((script[1] as Dictionary).get("type", "")) != str((title_steps[0] as Dictionary).get("type", "")):
		errors.append("Inlined steps should run right after the play_cutscene step.")
	nd.set("_cutscene_script", [])
	nd.set("_cutscene_index", 0)
	await _frames(1)
	return errors


## Walks Elsa's blame dialog: choice row after line 1, choice flag, follow-up, then the shared tail.
func _test_choice_flags_and_chaining() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs := _gs()
	var nd := _nd()
	gs.call("start_new_game", 1)
	var ended: Array[String] = []
	var on_ended := func(dialog_id: String, choice_id: String) -> void: ended.append("%s:%s" % [dialog_id, choice_id])
	nd.connect("dialog_ended", on_ended)
	nd.call("play_dialog", "elsa_blame", get_root())
	await _frames(2)
	var ui: Node = nd.get("_dialog_ui")
	var lines_seen: Array[String] = []
	for _step: int in range(2):
		lines_seen.append(str(ui.get("_line_label").text))
		ui.call("_advance")
		ui.call("_advance")
	if lines_seen.size() != 2 or not lines_seen[1].contains("supposed to watch her"):
		errors.append("Both of Elsa's lines should show before the choice; saw %s." % [lines_seen])
	if not bool(ui.get("_choice_box").visible):
		errors.append("The choice row should appear after the line given by after_line.")
	var options: Array = ui.get("_pending_choices")
	var lash: Dictionary = {}
	for option: Dictionary in options:
		if str(option.get("id", "")) == "lash":
			lash = option
	ui.call("_on_choice_made", lash)
	if not bool(nd.call("get_flag", "intro_elsa_choice_lash")):
		errors.append("Picking a choice should set its story flag.")
	var tail_seen := false
	for _step: int in range(8):
		if str(ui.get("_line_label").text).contains("Holt's lamp"):
			tail_seen = true
		if not bool(nd.call("is_dialog_active")):
			break
		ui.call("_advance")
		ui.call("_advance")
	await _frames(1)
	nd.disconnect("dialog_ended", on_ended)
	if not tail_seen:
		errors.append("The follow-up should chain into elsa_blame_tail via `next`.")
	if ended != ["elsa_blame:lash"]:
		errors.append("dialog_ended should fire once with the chosen option; got %s." % [ended])
	if bool(gs.get("busy_narrative")):
		errors.append("Finishing a chained dialog should release narrative control.")
	return errors


func _test_examinable_gating() -> PackedStringArray:
	var errors: PackedStringArray = []
	var gs := _gs()
	var nd := _nd()
	gs.call("start_new_game", 1)
	# Loaded at runtime: the script refers to autoloads, which don't exist when this test compiles.
	var examinable := (load("res://scripts/explore/explore_examinable.gd") as GDScript).new() as Area3D
	examinable.set("lines", PackedStringArray(["Ice on top. First this year."]))
	examinable.set("story_flag_required", "smoke_examine_ready")
	examinable.set("hide_when_flag", "smoke_examine_done")
	get_root().add_child(examinable)
	examinable.set("_player_inside", true)
	if bool(examinable.call("can_interact")):
		errors.append("An examinable should wait for its required flag.")
	nd.call("set_flag", "smoke_examine_ready", true)
	if not bool(examinable.call("can_interact")):
		errors.append("An examinable should open once its flag is set.")
	if not bool(examinable.call("interact")):
		errors.append("Interacting with an examinable should start its lines.")
	await _frames(2)
	if not bool(nd.call("is_dialog_active")) or not bool(gs.get("busy_narrative")):
		errors.append("Examining should show the lines and block explore input.")
	if bool(examinable.call("can_interact")):
		errors.append("An examinable should not re-trigger while its lines are showing.")
	(nd.get("_dialog_ui") as Node).call("_finish_dialog", "")
	await _frames(1)
	nd.call("set_flag", "smoke_examine_done", true)
	if bool(examinable.call("can_interact")):
		errors.append("hide_when_flag should switch the examinable off.")
	examinable.queue_free()
	gs.call("reset_party_to_default")
	return errors
