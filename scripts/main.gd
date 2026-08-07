extends Node2D


func _ready() -> void:
	GameState.ensure_party_initialized(GameState.DEFAULT_ENCOUNTER_ID)
	SceneTransition.go_to_explore()
