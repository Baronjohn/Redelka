class_name NarrativeDialogUI
extends CanvasLayer

const PANEL_HEIGHT: float = 220.0
const PORTRAIT_SIZE: float = 200.0
const SIDE_MARGIN: float = 80.0
const BOTTOM_MARGIN: float = 40.0

var _lines: Array = []
var _line_index: int = 0
var _pending_choices: Array = []
var _pending_choice_index: int = -1
var _portrait_default: Texture2D = null
var _on_complete: Callable = Callable()
var _is_advancing: bool = false


@onready var _panel: PanelContainer = $Panel
@onready var _portrait_rect: TextureRect = $Panel/Margin/HBox/PortraitRect
@onready var _name_label: Label = $Panel/Margin/HBox/TextColumn/NameLabel
@onready var _line_label: RichTextLabel = $Panel/Margin/HBox/TextColumn/LineLabel
@onready var _continue_label: Label = $Panel/Margin/ContinueLabel
@onready var _choice_box: VBoxContainer = $ChoiceBox


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_choice_box.visible = false
	_continue_label.visible = false
	_choice_box.choice_made.connect(_on_choice_made)
	set_process_unhandled_input(true)


func is_active() -> bool:
	return _panel.visible or _choice_box.visible


func start(dialog: Dictionary, on_complete: Callable) -> void:
	_lines = dialog.get("lines", []) as Array
	_line_index = 0
	_on_complete = on_complete
	_pending_choices = []
	_pending_choice_index = -1
	_panel.visible = true
	_choice_box.visible = false
	_continue_label.visible = false
	if dialog.has("pending_choices"):
		_pending_choices = dialog.get("pending_choices", []) as Array
		_pending_choice_index = int(dialog.get("pending_choice_after", -1))
	_show_current_line()


func stop() -> void:
	_panel.visible = false
	_choice_box.visible = false
	_continue_label.visible = false
	_lines = []
	_line_index = 0


func _show_current_line() -> void:
	if _line_index >= _lines.size():
		_finish_dialog("")
		return
	var line: Dictionary = _lines[_line_index] as Dictionary
	var speaker_id := str(line.get("speaker", ""))
	var speaker_meta := NarrativeDirector.get_speaker_meta(speaker_id)
	var display_name := str(speaker_meta.get("name", speaker_id.capitalize()))
	var portrait_path := str(speaker_meta.get("portrait", ""))
	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		_portrait_rect.texture = _portrait_default
	else:
		var tex := load(portrait_path) as Texture2D
		_portrait_rect.texture = tex
	var color := speaker_meta.get("color", Color(1, 1, 1, 1)) as Color
	_name_label.text = display_name
	_name_label.modulate = color
	_line_label.text = str(line.get("text", ""))
	_line_label.visible_ratio = 0.0
	_continue_label.visible = false
	if _pending_choice_index == _line_index and not _pending_choices.is_empty():
		_choice_box.set_choices(_pending_choices)
		_choice_box.visible = true
		_panel.visible = false
		_continue_label.visible = false
		return
	_choice_box.visible = false
	_panel.visible = true
	_is_advancing = false


func _on_choice_made(choice: Dictionary) -> void:
	_choice_box.visible = false
	var choice_id := str(choice.get("id", ""))
	var next_id := str(choice.get("next", ""))
	_panel.visible = true
	if next_id.is_empty():
		_finish_dialog(choice_id)
		return
	_play_followup(next_id, choice_id)


func _play_followup(dialog_id: String, prev_choice_id: String) -> void:
	_panel.visible = false
	_choice_box.visible = false
	var all_dialogs := DataLoader.load_json_object("res://data/dialogs.json")
	if not all_dialogs.has(dialog_id):
		_finish_dialog(prev_choice_id)
		return
	var raw := all_dialogs[dialog_id] as Dictionary
	_lines = (raw.get("lines", []) as Array).duplicate()
	_line_index = 0
	_pending_choices = []
	_pending_choice_index = -1
	var groups := raw.get("choices", []) as Array
	if not groups.is_empty():
		for group: Dictionary in groups:
			if _pending_choice_index == -1:
				_pending_choice_index = int(group.get("after_line", -1))
			for option: Dictionary in (group.get("options", []) as Array):
				_pending_choices.append(option)
	_panel.visible = true
	_show_current_line()


func _finish_dialog(choice_id: String) -> void:
	_panel.visible = false
	_choice_box.visible = false
	_continue_label.visible = false
	var callback := _on_complete
	_on_complete = Callable()
	if not callback.is_valid():
		callback = Callable(NarrativeDirector, "_on_dialog_default_finished")
	callback.call(choice_id)


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if _is_advancing:
		return
	if _choice_box.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_advance()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	if _choice_box.visible:
		return
	if _line_label.visible_ratio < 1.0:
		_line_label.visible_ratio = minf(1.0, _line_label.visible_ratio + 0.04)
		if _line_label.visible_ratio >= 1.0:
			_continue_label.visible = true
	else:
		_continue_label.visible = true


func _advance() -> void:
	_is_advancing = true
	if _line_label.visible_ratio < 1.0:
		_line_label.visible_ratio = 1.0
		_continue_label.visible = true
		_is_advancing = false
		return
	_line_index += 1
	_show_current_line()
