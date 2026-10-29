extends SceneTree

const BattleMaterialsScript = preload("res://scripts/assets/battle_materials.gd")


func _initialize() -> void:
	BattleMaterialsScript.export_texture_assets()
	quit()
