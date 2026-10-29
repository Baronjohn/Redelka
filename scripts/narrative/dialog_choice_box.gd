class_name NarrativeDialogChoiceBox
extends VBoxContainer

signal choice_made(choice: Dictionary)

var _choices: Array = []
var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func set_choices(choices: Array) -> void:
	_clear_buttons()
	_choices = choices
	for entry: Dictionary in choices:
		var button := Button.new()
		button.text = str(entry.get("label", ""))
		button.focus_mode = Control.FOCUS_ALL
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.pressed.connect(_on_button_pressed.bind(entry))
		SfxManager.wire_menu_button(button, true)
		add_child(button)
		_buttons.append(button)
	visible = true
	if _buttons.size() > 0:
		_buttons[0].grab_focus()


func _clear_buttons() -> void:
	for button in _buttons:
		if is_instance_valid(button):
			button.queue_free()
	_buttons.clear()
	_choices.clear()
	visible = false


func _on_button_pressed(choice: Dictionary) -> void:
	_clear_buttons()
	choice_made.emit(choice)
