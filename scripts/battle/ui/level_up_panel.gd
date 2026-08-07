class_name LevelUpPanel
extends Control

signal allocation_confirmed

const STAT_NAMES: Array[String] = ["str", "dex", "vit", "agi", "int", "mnd", "res", "luk"]
const PartyStatsHelper = preload("res://scripts/data/party_stats.gd")
const StatDescriptionsScript = preload("res://scripts/data/stat_descriptions.gd")

const COL_STAT_WIDTH: int = 52
const COL_VALUE_WIDTH: int = 44
const COL_BUTTON_WIDTH: int = 36

@onready var portrait_rect: TextureRect = $Panel/Margin/VBox/TopRow/Portrait
@onready var name_label: Label = $Panel/Margin/VBox/TopRow/Info/NameLabel
@onready var level_label: Label = $Panel/Margin/VBox/TopRow/Info/LevelLabel
@onready var growth_grid: GridContainer = $Panel/Margin/VBox/GrowthGrid
@onready var points_label: Label = $Panel/Margin/VBox/PointsLabel
@onready var allocation_grid: GridContainer = $Panel/Margin/VBox/AllocationGrid
@onready var reset_button: Button = $Panel/Margin/VBox/Footer/ResetButton
@onready var confirm_button: Button = $Panel/Margin/VBox/Footer/ConfirmButton

var _character_id: String = ""
var _stat_value_labels: Dictionary = {}
var _tooltip_dialog: AcceptDialog = null


