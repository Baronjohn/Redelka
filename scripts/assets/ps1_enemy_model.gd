class_name Ps1EnemyModel
extends "res://scripts/assets/ps1_block_model.gd"

const PALE_FLESH: Color = Color(0.62, 0.58, 0.54)
const SICK_FLESH: Color = Color(0.52, 0.5, 0.46)
const ROT_FLESH: Color = Color(0.42, 0.34, 0.3)
const BONE: Color = Color(0.72, 0.68, 0.6)
const RAG_BROWN: Color = Color(0.24, 0.18, 0.14)
const RAG_RUST: Color = Color(0.34, 0.2, 0.14)
const SHADOW_BLACK: Color = Color(0.06, 0.05, 0.08)
const SHADOW_VIOLET: Color = Color(0.14, 0.1, 0.2)
const SHADOW_MIST: Color = Color(0.22, 0.18, 0.28)
const EYE_GLOW: Color = Color(0.36, 0.18, 0.48)
const ARMOR_PALE: Color = Color(0.58, 0.6, 0.62)
const ARMOR_RUST: Color = Color(0.34, 0.24, 0.18)
const ARMOR_DARK: Color = Color(0.18, 0.18, 0.2)


static func create(enemy_id: String) -> Node3D:
	var model: Node3D = (load("res://scripts/assets/ps1_enemy_model.gd") as GDScript).new()
	model.name = "EnemyModel"
	model.build(enemy_id)
	return model


func build(enemy_id: String) -> void:
	scale = Vector3.ONE
	build_from_parts(_get_parts(enemy_id))
	if enemy_id == "pale_warden":
		scale = Vector3(1.25, 1.25, 1.25)


static func _get_parts(enemy_id: String) -> Array[Dictionary]:
	match enemy_id:
		"enemy_2":
			return _parts_wretch()
		"enemy_3":
			return _parts_shade()
		"pale_warden":
			return _parts_pale_warden()
		_:
			return _parts_hollow()


static func _parts_hollow() -> Array[Dictionary]:
	return [
		_box("FootL", Vector3(0.12, 0.08, 0.18), Vector3(-0.08, -0.52, 0.02), BONE),
		_box("FootR", Vector3(0.12, 0.08, 0.18), Vector3(0.08, -0.52, 0.02), BONE),
		_box("ShinL", Vector3(0.1, 0.28, 0.1), Vector3(-0.08, -0.32, 0.0), PALE_FLESH),
		_box("ShinR", Vector3(0.1, 0.28, 0.1), Vector3(0.08, -0.32, 0.0), PALE_FLESH),
		_box("Torso", Vector3(0.24, 0.34, 0.14), Vector3(0.0, -0.02, 0.04), SICK_FLESH),
		_box("Spine", Vector3(0.08, 0.28, 0.08), Vector3(0.0, 0.02, -0.06), BONE),
		_box("ArmL", Vector3(0.08, 0.3, 0.08), Vector3(-0.16, 0.0, 0.04), PALE_FLESH),
		_box("ArmR", Vector3(0.08, 0.34, 0.08), Vector3(0.16, -0.02, 0.04), PALE_FLESH),
		_box("ClawL", Vector3(0.1, 0.06, 0.14), Vector3(-0.16, -0.2, 0.08), BONE),
		_box("ClawR", Vector3(0.1, 0.06, 0.14), Vector3(0.16, -0.22, 0.08), BONE),
		_box("Head", Vector3(0.18, 0.22, 0.18), Vector3(0.0, 0.24, 0.06), SICK_FLESH),
		_box("Jaw", Vector3(0.14, 0.08, 0.12), Vector3(0.0, 0.14, 0.1), BONE),
		_box("EyeL", Vector3(0.04, 0.04, 0.04), Vector3(-0.05, 0.28, 0.14), SHADOW_BLACK),
		_box("EyeR", Vector3(0.04, 0.04, 0.04), Vector3(0.05, 0.28, 0.14), SHADOW_BLACK),
	]


static func _parts_wretch() -> Array[Dictionary]:
	return [
		_box("FootL", Vector3(0.1, 0.08, 0.16), Vector3(-0.08, -0.46, 0.02), RAG_BROWN),
		_box("FootR", Vector3(0.1, 0.08, 0.16), Vector3(0.08, -0.46, 0.02), RAG_BROWN),
		_box("LegL", Vector3(0.12, 0.24, 0.12), Vector3(-0.08, -0.28, 0.0), RAG_RUST),
		_box("LegR", Vector3(0.12, 0.24, 0.12), Vector3(0.08, -0.28, 0.0), RAG_RUST),
		_box("Torso", Vector3(0.22, 0.24, 0.14), Vector3(0.0, -0.04, 0.02), RAG_BROWN),
		_box("Hunch", Vector3(0.18, 0.12, 0.16), Vector3(0.0, 0.08, -0.04), RAG_RUST),
		_box("ArmL", Vector3(0.08, 0.22, 0.08), Vector3(-0.14, -0.02, 0.02), ROT_FLESH),
		_box("ArmR", Vector3(0.08, 0.26, 0.08), Vector3(0.14, -0.04, 0.02), ROT_FLESH),
		_box("ClawL", Vector3(0.08, 0.06, 0.12), Vector3(-0.14, -0.16, 0.06), BONE),
		_box("ClawR", Vector3(0.08, 0.06, 0.12), Vector3(0.14, -0.18, 0.06), BONE),
		_box("Head", Vector3(0.16, 0.18, 0.16), Vector3(0.0, 0.16, 0.04), ROT_FLESH),
		_box("EarL", Vector3(0.04, 0.08, 0.04), Vector3(-0.1, 0.2, 0.0), ROT_FLESH),
		_box("EarR", Vector3(0.04, 0.08, 0.04), Vector3(0.1, 0.2, 0.0), ROT_FLESH),
		_box("Mane", Vector3(0.12, 0.08, 0.1), Vector3(0.0, 0.24, -0.02), RAG_RUST),
	]


