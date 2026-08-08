class_name SurvivorModelScene
extends "res://scripts/assets/characters/character_rig.gd"

@export var character_id: String = "ally_1"


func _ready() -> void:
	build(character_id)
