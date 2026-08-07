class_name SaveSlotPanel
extends Control

signal save_completed(slot: int)
signal load_completed
signal closed

const STAT_NAMES: Array[String] = ["str", "dex", "vit", "agi", "int", "mnd", "res", "luk"]

enum Mode { SAVE, LOAD }
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var slot_list: ItemList = $Panel/Margin/VBox/SlotList
@onready var error_label: Label = $Panel/Margin/VBox/ErrorLabel
@onready var action_button: Button = $Panel/Margin/VBox/Buttons/ActionButton
@onready var back_button: Button = $Panel/Margin/VBox/Buttons/BackButton
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog

var _mode: Mode = Mode.LOAD
var _selected_slot: int = -1
var _selected_is_autosave: bool = false
var _save_position: Vector3 = Vector3.ZERO
var _save_rotation_y: float = 0.0
var _selected_read_status: int = SaveManager.SaveReadStatus.MISSING


func _ready() -> void:
	slot_list.item_selected.connect(_on_slot_selected)
	action_button.pressed.connect(_on_action_pressed)
	back_button.pressed.connect(_on_back_pressed)
	confirm_dialog.confirmed.connect(_on_confirm_overwrite)
	visible = false


func open_save_mode(player_position: Vector3, player_rotation_y: float) -> void:
	_mode = Mode.SAVE
	_save_position = player_position
	_save_rotation_y = player_rotation_y
	title_label.text = "Save Game"
	action_button.text = "Save"
	action_button.disabled = true
	back_button.text = "Cancel"
	_clear_error()
	_populate_save_list()
	visible = true


func open_load_mode(include_autosave: bool = true) -> void:
	_mode = Mode.LOAD
	title_label.text = "Load Game"
	action_button.text = "Load"
	action_button.disabled = true
	back_button.text = "Back"
	_clear_error()
	_populate_load_list(include_autosave)
	visible = true


func _populate_save_list() -> void:
	slot_list.clear()
	_selected_slot = -1
	for slot: int in range(1, SaveManager.SLOT_COUNT + 1):
		var read_status := SaveManager.get_slot_read_status(slot)
		var metadata := SaveManager.get_slot_metadata(slot)
		var index := slot_list.item_count
		slot_list.add_item(SaveManager.format_slot_label(slot, metadata, false, read_status))
		slot_list.set_item_metadata(index, {
			"slot": slot,
			"is_autosave": false,
			"read_status": read_status,
		})


func _populate_load_list(include_autosave: bool) -> void:
	slot_list.clear()
	_selected_slot = -1
	if include_autosave and SaveManager.has_autosave():
		var autosave_status := SaveManager.get_autosave_read_status()
		var autosave_meta := SaveManager.get_autosave_metadata()
		var index := slot_list.item_count
		slot_list.add_item(SaveManager.format_slot_label(0, autosave_meta, true, autosave_status))
		slot_list.set_item_metadata(index, {
			"slot": 0,
			"is_autosave": true,
			"read_status": autosave_status,
		})
	for slot: int in range(1, SaveManager.SLOT_COUNT + 1):
		var read_status := SaveManager.get_slot_read_status(slot)
		if read_status == SaveManager.SaveReadStatus.MISSING:
			continue
		var metadata := SaveManager.get_slot_metadata(slot)
		var item_index := slot_list.item_count
		slot_list.add_item(SaveManager.format_slot_label(slot, metadata, false, read_status))
		slot_list.set_item_metadata(item_index, {
			"slot": slot,
			"is_autosave": false,
			"read_status": read_status,
		})


func _on_slot_selected(index: int) -> void:
	var meta := slot_list.get_item_metadata(index) as Dictionary
	_selected_slot = int(meta.get("slot", -1))
	_selected_is_autosave = bool(meta.get("is_autosave", false))
	_selected_read_status = int(meta.get("read_status", SaveManager.SaveReadStatus.MISSING))
	_clear_error()
	if _mode == Mode.LOAD and _selected_read_status != SaveManager.SaveReadStatus.OK:
		action_button.disabled = true
		_show_error("This save file is corrupted and cannot be loaded.")
		return
	action_button.disabled = _selected_slot < 0


func _on_action_pressed() -> void:
	if _selected_slot < 0:
		return
	match _mode:
		Mode.SAVE:
			if _selected_is_autosave:
				return
			var metadata := SaveManager.get_slot_metadata(_selected_slot)
			if metadata.is_empty():
				_commit_save(_selected_slot)
			else:
				confirm_dialog.dialog_text = "Overwrite save in slot %02d?" % _selected_slot
				confirm_dialog.popup_centered()
		Mode.LOAD:
			if _selected_read_status != SaveManager.SaveReadStatus.OK:
				_show_error("This save file is corrupted and cannot be loaded.")
				return
			var loaded := false
			if _selected_is_autosave:
				loaded = GameState.load_autosave()
			else:
				loaded = GameState.load_from_slot(_selected_slot)
			if loaded:
				load_completed.emit()
			else:
				_show_error(GameState.last_save_error)


func _on_confirm_overwrite() -> void:
	_commit_save(_selected_slot)


func _commit_save(slot: int) -> void:
	if GameState.save_to_slot(slot, _save_position, _save_rotation_y):
		save_completed.emit(slot)
		visible = false
		closed.emit()
	else:
		_show_error(GameState.last_save_error)


func save_at_player(player_position: Vector3, player_rotation_y: float, slot: int) -> bool:
	return GameState.save_to_slot(slot, player_position, player_rotation_y)


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


func show_error(text: String) -> void:
	_show_error(text)


func _show_error(text: String) -> void:
	error_label.text = text


func _clear_error() -> void:
	error_label.text = ""
