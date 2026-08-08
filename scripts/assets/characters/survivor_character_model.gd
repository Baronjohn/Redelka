class_name SurvivorCharacterModel
extends "res://scripts/assets/characters/character_rig.gd"


static func create(character_id: String) -> Node3D:
	var model: Node3D = (load("res://scripts/assets/characters/survivor_character_model.gd") as GDScript).new()
	model.name = "SurvivorModel"
	model.build(character_id)
	return model
