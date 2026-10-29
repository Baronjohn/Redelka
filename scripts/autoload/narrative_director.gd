extends Node

const DialogUIScene: PackedScene = preload("res://scenes/narrative/dialog_ui.tscn")

signal cutscene_started(cutscene_id: String)
signal cutscene_ended(cutscene_id: String, completed: bool)
signal dialog_started(dialog_id: String)
signal dialog_ended(dialog_id: String, choice_id: String)
signal actor_said(speaker_id: String, text: String)
signal flag_changed(key: String, value: bool)

var _active: bool = false
var _active_cutscene_id: String = ""
var _cutscene_script: Array = []
var _cutscene_index: int = 0
var _cutscene_context: Node = null
var _cutscene_run_id: int = 0
var _theater: Control = null
var _dialog_ui: NarrativeDialogUI = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_active() -> bool:
	return _active


func is_cutscene_running() -> bool:
	return _active_cutscene_id != ""


func is_dialog_active() -> bool:
	return _dialog_ui != null and is_instance_valid(_dialog_ui) and _dialog_ui.is_active()


func get_speaker_meta(speaker_id: String) -> Dictionary:
	if speaker_id.is_empty():
		return {
			"name": "",
			"portrait": "",
			"color": Color(0.9, 0.85, 0.8, 1.0),
		}
	var speakers := DataLoader.load_json_object("res://data/actors.json")
	if speakers.has(speaker_id):
		var entry := speakers[speaker_id] as Dictionary
		return {
			"name": str(entry.get("name", speaker_id.capitalize())),
			"portrait": str(entry.get("portrait", "")),
			"color": _parse_color(entry.get("color", Color(0.9, 0.85, 0.8, 1.0))),
		}
	return {
		"name": speaker_id.capitalize(),
		"portrait": "",
		"color": Color(0.9, 0.85, 0.8, 1.0),
	}


func get_flag(key: String) -> bool:
	if GameState == null:
		return false
	return bool(GameState.story_flags.get(key, false))


func set_flag(key: String, value: bool) -> void:
	if GameState == null:
		return
	GameState.story_flags[key] = value
	flag_changed.emit(key, value)


func play_cutscene(cutscene_id: String, context: Node) -> void:
	if _active:
		push_warning("NarrativeDirector: cutscene already active, ignoring %s" % cutscene_id)
		return
	var all_cutscenes := DataLoader.load_json_object("res://data/cutscenes.json")
	if not all_cutscenes.has(cutscene_id):
		push_error("NarrativeDirector: cutscene not found: %s" % cutscene_id)
		return
	var entry := all_cutscenes[cutscene_id] as Dictionary
	var steps := entry.get("steps", []) as Array
	if steps.is_empty():
		push_warning("NarrativeDirector: cutscene %s has no steps" % cutscene_id)
		return
	_active_cutscene_id = cutscene_id
	_cutscene_script = steps
	_cutscene_index = 0
	_cutscene_context = context
	_cutscene_run_id += 1
	_active = true
	GameState.busy_narrative = true
	cutscene_started.emit(cutscene_id)
	_ensure_theater()
	_theater.show()
	_run_cutscene()


func end_current_cutscene(completed: bool = false) -> void:
	if _active_cutscene_id.is_empty():
		return
	var ended_id := _active_cutscene_id
	_active_cutscene_id = ""
	_cutscene_script = []
	_cutscene_index = 0
	_release_control()
	cutscene_ended.emit(ended_id, completed)
	if _theater != null:
		_theater.hide()
		_remove_theater()


func play_dialog(dialog_id: String, context: Node) -> void:
	if not _active:
		_active = true
		GameState.busy_narrative = true
	var all_dialogs := DataLoader.load_json_object("res://data/dialogs.json")
	if not all_dialogs.has(dialog_id):
		push_error("NarrativeDirector: dialog not found: %s" % dialog_id)
		if not is_cutscene_running():
			_release_control()
		if context != null and context.has_method("_on_dialog_complete"):
			context.call("_on_dialog_complete", "")
		return
	var raw := all_dialogs[dialog_id] as Dictionary
	var dialog := _resolve_dialog(raw)
	dialog_started.emit(dialog_id)
	_ensure_dialog_ui()
	# The UI is added to the tree deferred; its @onready nodes exist only after ready.
	if not _dialog_ui.is_node_ready():
		await _dialog_ui.ready
	_dialog_ui.start(dialog, _on_dialog_ui_complete.bind(dialog_id, context))


