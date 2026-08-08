class_name Ps1SurvivorModel
extends "res://scripts/assets/ps1_block_model.gd"

const SKIN: Color = Color(0.72, 0.58, 0.46)
const SKIN_SHADOW: Color = Color(0.58, 0.46, 0.36)
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
const FUR_DARK: Color = Color(0.1, 0.08, 0.07)
const ACCENT_RED: Color = Color(0.42, 0.14, 0.12)
const ACCENT_GOLD: Color = Color(0.48, 0.38, 0.18)
const BOOK_LEATHER: Color = Color(0.2, 0.1, 0.08)
const METAL_DARK: Color = Color(0.22, 0.2, 0.18)
const METAL_RUST: Color = Color(0.34, 0.22, 0.16)
const WOOD_DARK: Color = Color(0.18, 0.12, 0.08)
const WOOD_BOW: Color = Color(0.26, 0.2, 0.12)


static func create(character_id: String) -> Node3D:
	var model: Node3D = (load("res://scripts/assets/ps1_survivor_model.gd") as GDScript).new()
	model.name = "SurvivorModel"
	model.build(character_id)
	return model


func build(character_id: String) -> void:
	attack_style = _get_attack_style(character_id)
	build_from_parts(_get_parts(character_id))


static func _get_attack_style(character_id: String) -> String:
	match character_id:
		"ally_2":
			return "dagger"
		"ally_3":
			return "bow"
		"ally_4":
			return "staff"
		_:
			return "melee"


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
		_box("BootL", Vector3(0.16, 0.12, 0.24), Vector3(-0.11, -0.54, 0.02), BOOT_BLACK),
		_box("BootR", Vector3(0.16, 0.12, 0.24), Vector3(0.11, -0.54, 0.02), BOOT_BLACK),
		_box("LegL", Vector3(0.18, 0.36, 0.18), Vector3(-0.11, -0.28, 0.0), PANTS_DARK),
		_box("LegR", Vector3(0.18, 0.36, 0.18), Vector3(0.11, -0.28, 0.0), PANTS_DARK),
		_box("Belt", Vector3(0.34, 0.08, 0.16), Vector3(0.0, -0.02, 0.08), COAT_BLACK),
		_box("Torso", Vector3(0.42, 0.4, 0.22), Vector3(0.0, 0.04, 0.0), COAT_BROWN),
		_box("CoatFlap", Vector3(0.36, 0.24, 0.1), Vector3(0.0, -0.06, 0.11), COAT_BLACK),
		_box("FurCollar", Vector3(0.3, 0.1, 0.18), Vector3(0.0, 0.18, 0.04), FUR_DARK),
		_box("ShoulderL", Vector3(0.14, 0.12, 0.18), Vector3(-0.24, 0.16, 0.0), COAT_BROWN),
		_box("ShoulderR", Vector3(0.14, 0.12, 0.18), Vector3(0.24, 0.16, 0.0), COAT_BROWN),
		_box("ArmL", Vector3(0.14, 0.32, 0.14), Vector3(-0.28, 0.04, 0.0), COAT_BROWN),
		_box("ArmR", Vector3(0.14, 0.32, 0.14), Vector3(0.28, 0.04, 0.0), COAT_BROWN),
		_box("HandL", Vector3(0.1, 0.1, 0.1), Vector3(-0.28, -0.18, 0.0), SKIN),
		_box("HandR", Vector3(0.1, 0.1, 0.1), Vector3(0.28, -0.18, 0.0), SKIN),
		_box("Head", Vector3(0.24, 0.26, 0.24), Vector3(0.0, 0.36, 0.0), SKIN),
		_box("Brow", Vector3(0.18, 0.04, 0.06), Vector3(0.0, 0.44, 0.11), HAIR_DARK),
		_box("Jaw", Vector3(0.16, 0.08, 0.12), Vector3(0.0, 0.28, 0.1), SKIN_SHADOW),
		_box("Hair", Vector3(0.26, 0.14, 0.26), Vector3(0.0, 0.48, -0.02), HAIR_DARK),
		_box("SwordHilt", Vector3(0.08, 0.1, 0.08), Vector3(0.22, 0.0, 0.1), METAL_DARK),
		_box("SwordGuard", Vector3(0.14, 0.04, 0.06), Vector3(0.22, 0.06, 0.1), METAL_DARK),
		_box("SwordBlade", Vector3(0.06, 0.34, 0.04), Vector3(0.22, -0.12, 0.1), METAL_DARK),
		_box("Weapon", Vector3(0.08, 0.38, 0.06), Vector3(0.22, -0.04, 0.1), METAL_DARK),
	]


