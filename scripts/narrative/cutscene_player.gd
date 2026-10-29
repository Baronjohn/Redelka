class_name CutscenePlayer
extends Node

signal cutscene_requested(cutscene_id: String)
signal dialog_completed(choice_id: String)
signal cutscene_finished(cutscene_id: String)

@export var cutscene_id: String = ""
@export var auto_play: bool = false
@export var consume_dialogs: bool = true

var _current_cutscene_id: String = ""
var _is_playing: bool = false
var _last_choice_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if auto_play:
		call_deferred("play")


func play(cutscene_id_override: String = "") -> void:
	if _is_playing:
		return
	var id := cutscene_id_override if not cutscene_id_override.is_empty() else cutscene_id
	if id.is_empty():
		push_error("CutscenePlayer: cutscene_id is empty")
		return
	_current_cutscene_id = id
	_is_playing = true
	_last_choice_id = ""
	cutscene_requested.emit(id)
	NarrativeDirector.play_cutscene(id, self)
	_wait_for_completion()


func _wait_for_completion() -> void:
	while _is_playing:
		await get_tree().process_frame
		if not NarrativeDirector.is_cutscene_running() and _is_playing:
			break
	_is_playing = false
	var ended_id := _current_cutscene_id
	_current_cutscene_id = ""
	cutscene_finished.emit(ended_id)


func _on_dialog_complete(choice_id: String) -> void:
	_last_choice_id = choice_id
	dialog_completed.emit(choice_id)


func get_last_choice_id() -> String:
	return _last_choice_id