static func _parts_shade() -> Array[Dictionary]:
	return [
		_box("MistBase", Vector3(0.34, 0.12, 0.24), Vector3(0.0, -0.48, 0.0), SHADOW_BLACK),
		_box("RobeCore", Vector3(0.24, 0.42, 0.16), Vector3(0.0, 0.0, 0.0), SHADOW_VIOLET),
		_box("RobeL", Vector3(0.1, 0.36, 0.08), Vector3(-0.14, -0.04, 0.0), SHADOW_BLACK),
		_box("RobeR", Vector3(0.1, 0.36, 0.08), Vector3(0.14, -0.04, 0.0), SHADOW_BLACK),
		_box("Cowl", Vector3(0.22, 0.16, 0.2), Vector3(0.0, 0.28, -0.02), SHADOW_MIST),
		_box("HoodPeak", Vector3(0.08, 0.14, 0.08), Vector3(0.0, 0.38, 0.04), SHADOW_BLACK),
		_box("Face", Vector3(0.12, 0.1, 0.08), Vector3(0.0, 0.24, 0.08), SHADOW_VIOLET),
		_box("EyeL", Vector3(0.04, 0.04, 0.02), Vector3(-0.04, 0.26, 0.12), EYE_GLOW),
		_box("EyeR", Vector3(0.04, 0.04, 0.02), Vector3(0.04, 0.26, 0.12), EYE_GLOW),
		_box("WispL", Vector3(0.08, 0.24, 0.06), Vector3(-0.18, 0.02, -0.04), SHADOW_MIST),
		_box("WispR", Vector3(0.08, 0.24, 0.06), Vector3(0.18, 0.02, -0.04), SHADOW_MIST),
	]


static func _parts_pale_warden() -> Array[Dictionary]:
	return [
		_box("BootL", Vector3(0.16, 0.14, 0.24), Vector3(-0.12, -0.54, 0.02), ARMOR_DARK),
		_box("BootR", Vector3(0.16, 0.14, 0.24), Vector3(0.12, -0.54, 0.02), ARMOR_DARK),
		_box("GreaveL", Vector3(0.14, 0.32, 0.14), Vector3(-0.12, -0.28, 0.0), ARMOR_PALE),
		_box("GreaveR", Vector3(0.14, 0.32, 0.14), Vector3(0.12, -0.28, 0.0), ARMOR_PALE),
		_box("Torso", Vector3(0.42, 0.4, 0.22), Vector3(0.0, 0.04, 0.0), ARMOR_PALE),
		_box("ChestRust", Vector3(0.18, 0.16, 0.04), Vector3(0.0, 0.08, 0.1), ARMOR_RUST),
		_box("ShoulderL", Vector3(0.16, 0.12, 0.18), Vector3(-0.28, 0.16, 0.0), ARMOR_PALE),
		_box("ShoulderR", Vector3(0.16, 0.12, 0.18), Vector3(0.28, 0.16, 0.0), ARMOR_PALE),
		_box("ArmL", Vector3(0.14, 0.32, 0.14), Vector3(-0.28, -0.02, 0.0), ARMOR_PALE),
		_box("ArmR", Vector3(0.14, 0.32, 0.14), Vector3(0.28, -0.02, 0.0), ARMOR_PALE),
		_box("GauntletL", Vector3(0.12, 0.12, 0.12), Vector3(-0.28, -0.22, 0.02), ARMOR_DARK),
		_box("GauntletR", Vector3(0.12, 0.12, 0.12), Vector3(0.28, -0.22, 0.02), ARMOR_DARK),
		_box("Helm", Vector3(0.24, 0.24, 0.24), Vector3(0.0, 0.36, 0.0), ARMOR_PALE),
		_box("Visor", Vector3(0.16, 0.04, 0.06), Vector3(0.0, 0.34, 0.12), ARMOR_DARK),
		_box("Plume", Vector3(0.06, 0.16, 0.06), Vector3(0.0, 0.5, -0.04), ARMOR_RUST),
		_box("Cape", Vector3(0.34, 0.3, 0.06), Vector3(0.0, 0.02, -0.12), ARMOR_DARK),
	]
