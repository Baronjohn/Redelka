class_name ItemModelNode
extends Node3D

## Places an item's 3D model (ItemModels) in a scene, e.g. the wooden bird on the stump.

const ItemModelsScript = preload("res://scripts/assets/item_models.gd")

@export var item_id: String = ""


func _ready() -> void:
	if not item_id.is_empty():
		add_child(ItemModelsScript.build(item_id))
