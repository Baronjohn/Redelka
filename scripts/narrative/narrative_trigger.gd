class_name NarrativeTrigger
extends Area3D

@export var trigger_id: String = ""
@export var cutscene_id: String = ""
@export var dialog_id: String = ""
@export var story_flag_required: String = ""
@export var story_flag_set: String = ""
@export var one_shot: bool = true
@export var require_story_flag_value: bool = true
@export var auto_disable: bool = true
@export var trigger_radius: float = 0.0

signal triggered(payload: Dictionary)

var _has_fired: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("narrative_triggers")
	if trigger_radius > 0.0:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = trigger_radius
		shape.shape = sphere
		add_child(shape)


func try_fire() -> bool:
	if _has_fired and one_shot:
		return false
	if not story_flag_required.is_empty():
		if NarrativeDirector.get_flag(story_flag_required) != require_story_flag_value:
			return false
	_has_fired = true
	if auto_disable:
		monitoring = false
		monitorable = false
	var payload := {
		"trigger_id": trigger_id,
		"cutscene_id": cutscene_id,
		"dialog_id": dialog_id,
	}
	if not story_flag_set.is_empty():
		NarrativeDirector.set_flag(story_flag_set, true)
	triggered.emit(payload)
	if not cutscene_id.is_empty():
		NarrativeDirector.play_cutscene(cutscene_id, self)
	elif not dialog_id.is_empty():
		var ctx := get_tree().current_scene
		NarrativeDirector.play_dialog(dialog_id, ctx)
	return true
