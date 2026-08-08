class_name SurvivorModelScene
extends "res://scripts/assets/ps1_survivor_model.gd"

@export var character_id: String = "ally_1"


func _ready() -> void:
	build(character_id)
