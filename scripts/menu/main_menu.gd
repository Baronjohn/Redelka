extends Control

const CONFIG_TAB := preload("res://scripts/menu/tabs/config_tab.gd")
const SAVE_SLOT_PANEL_SCENE: PackedScene = preload("res://scenes/menu/save_slot_panel.tscn")

@onready var main_buttons: VBoxContainer = $Center/VBox/MainButtons
@onready var difficulty_panel: VBoxContainer = $Center/VBox/DifficultyPanel
@onready var message_label: Label = $Center/VBox/MessageLabel
@onready var title_label: Label = $Center/VBox/TitleLabel

var _config_overlay: CanvasLayer = null
var _save_panel: Control = null


func _ready() -> void:
	$Center/VBox/MainButtons/NewGameButton.pressed.connect(_on_new_game_pressed)
	$Center/VBox/MainButtons/LoadGameButton.pressed.connect(_on_load_game_pressed)
	$Center/VBox/MainButtons/ConfigButton.pressed.connect(_on_config_pressed)
	$Center/VBox/MainButtons/QuitButton.pressed.connect(_on_quit_pressed)
	$Center/VBox/DifficultyPanel/EasyButton.pressed.connect(_start_new_game.bind(GameState.Difficulty.EASY))
	$Center/VBox/DifficultyPanel/NormalButton.pressed.connect(_start_new_game.bind(GameState.Difficulty.NORMAL))
	$Center/VBox/DifficultyPanel/HardButton.pressed.connect(_start_new_game.bind(GameState.Difficulty.HARD))
	$Center/VBox/DifficultyPanel/DifficultyBackButton.pressed.connect(_show_main_buttons)
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
	title_label.text = "Choose Difficulty"
	show_message("")


func _show_main_buttons() -> void:
	main_buttons.visible = true
	difficulty_panel.visible = false
	title_label.text = "Redelka"
	show_message("")


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
	root.add_child(footer)
	_config_overlay = layer


func _close_config_overlay() -> void:
	if _config_overlay != null:
		_config_overlay.queue_free()
		_config_overlay = null


func _on_quit_pressed() -> void:
	get_tree().quit()