static func _parts_mira() -> Array[Dictionary]:
	return [
		_box("BootL", Vector3(0.12, 0.1, 0.2), Vector3(-0.08, -0.52, 0.02), BOOT_BLACK),
		_box("BootR", Vector3(0.12, 0.1, 0.2), Vector3(0.08, -0.52, 0.02), BOOT_BLACK),
		_box("LegL", Vector3(0.14, 0.32, 0.14), Vector3(-0.08, -0.28, 0.0), PANTS_DARK),
		_box("LegR", Vector3(0.14, 0.32, 0.14), Vector3(0.08, -0.28, 0.0), PANTS_DARK),
		_box("Torso", Vector3(0.28, 0.32, 0.16), Vector3(0.0, 0.02, 0.0), CLOAK_GRAY),
		_box("CloakL", Vector3(0.1, 0.34, 0.08), Vector3(-0.16, -0.02, 0.02), CLOAK_GRAY),
		_box("CloakR", Vector3(0.1, 0.34, 0.08), Vector3(0.16, -0.02, 0.02), CLOAK_GRAY),
		_box("Scarf", Vector3(0.14, 0.18, 0.1), Vector3(0.0, 0.16, 0.11), ACCENT_RED),
		_box("ScarfTail", Vector3(0.08, 0.14, 0.06), Vector3(0.06, 0.08, 0.12), ACCENT_RED),
		_box("ArmL", Vector3(0.1, 0.28, 0.1), Vector3(-0.2, 0.02, 0.0), CLOAK_GRAY),
		_box("ArmR", Vector3(0.1, 0.28, 0.1), Vector3(0.2, 0.02, 0.0), CLOAK_GRAY),
		_box("HandL", Vector3(0.08, 0.08, 0.08), Vector3(-0.2, -0.16, 0.0), SKIN),
		_box("HandR", Vector3(0.08, 0.08, 0.08), Vector3(0.2, -0.16, 0.0), SKIN),
		_box("Head", Vector3(0.2, 0.22, 0.2), Vector3(0.0, 0.32, 0.0), SKIN),
		_box("HoodBack", Vector3(0.28, 0.3, 0.14), Vector3(0.0, 0.34, -0.1), CLOAK_GRAY),
		_box("HoodTop", Vector3(0.26, 0.1, 0.22), Vector3(0.0, 0.46, 0.02), CLOAK_GRAY),
		_box("HoodFrameL", Vector3(0.04, 0.16, 0.08), Vector3(-0.1, 0.34, 0.06), CLOAK_GRAY),
		_box("HoodFrameR", Vector3(0.04, 0.16, 0.08), Vector3(0.1, 0.34, 0.06), CLOAK_GRAY),
		_box("Hair", Vector3(0.16, 0.1, 0.14), Vector3(0.0, 0.34, -0.04), HAIR_AUBURN),
		_box("DaggerHilt", Vector3(0.06, 0.06, 0.06), Vector3(0.22, -0.1, 0.08), METAL_RUST),
		_box("DaggerBlade", Vector3(0.04, 0.16, 0.04), Vector3(0.22, -0.2, 0.08), METAL_RUST),
		_box("Weapon", Vector3(0.06, 0.2, 0.05), Vector3(0.22, -0.16, 0.08), METAL_RUST),
	]


