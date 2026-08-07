extends Node2D

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")


func _ready() -> void:
	get_tree().change_scene_to_packed(BATTLE_SCENE)
