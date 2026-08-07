class_name ResultPanel
extends Control

signal restart_requested

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var restart_button: Button = $Panel/VBox/RestartButton


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	visible = false


func show_result(outcome: int) -> void:
	match outcome:
		1:
			title_label.text = "Victory"
		2:
			title_label.text = "Defeat"
		3:
			title_label.text = "Escaped"
		_:
			title_label.text = ""
	visible = true
