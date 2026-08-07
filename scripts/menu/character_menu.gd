extends Control

signal closed

const ITEMS_TAB := preload("res://scripts/menu/tabs/items_tab.gd")
const EQUIPMENT_TAB := preload("res://scripts/menu/tabs/equipment_tab.gd")
const STATUS_TAB := preload("res://scripts/menu/tabs/status_tab.gd")
const MAP_TAB := preload("res://scripts/menu/tabs/map_tab.gd")
const CONFIG_TAB := preload("res://scripts/menu/tabs/config_tab.gd")

@onready var party_sidebar: VBoxContainer = $ScreenMargin/Root/Body/PartySidebar
@onready var tab_buttons: HBoxContainer = $ScreenMargin/Root/Body/Content/TabBar
@onready var tab_content: Control = $ScreenMargin/Root/Body/Content/TabContent
@onready var message_label: Label = $ScreenMargin/Root/Footer/MessageLabel

var _tabs: Dictionary = {}
var _tab_roots: Dictionary = {}
var _active_tab_name: String = "items"
var _selected_character_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _selected_character_id.is_empty() and not GameState.party_members.is_empty():
		var first := GameState.party_members[0] as PartyMemberSnapshot
		_selected_character_id = first.character_id
	_build_party_sidebar()
	_register_tab("Items", ITEMS_TAB)
	_register_tab("Equipment", EQUIPMENT_TAB)
	_register_tab("Status", STATUS_TAB)
	_register_tab("Map", MAP_TAB)
	_register_tab("Config", CONFIG_TAB)
	_select_tab("Items")
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if Settings.is_rebinding():
		var result := Settings.process_rebind_event(event)
		if not result.is_empty():
			show_message(result)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu_cancel") or event.is_action_pressed("open_menu"):
		close_menu()
		get_viewport().set_input_as_handled()


func close_menu() -> void:
	closed.emit()
	queue_free()


func show_message(text: String) -> void:
	message_label.text = text


func refresh_all() -> void:
	_refresh_party_sidebar()
	for tab_name: String in _tabs.keys():
		var tab: Control = _tabs[tab_name] as Control
		if tab.has_method("refresh"):
			tab.call("refresh")


func get_selected_character_id() -> String:
	if _selected_character_id.is_empty() and not GameState.party_members.is_empty():
		var first := GameState.party_members[0] as PartyMemberSnapshot
		return first.character_id
	return _selected_character_id


func set_selected_character(character_id: String) -> void:
	_selected_character_id = character_id
	_refresh_party_sidebar()
	var tab: Control = _tabs.get(_active_tab_name) as Control
	if tab != null and tab.has_method("refresh"):
		tab.call("refresh")


func _register_tab(label: String, script_type: Script) -> void:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_select_tab.bind(label))
	tab_buttons.add_child(button)
	var tab := Control.new()
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.set_script(script_type)
	tab.name = label
	tab.set("menu", self)
	var tab_margin := MarginContainer.new()
	tab_margin.name = "%sRoot" % label
	tab_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab_margin.add_theme_constant_override("margin_left", 4)
	tab_margin.add_theme_constant_override("margin_top", 4)
	tab_margin.add_theme_constant_override("margin_right", 8)
	tab_margin.add_theme_constant_override("margin_bottom", 8)
	tab_margin.add_child(tab)
	tab_content.add_child(tab_margin)
	tab.call("setup")
	_tabs[label] = tab
	_tab_roots[label] = tab_margin


func _select_tab(label: String) -> void:
	_active_tab_name = label
	for tab_name: String in _tab_roots.keys():
		var tab_root: Control = _tab_roots[tab_name] as Control
		tab_root.visible = tab_name == label
		if tab_name == label:
			var tab: Control = _tabs[tab_name] as Control
			if tab.has_method("refresh"):
				tab.call("refresh")
	_refresh_party_sidebar()


func _should_highlight_selection() -> bool:
	return _active_tab_name in ["Items", "Equipment", "Status"]


func _build_party_sidebar() -> void:
	for child: Node in party_sidebar.get_children():
		child.queue_free()
	var characters := DataLoader.load_characters()
	for member_variant: Variant in GameState.party_members:
		var snapshot := member_variant as PartyMemberSnapshot
		var character: CharacterData = characters[snapshot.character_id]

		var entry := Control.new()
		entry.custom_minimum_size = Vector2(252, 72)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.set_meta("character_id", snapshot.character_id)

		var panel := PanelContainer.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_entry_style(panel, snapshot.character_id)
		entry.add_child(panel)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 6)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		margin.add_child(row)

		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(56, 56)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not character.portrait_path.is_empty() and ResourceLoader.exists(character.portrait_path):
			portrait.texture = load(character.portrait_path)
		row.add_child(portrait)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := Label.new()
		name_label.text = character.display_name
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bars := Label.new()
		bars.text = _format_member_stats(snapshot)
		bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(name_label)
		info.add_child(bars)
		row.add_child(info)

		var select_button := Button.new()
		select_button.flat = true
		select_button.set_anchors_preset(Control.PRESET_FULL_RECT)
		select_button.focus_mode = Control.FOCUS_ALL
		select_button.pressed.connect(set_selected_character.bind(snapshot.character_id))
		entry.add_child(select_button)

		party_sidebar.add_child(entry)


func _refresh_party_sidebar() -> void:
	for child: Node in party_sidebar.get_children():
		if not child is Control or not child.has_meta("character_id"):
			continue
		var entry := child as Control
		var character_id := str(entry.get_meta("character_id"))
		var panel := entry.get_child(0) as PanelContainer
		_apply_entry_style(panel, character_id)
		var snapshot := GameState.get_member_snapshot(character_id)
		if snapshot == null:
			continue
		var margin := panel.get_child(0) as MarginContainer
		var row := margin.get_child(0) as HBoxContainer
		var info := row.get_child(1) as VBoxContainer
		var bars := info.get_child(1) as Label
		bars.text = _format_member_stats(snapshot)


func _apply_entry_style(panel: PanelContainer, character_id: String) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	var selected := character_id == get_selected_character_id()
	if selected and _should_highlight_selection():
		style.bg_color = Color(0.95, 0.82, 0.28, 0.18)
		style.border_color = Color(0.95, 0.82, 0.28, 0.95)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.14, 0.15, 0.18, 0.95)
		style.border_color = Color(0.28, 0.3, 0.36, 0.9)
		style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)


func _format_member_stats(snapshot: PartyMemberSnapshot) -> String:
	return "HP %d/%d  MP %d/%d%s" % [
		snapshot.current_hp,
		snapshot.max_hp,
		snapshot.current_mp,
		snapshot.max_mp,
		" KO" if snapshot.is_ko else "",
	]
