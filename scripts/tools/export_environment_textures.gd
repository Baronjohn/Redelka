extends SceneTree

const EnvironmentMaterialsScript = preload("res://scripts/assets/environment_materials.gd")
const BattleMaterialsScript = preload("res://scripts/assets/battle_materials.gd")


func _initialize() -> void:
	EnvironmentMaterialsScript.export_texture_assets()
	BattleMaterialsScript.export_texture_assets()
	quit()
