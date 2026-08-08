class_name ResultPanel
extends Control

signal restart_requested
signal continue_requested
signal load_save_requested
signal load_autosave_requested
signal main_menu_requested

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var loot_label: Label = $Panel/VBox/LootLabel
@onready var restart_button: Button = $Panel/VBox/RestartButton
@onready var continue_button: Button = $Panel/VBox/ContinueButton
@onready var game_over_buttons: VBoxContainer = $Panel/VBox/GameOverButtons
@onready var load_save_button: Button = $Panel/VBox/GameOverButtons/LoadSaveButton
@onready var load_autosave_button: Button = $Panel/VBox/GameOverButtons/LoadAutosaveButton
@onready var main_menu_button: Button = $Panel/VBox/GameOverButtons/MainMenuButton


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	load_save_button.pressed.connect(func() -> void: load_save_requested.emit())
	load_autosave_button.pressed.connect(func() -> void: load_autosave_requested.emit())
	main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	visible = false


func show_result(outcome: int, from_explore: bool = false) -> void:
	game_over_buttons.visible = false
	restart_button.visible = false
	continue_button.visible = false
	match outcome:
		1:
			title_label.text = "Victory"
		2:
			title_label.text = "Game Over"
		3:
			title_label.text = "Escaped"
		_:
			title_label.text = ""
	if outcome == 2 and from_explore:
		loot_label.text = "Your party was defeated."
		game_over_buttons.visible = true
		load_autosave_button.visible = (
			GameState.difficulty == GameState.Difficulty.EASY and SaveManager.has_autosave()
		)
	else:
		loot_label.text = _format_result_text(outcome)
		if from_explore:
			continue_button.visible = true
			continue_button.text = "Continue"
		else:
			restart_button.visible = true
	visible = true


func _format_result_text(outcome: int) -> String:
	if outcome != 1:
		return ""
	var lines: PackedStringArray = []
	var loot: Array = GameState.last_battle_loot
	if loot.is_empty():
		lines.append("No loot.")
	else:
		for entry_variant: Variant in loot:
			var entry := entry_variant as Dictionary
			lines.append("%s dropped: %s x%d" % [
				str(entry.get("enemy_name", "Enemy")),
				str(entry.get("item_name", entry.get("item_id", "Item"))),
				int(entry.get("count", 1)),
			])
	if GameState.last_battle_xp > 0:
		lines.append("+%d XP" % GameState.last_battle_xp)
	for entry_variant: Variant in GameState.last_level_ups:
		var entry := entry_variant as Dictionary
		lines.append("%s: Lv %d → %d" % [
			str(entry.get("name", "Ally")),
			int(entry.get("old_level", 1)),
			int(entry.get("new_level", 1)),
		])
	if GameState.has_pending_level_ups():
		lines.append("Press Continue to allocate stat points.")
	return "\n".join(lines)