static func _parts_owen() -> Array[Dictionary]:
	return [
		_box("BootL", Vector3(0.14, 0.12, 0.22), Vector3(-0.1, -0.54, 0.02), BOOT_BLACK),
		_box("BootR", Vector3(0.14, 0.12, 0.22), Vector3(0.1, -0.54, 0.02), BOOT_BLACK),
		_box("LegL", Vector3(0.16, 0.34, 0.16), Vector3(-0.1, -0.28, 0.0), PANTS_DARK),
		_box("LegR", Vector3(0.16, 0.34, 0.16), Vector3(0.1, -0.28, 0.0), PANTS_DARK),
		_box("Torso", Vector3(0.32, 0.34, 0.18), Vector3(0.0, 0.02, 0.0), COAT_OLIVE),
		_box("Vest", Vector3(0.26, 0.26, 0.12), Vector3(0.0, 0.04, 0.09), COAT_BROWN),
		_box("VestPanel", Vector3(0.16, 0.18, 0.04), Vector3(0.0, 0.06, 0.12), COAT_BROWN),
		_box("ArmL", Vector3(0.12, 0.28, 0.12), Vector3(-0.22, 0.02, 0.0), COAT_OLIVE),
		_box("ArmR", Vector3(0.12, 0.28, 0.12), Vector3(0.22, 0.02, 0.0), COAT_OLIVE),
		_box("HandL", Vector3(0.08, 0.08, 0.08), Vector3(-0.22, -0.16, 0.0), SKIN),
		_box("HandR", Vector3(0.08, 0.08, 0.08), Vector3(0.22, -0.16, 0.0), SKIN),
		_box("Satchel", Vector3(0.16, 0.2, 0.12), Vector3(0.18, -0.02, 0.08), COAT_BROWN),
		_box("SatchelStrap", Vector3(0.06, 0.34, 0.04), Vector3(0.1, 0.04, 0.1), COAT_BROWN),
		_box("Quiver", Vector3(0.1, 0.24, 0.08), Vector3(-0.14, 0.02, -0.06), COAT_BROWN),
		_box("Head", Vector3(0.22, 0.22, 0.22), Vector3(0.0, 0.34, 0.0), SKIN),
		_box("Cap", Vector3(0.26, 0.08, 0.26), Vector3(0.0, 0.46, 0.0), COAT_BROWN),
		_box("CapBrim", Vector3(0.28, 0.04, 0.16), Vector3(0.0, 0.42, 0.11), COAT_BROWN),
		_box("HairSideL", Vector3(0.05, 0.12, 0.14), Vector3(-0.1, 0.34, -0.02), HAIR_BLOND),
		_box("HairSideR", Vector3(0.05, 0.12, 0.14), Vector3(0.1, 0.34, -0.02), HAIR_BLOND),
		_box("Bow", Vector3(0.04, 0.42, 0.06), Vector3(-0.08, 0.02, -0.04), WOOD_BOW),
		_box("BowGrip", Vector3(0.06, 0.08, 0.08), Vector3(-0.08, 0.02, -0.04), COAT_BROWN),
		_box("BowString", Vector3(0.02, 0.36, 0.02), Vector3(-0.06, 0.02, -0.04), Color(0.72, 0.68, 0.58)),
	]


static func _parts_elara() -> Array[Dictionary]:
	return [
		_box("BootL", Vector3(0.12, 0.1, 0.2), Vector3(-0.08, -0.52, 0.02), BOOT_BLACK),
		_box("BootR", Vector3(0.12, 0.1, 0.2), Vector3(0.08, -0.52, 0.02), BOOT_BLACK),
		_box("Skirt", Vector3(0.32, 0.3, 0.2), Vector3(0.0, -0.16, 0.0), COAT_PURPLE),
		_box("Torso", Vector3(0.28, 0.3, 0.18), Vector3(0.0, 0.12, 0.0), COAT_PURPLE),
		_box("RobeTrim", Vector3(0.34, 0.06, 0.22), Vector3(0.0, -0.02, 0.0), ACCENT_GOLD),
		_box("RobeTrimTop", Vector3(0.3, 0.04, 0.2), Vector3(0.0, 0.2, 0.0), ACCENT_GOLD),
		_box("ArmL", Vector3(0.1, 0.26, 0.1), Vector3(-0.18, 0.1, 0.0), COAT_PURPLE),
		_box("ArmR", Vector3(0.1, 0.26, 0.1), Vector3(0.18, 0.1, 0.0), COAT_PURPLE),
		_box("HandL", Vector3(0.08, 0.08, 0.08), Vector3(-0.18, -0.04, 0.0), SKIN),
		_box("HandR", Vector3(0.08, 0.08, 0.08), Vector3(0.18, -0.04, 0.0), SKIN),
		_box("Book", Vector3(0.1, 0.16, 0.14), Vector3(0.18, 0.02, 0.06), BOOK_LEATHER),
		_box("BookClasp", Vector3(0.04, 0.08, 0.04), Vector3(0.18, 0.02, 0.12), ACCENT_GOLD),
		_box("Staff", Vector3(0.06, 0.52, 0.06), Vector3(-0.12, -0.02, 0.0), WOOD_DARK),
		_box("StaffTop", Vector3(0.08, 0.08, 0.08), Vector3(-0.12, 0.24, 0.0), ACCENT_GOLD),
		_box("Head", Vector3(0.2, 0.22, 0.2), Vector3(0.0, 0.34, 0.0), SKIN),
		_box("Hood", Vector3(0.26, 0.2, 0.24), Vector3(0.0, 0.4, -0.02), COAT_BLACK),
		_box("HoodPeak", Vector3(0.1, 0.18, 0.1), Vector3(0.0, 0.52, 0.1), COAT_BLACK),
		_box("Hair", Vector3(0.14, 0.16, 0.12), Vector3(0.0, 0.32, -0.06), HAIR_DARK),
	]
