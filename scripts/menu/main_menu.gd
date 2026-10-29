extends Control

const CONFIG_TAB := preload("res://scripts/menu/tabs/config_tab.gd")
const SAVE_SLOT_PANEL_SCENE: PackedScene = preload("res://scenes/menu/save_slot_panel.tscn")

const DIFFICULTY_HINTS: Dictionary = {
	"EasyButton": "Autosave at every door, on top of save points.",
	"NormalButton": "Save only at save points.",
	"HardButton": "Each save at a save point spends a Memory Tape.",
}

@onready var main_buttons: VBoxContainer = %MainButtons
@onready var load_game_button: Button = %LoadGameButton
@onready var difficulty_panel: VBoxContainer = %DifficultyPanel
@onready var message_label: Label = %MessageLabel
@onready var section_label: Label = %SectionLabel

var _config_overlay: CanvasLayer = null
var _save_panel: Control = null


func _ready() -> void:
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%LoadGameButton.pressed.connect(_on_load_game_pressed)
	%ConfigButton.pressed.connect(_on_config_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	%EasyButton.pressed.connect(_start_new_game.bind(GameState.Difficulty.EASY))
	%NormalButton.pressed.connect(_start_new_game.bind(GameState.Difficulty.NORMAL))
	%HardButton.pressed.connect(_start_new_game.bind(GameState.Difficulty.HARD))
	%DifficultyBackButton.pressed.connect(_show_main_buttons)
	for button: Button in main_buttons.get_children():
		SfxManager.wire_menu_button(button)
	for button: Button in difficulty_panel.get_children():
		SfxManager.wire_menu_button(button, button.name != "DifficultyBackButton")
		if DIFFICULTY_HINTS.has(button.name):
			var hint := str(DIFFICULTY_HINTS[button.name])
			button.focus_entered.connect(show_message.bind(hint))
			button.mouse_entered.connect(show_message.bind(hint))
	_update_load_button_state()
	_show_main_buttons()
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if _config_overlay != null and Settings.is_rebinding():
		var result := Settings.process_rebind_event(event)
		if not result.is_empty():
			show_message(result)
			get_viewport().set_input_as_handled()


func show_message(text: String) -> void:
	message_label.text = text


func _on_new_game_pressed() -> void:
	main_buttons.visible = false
	difficulty_panel.visible = true
	section_label.visible = true
	show_message("")
	%NormalButton.grab_focus()


func _show_main_buttons() -> void:
	main_buttons.visible = true
	difficulty_panel.visible = false
	section_label.visible = false
	show_message("")
	_update_load_button_state()
	%NewGameButton.grab_focus()


func _update_load_button_state() -> void:
	load_game_button.disabled = not SaveManager.has_loadable_save()


func _start_new_game(chosen_difficulty: int) -> void:
	GameState.start_new_game(chosen_difficulty)
	await SceneTransition.go_to_explore()


func _on_load_game_pressed() -> void:
	_open_save_panel_load()


func _open_save_panel_load() -> void:
	if _save_panel == null:
		_save_panel = SAVE_SLOT_PANEL_SCENE.instantiate() as Control
		add_child(_save_panel)
		_save_panel.load_completed.connect(_on_save_loaded)
		_save_panel.closed.connect(func() -> void: _save_panel.visible = false)
	_save_panel.open_load_mode(true)


func _on_save_loaded() -> void:
	await SceneTransition.go_to_explore()


func _on_config_pressed() -> void:
	if _config_overlay != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var dimmer := ColorRect.new()
	dimmer.color = Color(UiPalette.INK, 0.8)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dimmer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120.0
	panel.offset_top = 80.0
	panel.offset_right = -120.0
	panel.offset_bottom = -80.0
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(root)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "Config"
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close_config_overlay)
	header.add_child(close_button)
	root.add_child(header)
	var config_tab := Control.new()
	config_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	config_tab.set_script(CONFIG_TAB)
	config_tab.set("menu", self)
	root.add_child(config_tab)
	config_tab.call("setup")
	config_tab.call("refresh")
	var footer := Label.new()
	footer.name = "ConfigMessageLabel"
	footer.theme_type_variation = &"HintLabel"
	root.add_child(footer)
	_config_overlay = layer


func _close_config_overlay() -> void:
	if _config_overlay != null:
		_config_overlay.queue_free()
		_config_overlay = null


func _on_quit_pressed() -> void:
	get_tree().quit()
