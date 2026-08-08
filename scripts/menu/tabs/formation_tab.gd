extends Control

const PartyFormationScript = preload("res://scripts/data/party_formation.gd")

var menu: Control

var _hint_label: Label
var _cell_buttons: Dictionary = {}


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	_hint_label = Label.new()
	_hint_label.text = "Select a party member, then click a tile in the first two rows."
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_hint_label)

	var display_rows: Array[int] = [PartyFormationScript.ROW_MAX, PartyFormationScript.ROW_MIN]
	for y: int in display_rows:
		var row_label := Label.new()
		row_label.text = "Front row" if y == PartyFormationScript.ROW_MAX else "Back row"
		root.add_child(row_label)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		root.add_child(row)

		for menu_x: int in CombatConstants.GRID_SIZE:
			var cell := Vector2i(menu_x, y)
			var button := Button.new()
			button.custom_minimum_size = Vector2(72, 56)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_ALL
			button.pressed.connect(_on_cell_pressed.bind(cell))
			row.add_child(button)
			_cell_buttons[cell] = button

	refresh()


func refresh() -> void:
	_update_cells()
	if menu != null:
		menu.call("show_message", "Select a party member, then assign a starting tile.")


func _update_cells() -> void:
	var characters := DataLoader.load_characters()
	var selected_id := str(menu.call("get_selected_character_id"))
	for y: int in range(PartyFormationScript.ROW_MIN, PartyFormationScript.ROW_MAX + 1):
		for menu_x: int in CombatConstants.GRID_SIZE:
			var cell := Vector2i(menu_x, y)
			var button: Button = _cell_buttons[cell]
			var occupant := GameState.get_formation_character_at(cell)
			if occupant.is_empty():
				button.text = "(%d,%d)" % [cell.x, cell.y]
				button.tooltip_text = "Empty tile"
			else:
				var character: CharacterData = characters[occupant]
				button.text = character.display_name
				button.tooltip_text = "%s at (%d, %d)" % [character.display_name, cell.x, cell.y]
			_apply_cell_style(button, occupant, selected_id)


func _apply_cell_style(button: Button, occupant: String, selected_id: String) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.set_border_width_all(1)
	if occupant == selected_id:
		style.bg_color = Color(0.95, 0.82, 0.28, 0.22)
		style.border_color = Color(0.95, 0.82, 0.28, 0.95)
	elif not occupant.is_empty():
		style.bg_color = Color(0.22, 0.35, 0.55, 0.85)
		style.border_color = Color(0.35, 0.55, 0.85, 0.95)
	else:
		style.bg_color = Color(0.14, 0.15, 0.18, 0.95)
		style.border_color = Color(0.28, 0.3, 0.36, 0.9)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)


func _on_cell_pressed(cell: Vector2i) -> void:
	var character_id := str(menu.call("get_selected_character_id"))
	var result: Dictionary = GameState.set_formation_position(character_id, cell)
	menu.call("show_message", str(result.get("message", "Formation updated.")))
	_update_cells()
