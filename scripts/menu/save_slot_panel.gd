class_name SaveSlotPanel
extends Control

signal save_completed(slot: int)
signal load_completed
signal closed

const STAT_NAMES: Array[String] = ["str", "dex", "vit", "agi", "int", "mnd", "res", "luk"]
const SaveManagerScript = preload("res://scripts/data/save_manager.gd")

enum Mode { SAVE, LOAD }
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var slot_list: ItemList = $Panel/Margin/VBox/SlotList
@onready var action_button: Button = $Panel/Margin/VBox/Buttons/ActionButton
@onready var back_button: Button = $Panel/Margin/VBox/Buttons/BackButton
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog

var _mode: Mode = Mode.LOAD
var _selected_slot: int = -1
var _selected_is_autosave: bool = false
var _save_position: Vector3 = Vector3.ZERO
var _save_rotation_y: float = 0.0


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
	_populate_save_list()
	visible = true


func open_load_mode(include_autosave: bool = true) -> void:
	_mode = Mode.LOAD
	title_label.text = "Load Game"
	action_button.text = "Load"
	action_button.disabled = true
	back_button.text = "Back"
	_populate_load_list(include_autosave)
	visible = true


func _populate_save_list() -> void:
	slot_list.clear()
	_selected_slot = -1
	for slot: int in range(1, SaveManagerScript.SLOT_COUNT + 1):
		var metadata := SaveManagerScript.get_slot_metadata(slot)
		var index := slot_list.item_count
		slot_list.add_item(SaveManagerScript.format_slot_label(slot, metadata))
		slot_list.set_item_metadata(index, {"slot": slot, "is_autosave": false})


func _populate_load_list(include_autosave: bool) -> void:
	slot_list.clear()
	_selected_slot = -1
	if include_autosave and SaveManagerScript.has_autosave():
		var autosave_meta := SaveManagerScript.get_autosave_metadata()
		var index := slot_list.item_count
		slot_list.add_item(SaveManagerScript.format_slot_label(0, autosave_meta, true))
		slot_list.set_item_metadata(index, {"slot": 0, "is_autosave": true})
	for slot: int in range(1, SaveManagerScript.SLOT_COUNT + 1):
		var metadata := SaveManagerScript.get_slot_metadata(slot)
		if metadata.is_empty():
			continue
		var item_index := slot_list.item_count
		slot_list.add_item(SaveManagerScript.format_slot_label(slot, metadata))
		slot_list.set_item_metadata(item_index, {"slot": slot, "is_autosave": false})


func _on_slot_selected(index: int) -> void:
	var meta := slot_list.get_item_metadata(index) as Dictionary
	_selected_slot = int(meta.get("slot", -1))
	_selected_is_autosave = bool(meta.get("is_autosave", false))
	action_button.disabled = _selected_slot < 0


func _on_action_pressed() -> void:
	if _selected_slot < 0:
		return
	match _mode:
		Mode.SAVE:
			if _selected_is_autosave:
				return
			var metadata := SaveManagerScript.get_slot_metadata(_selected_slot)
			if metadata.is_empty():
				_commit_save(_selected_slot)
			else:
				confirm_dialog.dialog_text = "Overwrite save in slot %02d?" % _selected_slot
				confirm_dialog.popup_centered()
		Mode.LOAD:
			if _selected_is_autosave:
				if GameState.load_autosave():
					load_completed.emit()
			elif GameState.load_from_slot(_selected_slot):
				load_completed.emit()


func _on_confirm_overwrite() -> void:
	_commit_save(_selected_slot)


func _commit_save(slot: int) -> void:
	if GameState.save_to_slot(slot, _save_position, _save_rotation_y):
		save_completed.emit(slot)
		visible = false
		closed.emit()


func save_at_player(player_position: Vector3, player_rotation_y: float, slot: int) -> bool:
	return GameState.save_to_slot(slot, player_position, player_rotation_y)


func _on_back_pressed() -> void:
	visible = false
	closed.emit()
