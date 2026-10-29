class_name ExploreExaminable
extends Area3D

## Press-E point of interest under an area's `Interactables` node. Shows internal
## lines, or starts a dialog / cutscene, optionally gated on story flags.
## After a one-shot dialog or cutscene has fired, `lines` (if any) play on repeat visits.

@export var label: String = "it"
@export var prompt_verb: String = "examine"
@export var speaker: String = "internal"
@export var lines: PackedStringArray = PackedStringArray()
@export var dialog_id: String = ""
@export var cutscene_id: String = ""
## Only interactable once this flag is set.
@export var story_flag_required: String = ""
## No longer interactable once this flag is set.
@export var hide_when_flag: String = ""
## Set when the dialog or cutscene fires; also marks it as already seen on later visits.
@export var story_flag_set: String = ""
@export var radius: float = 1.3

var _player_inside: bool = false
var _fired: bool = false


func _ready() -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("explore_player"):
		_player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("explore_player"):
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not can_interact():
		return
	if event.is_action_pressed("interact"):
		if interact():
			get_viewport().set_input_as_handled()


func can_interact() -> bool:
	if not _player_inside or GameState.busy_narrative:
		return false
	if not story_flag_required.is_empty() and not NarrativeDirector.get_flag(story_flag_required):
		return false
	if not hide_when_flag.is_empty() and NarrativeDirector.get_flag(hide_when_flag):
		return false
	return _has_event() or not lines.is_empty()


func get_interact_prompt() -> String:
	return "Press E or click to %s %s" % [prompt_verb, label]


func interact() -> bool:
	if not can_interact():
		return false
	if _has_event():
		_fired = true
		if not story_flag_set.is_empty():
			NarrativeDirector.set_flag(story_flag_set, true)
		if not cutscene_id.is_empty():
			NarrativeDirector.play_cutscene(cutscene_id, self)
		else:
			NarrativeDirector.play_dialog(dialog_id, get_tree().current_scene)
		return true
	var dialog_lines: Array = []
	for text: String in lines:
		dialog_lines.append({"speaker": speaker, "text": text})
	NarrativeDirector.play_dialog_data("examine_%s" % name.to_snake_case(), {"lines": dialog_lines}, self)
	return true


func _has_event() -> bool:
	if cutscene_id.is_empty() and dialog_id.is_empty():
		return false
	if _fired:
		return false
	return story_flag_set.is_empty() or not NarrativeDirector.get_flag(story_flag_set)
