class_name ResultPanel
extends Control

signal restart_requested
signal continue_requested

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var loot_label: Label = $Panel/VBox/LootLabel
@onready var restart_button: Button = $Panel/VBox/RestartButton
@onready var continue_button: Button = $Panel/VBox/ContinueButton


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	visible = false


func show_result(outcome: int, from_explore: bool = false) -> void:
	match outcome:
		1:
			title_label.text = "Victory"
		2:
			title_label.text = "Defeat"
		3:
			title_label.text = "Escaped"
		_:
			title_label.text = ""
	loot_label.text = _format_loot_text(outcome)
	if from_explore:
		continue_button.visible = true
		continue_button.text = "Continue" if outcome != 2 else "Reload Checkpoint"
		restart_button.visible = false
	else:
		continue_button.visible = false
		restart_button.visible = true
	visible = true


func _format_loot_text(outcome: int) -> String:
	if outcome != 1:
		return ""
	var loot: Array = GameState.last_battle_loot
	if loot.is_empty():
		return "No loot."
	var lines: PackedStringArray = []
	for entry_variant: Variant in loot:
		var entry := entry_variant as Dictionary
		lines.append("%s dropped: %s x%d" % [
			str(entry.get("enemy_name", "Enemy")),
			str(entry.get("item_name", entry.get("item_id", "Item"))),
			int(entry.get("count", 1)),
		])
	return "\n".join(lines)