func _on_dialog_ui_complete(choice_id: String, dialog_id: String, _context: Node) -> void:
	# A dialog played from inside a cutscene leaves control with the cutscene.
	if not is_cutscene_running():
		_release_control()
	dialog_ended.emit(dialog_id, choice_id)


func _release_control() -> void:
	_active = false
	GameState.busy_narrative = false


func _on_dialog_default_finished(_choice_id: String) -> void:
	pass


func _resolve_dialog(raw: Dictionary) -> Dictionary:
	var resolved := {
		"lines": (raw.get("lines", []) as Array).duplicate(),
	}
	var groups := raw.get("choices", []) as Array
	if not groups.is_empty():
		var pending_options: Array = []
		var pending_after: int = -1
		for group: Dictionary in groups:
			if pending_after == -1:
				pending_after = int(group.get("after_line", -1))
			for option: Dictionary in (group.get("options", []) as Array):
				pending_options.append(option)
		resolved["pending_choices"] = pending_options
		resolved["pending_choice_after"] = pending_after
	return resolved


func _ensure_theater() -> void:
	if _theater != null and is_instance_valid(_theater):
		return
	_theater = ColorRect.new()
	_theater.name = "NarrativeTheater"
	_theater.color = Color(0, 0, 0, 0)
	_theater.set_anchors_preset(Control.PRESET_FULL_RECT)
	_theater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_theater.process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_add_theater_deferred")


func _add_theater_deferred() -> void:
	if _theater == null:
		return
	get_tree().root.add_child(_theater)


func _remove_theater() -> void:
	if _theater != null and is_instance_valid(_theater):
		_theater.queue_free()
	_theater = null


func _ensure_dialog_ui() -> void:
	if _dialog_ui != null and is_instance_valid(_dialog_ui):
		return
	_dialog_ui = DialogUIScene.instantiate() as NarrativeDialogUI
	call_deferred("_add_dialog_ui_deferred")


func _add_dialog_ui_deferred() -> void:
	if _dialog_ui == null:
		return
	get_tree().root.add_child(_dialog_ui)


func _run_cutscene() -> void:
	if _active_cutscene_id.is_empty():
		return
	var run_id := _cutscene_run_id
	while _cutscene_index < _cutscene_script.size():
		var step: Dictionary = _cutscene_script[_cutscene_index] as Dictionary
		_cutscene_index += 1
		await _execute_step(step)
		# Stop if this cutscene ended or a new one (e.g. a goto_area autoplay) took over.
		if _active_cutscene_id.is_empty() or run_id != _cutscene_run_id:
			return
	end_current_cutscene(true)


func _execute_step(step: Dictionary) -> void:
	var step_type := str(step.get("type", ""))
	match step_type:
		"wait":
			var seconds := float(step.get("seconds", 0.0))
			if seconds > 0.0:
				await get_tree().create_timer(seconds).timeout
		"flag_set":
			set_flag(str(step.get("key", "")), bool(step.get("value", true)))
		"flag_branch":
			var key := str(step.get("key", ""))
			var value := bool(step.get("value", true))
			if get_flag(key) != value:
				var jump_index := int(step.get("goto", -1))
				if jump_index >= 0 and jump_index < _cutscene_script.size():
					_cutscene_index = jump_index
		"camera_cut":
			await _step_camera_cut(step)
		"camera_blend":
			await _step_camera_blend(step)
		"actor_move":
			await _step_actor_move(step)
		"actor_face":
			await _step_actor_face(step)
		"actor_show":
			_step_set_actor_visibility(step, true)
		"actor_hide":
			_step_set_actor_visibility(step, false)
		"actor_reset":
			_step_actor_reset(step)
		"actor_say":
			await _step_actor_say(step)
		"play_dialog":
			await _step_play_dialog(step)
		"fade":
			await _step_fade(step)
		"hand_control_back":
			await _step_hand_control_back()
		"goto_area":
			await _step_goto_area(step)
		"sfx":
			_step_sfx(step)
		"music":
			_step_music(step)
		_:
			push_warning("NarrativeDirector: unknown step type %s" % step_type)
			await get_tree().process_frame


