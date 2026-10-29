extends Node


func _ready() -> void:
	if NarrativeDirector == null:
		return
	NarrativeDirector.cutscene_ended.connect(_on_cutscene_ended)
	NarrativeDirector.dialog_ended.connect(_on_dialog_ended)


func _on_cutscene_ended(cutscene_id: String, _completed: bool) -> void:
	if cutscene_id == "mira_dawn":
		NarrativeDirector.set_flag("intro_dawn_seen", true)
	elif cutscene_id == "mira_finds_empty_spot":
		NarrativeDirector.set_flag("intro_empty_spot_seen", true)


func _on_dialog_ended(dialog_id: String, choice_id: String) -> void:
	if dialog_id == "neighbor_testimony":
		NarrativeDirector.set_flag("intro_testimony_seen", true)
		await get_tree().create_timer(0.2).timeout
		if NarrativeDirector.is_active():
			return
		if not NarrativeDirector.get_flag("intro_complete"):
			NarrativeDirector.play_cutscene("mira_to_woods", null)