func _ready() -> void:
	allocation_grid.columns = 4
	allocation_grid.add_theme_constant_override("h_separation", 10)
	allocation_grid.add_theme_constant_override("v_separation", 4)
	growth_grid.columns = 2
	growth_grid.add_theme_constant_override("h_separation", 12)
	growth_grid.add_theme_constant_override("v_separation", 2)
	reset_button.pressed.connect(_on_reset_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	_build_allocation_grid()
	visible = false


func show_level_up(character_id: String) -> void:
	_character_id = character_id
	GameState.begin_level_up_allocation(character_id)
	_refresh_all()
	visible = true


func _build_allocation_grid() -> void:
	_add_grid_header_label(allocation_grid, "Stat", HORIZONTAL_ALIGNMENT_LEFT)
	_add_grid_header_label(allocation_grid, "Add", HORIZONTAL_ALIGNMENT_CENTER)
	_add_grid_header_label(allocation_grid, "", HORIZONTAL_ALIGNMENT_CENTER)
	_add_grid_header_label(allocation_grid, "", HORIZONTAL_ALIGNMENT_CENTER)

	for stat_name: String in STAT_NAMES:
		var name_button := Button.new()
		name_button.text = stat_name.to_upper()
		name_button.flat = true
		name_button.focus_mode = Control.FOCUS_NONE
		name_button.custom_minimum_size = Vector2(COL_STAT_WIDTH, 0)
		name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_button.pressed.connect(_show_stat_tooltip.bind(stat_name))
		name_button.gui_input.connect(_on_stat_name_gui_input.bind(stat_name))
		allocation_grid.add_child(name_button)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(COL_VALUE_WIDTH, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		allocation_grid.add_child(value_label)
		_stat_value_labels[stat_name] = value_label

		var minus_button := Button.new()
		minus_button.text = "-"
		minus_button.custom_minimum_size = Vector2(COL_BUTTON_WIDTH, 28)
		minus_button.pressed.connect(_on_minus_pressed.bind(stat_name))
		allocation_grid.add_child(minus_button)

		var plus_button := Button.new()
		plus_button.text = "+"
		plus_button.custom_minimum_size = Vector2(COL_BUTTON_WIDTH, 28)
		plus_button.pressed.connect(_on_plus_pressed.bind(stat_name))
		allocation_grid.add_child(plus_button)


func _refresh_all() -> void:
	var characters := DataLoader.load_characters()
	if not characters.has(_character_id):
		return
	var character: CharacterData = characters[_character_id]
	var snapshot := GameState.get_member_snapshot(_character_id)
	if snapshot == null:
		return
	var level_entry := GameState.get_level_up_entry(_character_id)

	name_label.text = character.display_name
	if level_entry.is_empty():
		level_label.text = "Level %d" % snapshot.level
	else:
		level_label.text = "Level %d → %d" % [
			int(level_entry.get("old_level", snapshot.level)),
			int(level_entry.get("new_level", snapshot.level)),
		]

	if not character.portrait_path.is_empty() and ResourceLoader.exists(character.portrait_path):
		portrait_rect.texture = load(character.portrait_path)
	else:
		portrait_rect.texture = null

	_refresh_growth_grid(character, snapshot, level_entry)
	_refresh_allocation_labels()


func _refresh_allocation_labels() -> void:
	var draft := GameState.get_draft_allocated_stats()
	var remaining := GameState.get_draft_remaining_points()
	var spent := 0
	for stat_name: String in STAT_NAMES:
		spent += draft.get_stat(stat_name)
	points_label.text = "Points remaining: %d / %d" % [remaining, remaining + spent]

	for stat_name: String in STAT_NAMES:
		var label: Label = _stat_value_labels[stat_name] as Label
		label.text = "+%d" % draft.get_stat(stat_name)

	confirm_button.disabled = remaining > 0


func _refresh_growth_grid(
	character: CharacterData,
	snapshot: PartyMemberSnapshot,
	level_entry: Dictionary
) -> void:
	for child: Node in growth_grid.get_children():
		child.queue_free()

	_add_grid_header_label(growth_grid, "Stat", HORIZONTAL_ALIGNMENT_LEFT)
	_add_grid_header_label(growth_grid, "Value", HORIZONTAL_ALIGNMENT_LEFT)

	var progression: StatBlock = PartyStatsHelper.get_progression_stats(character, snapshot)
	var auto_growth: StatBlock = level_entry.get("auto_growth", StatBlock.new()) as StatBlock
	for stat_name: String in STAT_NAMES:
		var stat_label := Label.new()
		stat_label.text = stat_name.to_upper()
		stat_label.custom_minimum_size = Vector2(COL_STAT_WIDTH, 0)
		growth_grid.add_child(stat_label)

		var value_label := RichTextLabel.new()
		value_label.bbcode_enabled = true
		value_label.fit_content = true
		value_label.scroll_active = false
		value_label.custom_minimum_size = Vector2(COL_VALUE_WIDTH + 80, 0)
		var value: int = progression.get_stat(stat_name)
		var growth: int = auto_growth.get_stat(stat_name)
		if growth > 0:
			value_label.text = "%d [color=green](+%d)[/color]" % [value, growth]
		else:
			value_label.text = str(value)
		growth_grid.add_child(value_label)


func _add_grid_header_label(
	grid: GridContainer,
	text: String,
	alignment: HorizontalAlignment
) -> void:
	var label := Label.new()
	label.text = text
	if not text.is_empty():
		label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	if grid == allocation_grid:
		var width := COL_STAT_WIDTH
		if text == "Add":
			width = COL_VALUE_WIDTH
		elif text.is_empty():
			width = COL_BUTTON_WIDTH
		label.custom_minimum_size = Vector2(width, 0)
	else:
		label.custom_minimum_size = Vector2(COL_STAT_WIDTH if text == "Stat" else COL_VALUE_WIDTH + 80, 0)
	label.horizontal_alignment = alignment
	grid.add_child(label)


func _on_plus_pressed(stat_name: String) -> void:
	GameState.draft_allocate_stat(stat_name)
	_refresh_allocation_labels()


func _on_minus_pressed(stat_name: String) -> void:
	GameState.draft_deallocate_stat(stat_name)
	_refresh_allocation_labels()


func _on_reset_pressed() -> void:
	GameState.reset_draft_allocation()
	_refresh_allocation_labels()


func _on_confirm_pressed() -> void:
	if GameState.get_draft_remaining_points() > 0:
		return
	GameState.confirm_draft_allocation()
	visible = false
	allocation_confirmed.emit()


func _on_stat_name_gui_input(event: InputEvent, stat_name: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_show_stat_tooltip(stat_name)


func _show_stat_tooltip(stat_name: String) -> void:
	var text: String = StatDescriptionsScript.get_description(stat_name)
	if text.is_empty():
		return
	if _tooltip_dialog == null:
		_tooltip_dialog = AcceptDialog.new()
		add_child(_tooltip_dialog)
	_tooltip_dialog.title = stat_name.to_upper()
	_tooltip_dialog.dialog_text = text
	_tooltip_dialog.popup_centered()
