class_name Ps1SurvivorModel
extends "res://scripts/assets/ps1_block_model.gd"

const SKIN: Color = Color(0.72, 0.58, 0.46)
const HAIR_DARK: Color = Color(0.12, 0.1, 0.09)
const HAIR_AUBURN: Color = Color(0.28, 0.16, 0.12)
const HAIR_BLOND: Color = Color(0.36, 0.3, 0.18)
const COAT_BLACK: Color = Color(0.14, 0.12, 0.11)
const COAT_BROWN: Color = Color(0.24, 0.18, 0.13)
const COAT_OLIVE: Color = Color(0.22, 0.24, 0.16)
const COAT_PURPLE: Color = Color(0.18, 0.12, 0.22)
const CLOAK_GRAY: Color = Color(0.28, 0.3, 0.28)
const PANTS_DARK: Color = Color(0.16, 0.15, 0.14)
const BOOT_BLACK: Color = Color(0.08, 0.07, 0.07)
const ACCENT_RED: Color = Color(0.42, 0.14, 0.12)
const ACCENT_GOLD: Color = Color(0.48, 0.38, 0.18)
const BOOK_LEATHER: Color = Color(0.2, 0.1, 0.08)


static func create(character_id: String) -> Node3D:
	var model: Node3D = (load("res://scripts/assets/ps1_survivor_model.gd") as GDScript).new()
	model.name = "SurvivorModel"
	model.build(character_id)
	return model


func build(character_id: String) -> void:
	build_from_parts(_get_parts(character_id))


static func _get_parts(character_id: String) -> Array[Dictionary]:
	match character_id:
		"ally_2":
			return _parts_mira()
		"ally_3":
			return _parts_owen()
		"ally_4":
			return _parts_elara()
		_:
			return _parts_bran()


static func _parts_bran() -> Array[Dictionary]:
	return [
		_box("BootL", Vector3(0.14, 0.12, 0.22), Vector3(-0.1, -0.54, 0.02), BOOT_BLACK),
		_box("BootR", Vector3(0.14, 0.12, 0.22), Vector3(0.1, -0.54, 0.02), BOOT_BLACK),
		_box("LegL", Vector3(0.16, 0.34, 0.16), Vector3(-0.1, -0.28, 0.0), PANTS_DARK),
		_box("LegR", Vector3(0.16, 0.34, 0.16), Vector3(0.1, -0.28, 0.0), PANTS_DARK),
		_box("Torso", Vector3(0.38, 0.36, 0.2), Vector3(0.0, 0.02, 0.0), COAT_BROWN),
		_box("CoatFlap", Vector3(0.34, 0.22, 0.08), Vector3(0.0, -0.08, 0.1), COAT_BLACK),
		_box("ArmL", Vector3(0.12, 0.3, 0.12), Vector3(-0.24, 0.02, 0.0), COAT_BROWN),
		_box("ArmR", Vector3(0.12, 0.3, 0.12), Vector3(0.24, 0.02, 0.0), COAT_BROWN),
		_box("HandL", Vector3(0.1, 0.1, 0.1), Vector3(-0.24, -0.18, 0.0), SKIN),
		_box("HandR", Vector3(0.1, 0.1, 0.1), Vector3(0.24, -0.18, 0.0), SKIN),
		_box("Head", Vector3(0.22, 0.24, 0.22), Vector3(0.0, 0.34, 0.0), SKIN),
		_box("Hair", Vector3(0.24, 0.12, 0.24), Vector3(0.0, 0.46, -0.02), HAIR_DARK),
		_box("Brow", Vector3(0.18, 0.04, 0.06), Vector3(0.0, 0.42, 0.1), HAIR_DARK),
	]


static func _parts_mira() -> Array[Dictionary]:
	return [
		_box("BootL", Vector3(0.12, 0.1, 0.2), Vector3(-0.08, -0.52, 0.02), BOOT_BLACK),
		_box("BootR", Vector3(0.12, 0.1, 0.2), Vector3(0.08, -0.52, 0.02), BOOT_BLACK),
		_box("LegL", Vector3(0.14, 0.32, 0.14), Vector3(-0.08, -0.28, 0.0), PANTS_DARK),
		_box("LegR", Vector3(0.14, 0.32, 0.14), Vector3(0.08, -0.28, 0.0), PANTS_DARK),
		_box("Torso", Vector3(0.28, 0.32, 0.16), Vector3(0.0, 0.02, 0.0), CLOAK_GRAY),
		_box("Scarf", Vector3(0.12, 0.16, 0.08), Vector3(0.0, 0.16, 0.1), ACCENT_RED),
		_box("ArmL", Vector3(0.1, 0.28, 0.1), Vector3(-0.2, 0.02, 0.0), CLOAK_GRAY),
		_box("ArmR", Vector3(0.1, 0.28, 0.1), Vector3(0.2, 0.02, 0.0), CLOAK_GRAY),
		_box("Head", Vector3(0.2, 0.22, 0.2), Vector3(0.0, 0.32, 0.0), SKIN),
		_box("HoodBack", Vector3(0.26, 0.28, 0.12), Vector3(0.0, 0.34, -0.08), CLOAK_GRAY),
		_box("HoodTop", Vector3(0.24, 0.08, 0.2), Vector3(0.0, 0.46, 0.02), CLOAK_GRAY),
		_box("Hair", Vector3(0.16, 0.1, 0.14), Vector3(0.0, 0.34, -0.04), HAIR_AUBURN),
	]