func _find_actor(actor_id: String) -> Node3D:
	if _cutscene_context == null:
		return null
	var root: Node = _cutscene_context
	if root is Node3D == false and root.has_method("get"):
		var fallback := root.get_tree().current_scene
		if fallback != null:
			root = fallback
	for child: Node in root.get_tree().get_nodes_in_group("narrative_actors"):
		if str(child.get("actor_id")) == actor_id:
			return child as Node3D
	return null


func _find_camera() -> Camera3D:
	var rig := _find_camera_rig()
	if rig != null:
		return rig.get_camera() as Camera3D
	var scene := get_tree().current_scene
	if scene != null:
		var cam := scene.get_viewport().get_camera_3d()
		if cam != null:
			return cam
	return null


func _find_camera_rig() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var rig := scene.get_node_or_null("CameraRig")
	return rig


func _step_camera_cut(step: Dictionary) -> void:
	var camera := _find_camera()
	if camera == null:
		return
	if step.has("position"):
		var pos_array: Array = step.get("position", [0, 0, 0]) as Array
		camera.global_position = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
	if step.has("look_at"):
		var look_array: Array = step.get("look_at", [0, 0, 0]) as Array
		var look_pos := Vector3(float(look_array[0]), float(look_array[1]), float(look_array[2]))
		camera.look_at(look_pos, Vector3.UP)
	elif step.has("basis"):
		var basis_array: Array = step.get("basis", []) as Array
		if basis_array.size() == 9:
			camera.global_basis = Basis(
				Vector3(float(basis_array[0]), float(basis_array[1]), float(basis_array[2])),
				Vector3(float(basis_array[3]), float(basis_array[4]), float(basis_array[5])),
				Vector3(float(basis_array[6]), float(basis_array[7]), float(basis_array[8])),
			)
	var rig := _find_camera_rig()
	if rig != null:
		rig.set("_track_target", null)
	await get_tree().process_frame


func _step_camera_blend(step: Dictionary) -> void:
	var camera := _find_camera()
	if camera == null:
		return
	var rig := _find_camera_rig()
	if rig != null:
		rig.set("_track_target", null)
	var duration := float(step.get("duration", 1.0))
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	if step.has("position"):
		var pos_array: Array = step.get("position", [0, 0, 0]) as Array
		var target_pos := Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
		tween.tween_property(camera, "global_position", target_pos, duration)
	if step.has("look_at"):
		var look_array: Array = step.get("look_at", [0, 0, 0]) as Array
		var look_pos := Vector3(float(look_array[0]), float(look_array[1]), float(look_array[2]))
		var saved_transform := camera.global_transform
		camera.look_at(look_pos, Vector3.UP)
		var target_basis := camera.global_basis
		camera.global_transform = saved_transform
		tween.parallel().tween_property(camera, "global_basis", target_basis, duration)
	await tween.finished


func _step_actor_move(step: Dictionary) -> void:
	var actor := _find_actor(str(step.get("id", "")))
	if actor == null:
		return
	var pos_array: Array = step.get("to", [0, 0, 0]) as Array
	var target := Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
	var duration := float(step.get("duration", 1.0))
	if actor.has_method("move_to"):
		await actor.move_to(target, duration)
	else:
		actor.global_position = target


func _step_actor_face(step: Dictionary) -> void:
	var actor := _find_actor(str(step.get("id", "")))
	if actor == null:
		return
	var duration := float(step.get("duration", 0.0))
	var target_actor_id := str(step.get("target_id", ""))
	if not target_actor_id.is_empty():
		var other := _find_actor(target_actor_id)
		if other != null and actor.has_method("face_actor"):
			await actor.face_actor(other, duration)
			return
	if step.has("target"):
		var pos_array: Array = step.get("target", [0, 0, 0]) as Array
		var target_pos := Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
		if actor.has_method("face_to"):
			await actor.face_to(target_pos, duration)
		else:
			var offset := target_pos - actor.global_position
			offset.y = 0.0
			if offset.length_squared() > 0.0001:
				actor.rotation.y = atan2(offset.x, offset.z)


