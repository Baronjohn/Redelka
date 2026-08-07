extends Control

var menu: Control

var _sub_tabs: TabContainer
var _graphics_box: VBoxContainer
var _audio_box: VBoxContainer
var _input_list: ItemList
var _rebind_button: Button
var _clear_button: Button
var _misc_label: Label
var _debug_label: Label


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub_tabs = TabContainer.new()
	_sub_tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_sub_tabs)
	_build_graphics_tab()
	_build_audio_tab()
	_build_input_tab()
	_build_misc_tab()
	_build_debug_tab()


func refresh() -> void:
	_refresh_input_list()


func _build_graphics_tab() -> void:
	_graphics_box = VBoxContainer.new()
	_sub_tabs.add_child(_graphics_box)
	_sub_tabs.set_tab_title(0, "Graphics")
	var window_button := Button.new()
	window_button.text = "Window Mode: %s" % Settings.window_mode
	window_button.pressed.connect(func() -> void:
		Settings.cycle_window_mode()
		window_button.text = "Window Mode: %s" % Settings.window_mode
		menu.call("show_message", "Window mode: %s" % Settings.window_mode)
	)
	_graphics_box.add_child(window_button)
	var vsync_check := CheckBox.new()
	vsync_check.text = "VSync"
	vsync_check.button_pressed = Settings.vsync_enabled
	vsync_check.toggled.connect(func(enabled: bool) -> void:
		Settings.set_vsync(enabled)
	)
	_graphics_box.add_child(vsync_check)
	var scale_label := Label.new()
	scale_label.text = "Resolution Scale: %.2f" % Settings.resolution_scale
	_graphics_box.add_child(scale_label)
	var scale_slider := HSlider.new()
	scale_slider.min_value = 0.5
	scale_slider.max_value = 1.5
	scale_slider.step = 0.05
	scale_slider.value = Settings.resolution_scale
	scale_slider.value_changed.connect(func(value: float) -> void:
		Settings.set_resolution_scale(value)
		scale_label.text = "Resolution Scale: %.2f" % value
	)
	_graphics_box.add_child(scale_slider)


func _build_audio_tab() -> void:
	_audio_box = VBoxContainer.new()
	_sub_tabs.add_child(_audio_box)
	_sub_tabs.set_tab_title(1, "Audio")
	_audio_box.add_child(_make_volume_row("Master", Settings.master_volume, Settings.set_master_volume))
	_audio_box.add_child(_make_volume_row("Music", Settings.music_volume, Settings.set_music_volume))
	_audio_box.add_child(_make_volume_row("SFX", Settings.sfx_volume, Settings.set_sfx_volume))


func _build_input_tab() -> void:
	var box := VBoxContainer.new()
	_sub_tabs.add_child(box)
	_sub_tabs.set_tab_title(2, "Input")
	_input_list = ItemList.new()
	_input_list.custom_minimum_size = Vector2(0, 260)
	box.add_child(_input_list)
	var actions := HBoxContainer.new()
	_rebind_button = Button.new()
	_rebind_button.text = "Rebind Selected"
	_rebind_button.pressed.connect(_on_rebind_pressed)
	actions.add_child(_rebind_button)
	_clear_button = Button.new()
	_clear_button.text = "Clear Binding"
	_clear_button.pressed.connect(_on_clear_pressed)
	actions.add_child(_clear_button)
	box.add_child(actions)
	_refresh_input_list()


func _build_misc_tab() -> void:
	var box := VBoxContainer.new()
	_sub_tabs.add_child(box)
	_sub_tabs.set_tab_title(3, "Misc")
	_misc_label = Label.new()
	_misc_label.text = "Misc settings will be added later."
	box.add_child(_misc_label)


func _build_debug_tab() -> void:
	var box := VBoxContainer.new()
	_sub_tabs.add_child(box)
	_sub_tabs.set_tab_title(4, "Debug")
	_debug_label = Label.new()
	_debug_label.text = "Developer debug tools will be added later."
	box.add_child(_debug_label)


func _make_volume_row(label_text: String, initial_value: float, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size = Vector2(120, 0)
	label.text = label_text
	row.add_child(label)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial_value
	slider.value_changed.connect(func(value: float) -> void:
		setter.call(value)
	)
	row.add_child(slider)
	return row


func _refresh_input_list() -> void:
	if _input_list == null:
		return
	_input_list.clear()
	for action_name: String in Settings.REBINDABLE_ACTIONS:
		var events := Settings.get_action_events(action_name)
		var binding_text := "Unbound"
		if not events.is_empty():
			binding_text = Settings.format_input_event(events[0] as InputEvent)
		var index := _input_list.item_count
		_input_list.add_item("%s: %s" % [Settings.get_action_display_name(action_name), binding_text])
		_input_list.set_item_metadata(index, action_name)


func _on_rebind_pressed() -> void:
	var selected := _input_list.get_selected_items()
	if selected.is_empty():
		menu.call("show_message", "Select an action to rebind.")
		return
	var action_name := str(_input_list.get_item_metadata(selected[0]))
	Settings.begin_rebind(action_name)
	menu.call("show_message", "Press a key or controller button...")


func _on_clear_pressed() -> void:
	var selected := _input_list.get_selected_items()
	if selected.is_empty():
		menu.call("show_message", "Select an action to clear.")
		return
	var action_name := str(_input_list.get_item_metadata(selected[0]))
	Settings.clear_binding(action_name)
	_refresh_input_list()
	menu.call("show_message", "Binding cleared for %s." % Settings.get_action_display_name(action_name))
