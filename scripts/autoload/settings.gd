extends Node

const SETTINGS_PATH: String = "user://settings.cfg"

const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "borderless"]
const REBINDABLE_ACTIONS: Array[String] = [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"interact",
	"open_menu",
	"menu_cancel",
	"ui_accept",
	"ui_cancel",
]

var window_mode: String = "windowed"
var vsync_enabled: bool = true
var resolution_scale: float = 1.0
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var input_overrides: Dictionary = {}

var _config: ConfigFile = ConfigFile.new()
var _rebinding_action: String = ""


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	if _config.load(SETTINGS_PATH) != OK:
		master_volume = AudioSettings.master_volume_default
		music_volume = AudioSettings.music_volume_default
		sfx_volume = AudioSettings.sfx_volume_default
		return
	window_mode = str(_config.get_value("graphics", "window_mode", window_mode))
	vsync_enabled = bool(_config.get_value("graphics", "vsync_enabled", vsync_enabled))
	resolution_scale = float(_config.get_value("graphics", "resolution_scale", resolution_scale))
	master_volume = float(_config.get_value("audio", "master_volume", AudioSettings.master_volume_default))
	music_volume = float(_config.get_value("audio", "music_volume", AudioSettings.music_volume_default))
	sfx_volume = float(_config.get_value("audio", "sfx_volume", AudioSettings.sfx_volume_default))
	input_overrides = _config.get_value("input", "overrides", {}) as Dictionary


func save_settings() -> void:
	_config.set_value("graphics", "window_mode", window_mode)
	_config.set_value("graphics", "vsync_enabled", vsync_enabled)
	_config.set_value("graphics", "resolution_scale", resolution_scale)
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("audio", "music_volume", music_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.set_value("input", "overrides", input_overrides)
	_config.save(SETTINGS_PATH)


func apply_all() -> void:
	apply_graphics()
	apply_audio()
	apply_input_overrides()


func apply_graphics() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	match window_mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var base_size := Vector2i(1920, 1080)
	get_window().content_scale_factor = resolution_scale


func apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func apply_input_overrides() -> void:
	for action_name: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action_name):
			continue
		var events: Array = input_overrides.get(action_name, []) as Array
		if events.is_empty():
			continue
		InputMap.action_erase_events(action_name)
		for event_data: Variant in events:
			var event := _deserialize_input_event(event_data as Dictionary)
			if event != null:
				InputMap.action_add_event(action_name, event)


func get_action_display_name(action_name: String) -> String:
	return action_name.replace("_", " ").capitalize()


func get_action_events(action_name: String) -> Array:
	if input_overrides.has(action_name):
		var stored: Array = input_overrides[action_name] as Array
		var events: Array = []
		for event_data: Variant in stored:
			var event := _deserialize_input_event(event_data as Dictionary)
			if event != null:
				events.append(event)
		if not events.is_empty():
			return events
	return InputMap.action_get_events(action_name)


func format_input_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return OS.get_keycode_string(key_event.physical_keycode)
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		return "Pad %d Btn %d" % [button_event.device, button_event.button_index]
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		return "Pad %d Axis %d" % [motion_event.device, motion_event.axis]
	return event.as_text()


func begin_rebind(action_name: String) -> void:
	_rebinding_action = action_name


func cancel_rebind() -> void:
	_rebinding_action = ""


func is_rebinding() -> bool:
	return not _rebinding_action.is_empty()


func process_rebind_event(event: InputEvent) -> String:
	if _rebinding_action.is_empty():
		return ""
	if event is InputEventKey and event.is_echo():
		return ""
	if event is InputEventMouse or event is InputEventMouseButton or event is InputEventMouseMotion:
		return ""
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return ""
	if event.is_released():
		return ""
	var duplicate_action := _find_action_with_event(event)
	if not duplicate_action.is_empty() and duplicate_action != _rebinding_action:
		return "Already bound to %s." % get_action_display_name(duplicate_action)
	var serialized := _serialize_input_event(event)
	input_overrides[_rebinding_action] = [serialized]
	apply_input_overrides()
	save_settings()
	var action := _rebinding_action
	_rebinding_action = ""
	return "Bound %s to %s." % [get_action_display_name(action), format_input_event(event)]


func clear_binding(action_name: String) -> void:
	input_overrides.erase(action_name)
	apply_input_overrides()
	save_settings()


func cycle_window_mode() -> void:
	var index := WINDOW_MODES.find(window_mode)
	index = (index + 1) % WINDOW_MODES.size()
	window_mode = WINDOW_MODES[index]
	apply_graphics()
	save_settings()


func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	apply_graphics()
	save_settings()


func set_resolution_scale(scale: float) -> void:
	resolution_scale = clampf(scale, 0.5, 1.5)
	apply_graphics()
	save_settings()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()


func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var db := linear_to_db(clampf(linear_value, 0.0001, 1.0))
	AudioServer.set_bus_volume_db(index, db)


func _find_action_with_event(event: InputEvent) -> String:
	for action_name: String in REBINDABLE_ACTIONS:
		for existing: InputEvent in get_action_events(action_name):
			if existing.is_match(event):
				return action_name
	return ""


func _serialize_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {
			"type": "key",
			"physical_keycode": key_event.physical_keycode,
		}
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		return {
			"type": "joy_button",
			"device": button_event.device,
			"button_index": button_event.button_index,
		}
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		return {
			"type": "joy_motion",
			"device": motion_event.device,
			"axis": motion_event.axis,
			"axis_value": motion_event.axis_value,
		}
	return {}


func _deserialize_input_event(data: Dictionary) -> InputEvent:
	match str(data.get("type", "")):
		"key":
			var event := InputEventKey.new()
			event.physical_keycode = int(data.get("physical_keycode", 0))
			return event
		"joy_button":
			var event := InputEventJoypadButton.new()
			event.device = int(data.get("device", 0))
			event.button_index = int(data.get("button_index", 0))
			return event
		"joy_motion":
			var event := InputEventJoypadMotion.new()
			event.device = int(data.get("device", 0))
			event.axis = int(data.get("axis", 0))
			event.axis_value = float(data.get("axis_value", 0.0))
			return event
	return null