static func _parts_owen() -> Array[Dictionary]:
	return [
		_box("BootL", Vector3(0.14, 0.12, 0.22), Vector3(-0.1, -0.54, 0.02), BOOT_BLACK),
		_box("BootR", Vector3(0.14, 0.12, 0.22), Vector3(0.1, -0.54, 0.02), BOOT_BLACK),
		_box("LegL", Vector3(0.16, 0.34, 0.16), Vector3(-0.1, -0.28, 0.0), PANTS_DARK),
		_box("LegR", Vector3(0.16, 0.34, 0.16), Vector3(0.1, -0.28, 0.0), PANTS_DARK),
		_box("Torso", Vector3(0.32, 0.34, 0.18), Vector3(0.0, 0.02, 0.0), COAT_OLIVE),
		_box("Vest", Vector3(0.24, 0.24, 0.1), Vector3(0.0, 0.04, 0.08), COAT_BROWN),
		_box("ArmL", Vector3(0.12, 0.28, 0.12), Vector3(-0.22, 0.02, 0.0), COAT_OLIVE),
		_box("ArmR", Vector3(0.12, 0.28, 0.12), Vector3(0.22, 0.02, 0.0), COAT_OLIVE),
		_box("Satchel", Vector3(0.14, 0.18, 0.1), Vector3(0.18, -0.02, 0.08), COAT_BROWN),
		_box("Head", Vector3(0.22, 0.22, 0.22), Vector3(0.0, 0.34, 0.0), SKIN),
		_box("Cap", Vector3(0.24, 0.08, 0.24), Vector3(0.0, 0.46, 0.0), COAT_BROWN),
		_box("CapBrim", Vector3(0.26, 0.04, 0.14), Vector3(0.0, 0.42, 0.1), COAT_BROWN),
		_box("HairSide", Vector3(0.06, 0.12, 0.16), Vector3(0.1, 0.34, -0.02), HAIR_BLOND),
	]


static func _parts_elara() -> Array[Dictionary]:
	return [
		_box("BootL", Vector3(0.12, 0.1, 0.2), Vector3(-0.08, -0.52, 0.02), BOOT_BLACK),
		_box("BootR", Vector3(0.12, 0.1, 0.2), Vector3(0.08, -0.52, 0.02), BOOT_BLACK),
		_box("Skirt", Vector3(0.3, 0.28, 0.18), Vector3(0.0, -0.16, 0.0), COAT_PURPLE),
		_box("Torso", Vector3(0.26, 0.28, 0.16), Vector3(0.0, 0.12, 0.0), COAT_PURPLE),
		_box("RobeTrim", Vector3(0.32, 0.06, 0.2), Vector3(0.0, -0.02, 0.0), ACCENT_GOLD),
		_box("ArmL", Vector3(0.1, 0.26, 0.1), Vector3(-0.18, 0.1, 0.0), COAT_PURPLE),
		_box("ArmR", Vector3(0.1, 0.26, 0.1), Vector3(0.18, 0.1, 0.0), COAT_PURPLE),
		_box("Book", Vector3(0.08, 0.14, 0.12), Vector3(0.18, 0.02, 0.06), BOOK_LEATHER),
		_box("Head", Vector3(0.2, 0.22, 0.2), Vector3(0.0, 0.34, 0.0), SKIN),
		_box("Hood", Vector3(0.24, 0.18, 0.22), Vector3(0.0, 0.4, -0.02), COAT_BLACK),
		_box("HoodPeak", Vector3(0.08, 0.16, 0.08), Vector3(0.0, 0.5, 0.08), COAT_BLACK),
		_box("Hair", Vector3(0.14, 0.16, 0.12), Vector3(0.0, 0.32, -0.06), HAIR_DARK),
	]