func _step_set_actor_visibility(step: Dictionary, visible: bool) -> void:
	var actor := _find_actor(str(step.get("id", "")))
	if actor == null:
		return
	if visible and actor.has_method("show_actor"):
		actor.show_actor()
	elif visible:
		actor.visible = true
	elif actor.has_method("hide_actor"):
		actor.hide_actor()
	else:
		actor.visible = false


func _step_actor_reset(step: Dictionary) -> void:
	var actor := _find_actor(str(step.get("id", "")))
	if actor == null:
		return
	if actor.has_method("reset_to_initial"):
		actor.reset_to_initial()


func _step_actor_say(step: Dictionary) -> void:
	var speaker_id := str(step.get("speaker", ""))
	var text := str(step.get("text", ""))
	var duration := float(step.get("duration", 0.0))
	actor_said.emit(speaker_id, text)
	if duration <= 0.0:
		var char_count := text.length()
		duration = clampf(0.04 * float(char_count), 1.2, 4.0)
	await get_tree().create_timer(duration).timeout


func _step_play_dialog(step: Dictionary) -> void:
	var dialog_id := str(step.get("dialog_id", ""))
	if dialog_id.is_empty():
		return
	var ctx := _cutscene_context
	if ctx == null:
		ctx = get_tree().current_scene
	await play_dialog(dialog_id, ctx)
	while _active:
		await get_tree().process_frame
		if _dialog_ui == null or not is_instance_valid(_dialog_ui) or not _dialog_ui.is_active():
			break


func _step_fade(step: Dictionary) -> void:
	var target := str(step.get("to", "black"))
	var duration := float(step.get("duration", 0.6))
	_ensure_theater()
	if _theater == null:
		return
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	if target == "black":
		tween.tween_property(_theater, "color:a", 1.0, duration)
	else:
		tween.tween_property(_theater, "color:a", 0.0, duration)
	await tween.finished


func _step_hand_control_back() -> void:
	end_current_cutscene(true)


func _step_goto_area(step: Dictionary) -> void:
	var area_id := str(step.get("area_id", ""))
	if area_id.is_empty():
		return
	var pos_array: Array = step.get("spawn", [0, 0, 0]) as Array
	var spawn := Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
	var rotation_y := float(step.get("rotation_y", 0.0))
	var ending_id := _active_cutscene_id
	_active_cutscene_id = ""
	_active = false
	cutscene_ended.emit(ending_id, true)
	GameState.travel_to_area(area_id, spawn, rotation_y)
	await SceneTransition.go_to_explore()
	# The new area may autoplay its own cutscene, which then owns the theater and control.
	if _active:
		return
	if _theater != null and is_instance_valid(_theater):
		await _step_fade({"to": "clear"})
		if _active:
			return
		_remove_theater()
	GameState.busy_narrative = false


func _step_sfx(step: Dictionary) -> void:
	var sfx_id := str(step.get("id", ""))
	if sfx_id.is_empty() or SfxManager == null:
		return
	SfxManager.play(
		sfx_id,
		float(step.get("pitch", 1.0)),
		float(step.get("volume_db", 0.0)),
	)


func _step_music(step: Dictionary) -> void:
	var track_id := str(step.get("track", ""))
	if track_id.is_empty() or MusicManager == null:
		return
	MusicManager.play_track(track_id, bool(step.get("force", false)))


func _find_explore_controller() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	if scene.has_method("get"):
		var ctrl := scene.get_node_or_null(".")
		if ctrl != null and ctrl.has_method("restore_player_tracking"):
			return ctrl
	return null





func _parse_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Array and (value as Array).size() >= 3:
		var arr := value as Array
		var a := 1.0
		if arr.size() >= 4:
			a = float(arr[3])
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	if value is String:
		return Color(value)
	return Color(0.9, 0.85, 0.8, 1.0)
