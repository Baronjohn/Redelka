class_name ResultPanel
extends Control

signal restart_requested
signal continue_requested

@onready var title_label: Label = $Panel/VBox/TitleLabel
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
	if from_explore:
		continue_button.visible = true
		continue_button.text = "Continue" if outcome != 2 else "Reload Checkpoint"
		restart_button.visible = false
	else:
		continue_button.visible = false
		restart_button.visible = true
	visible = true
