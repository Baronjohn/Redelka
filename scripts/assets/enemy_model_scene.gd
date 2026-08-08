class_name EnemyModelScene
extends "res://scripts/assets/ps1_enemy_model.gd"

@export var enemy_id: String = "enemy_1"


func _ready() -> void:
	build(enemy_id)
