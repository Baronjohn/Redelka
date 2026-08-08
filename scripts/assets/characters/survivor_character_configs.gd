class_name SurvivorCharacterConfigs
extends RefCounted

## Per-character body/wardrobe parameters derived from data/characters.json:
## Bran  — bulky 40s prison guard: brown coat, fur collar, iron sword.
## Mira  — slim late-teen orphan: gray hooded cloak, red scarf, rusty dagger, auburn hair.
## Owen  — wiry 30s hunter: olive coat, brown vest, brimmed cap, satchel, short bow, blond.
## Elara — slight mid-20s mage: purple robe with gold trim, black peaked hood, staff, book.


static func get_config(character_id: String) -> Dictionary:
	match character_id:
		"ally_2":
			return _config_mira()
		"ally_3":
			return _config_owen()
		"ally_4":
			return _config_elara()
		_:
			return _config_bran()


static func _config_bran() -> Dictionary:
	return {
		"attack_style": "melee",
		"scale": Vector3(1.07, 1.07, 1.07),
		"walk_swing": 0.9,
		"body": {
			"shoulder_x": 0.195,
			"width": 1.12,
			"depth": 1.12,
			"girth": 1.15,
			"hip_width": 1.05,
		},
		"features": ["belt", "coat_skirt", "fur_collar", "sword"],
		"colors": {
			"skin": Color("c7a17c"),
			"hair": Color("2e2620"),
			"torso": Color("5b4531"),
			"sleeves": Color("55402d"),
			"pants": Color("35312b"),
			"boots": Color("1c1815"),
			"coat": Color("4e3a2a"),
			"fur": Color("262019"),
			"belt": Color("27201a"),
			"buckle": Color("7d6738"),
			"metal": Color("9096a0"),
			"grip": Color("241f1a"),
		},
	}


static func _config_mira() -> Dictionary:
	return {
		"attack_style": "dagger",
		"scale": Vector3(0.93, 0.94, 0.93),
		"walk_swing": 1.1,
		"body": {
			"shoulder_x": 0.165,
			"width": 0.92,
			"depth": 0.9,
			"girth": 0.82,
			"hip_width": 0.98,
		},
		"features": ["cape", "hood", "scarf", "dagger"],
		"colors": {
			"skin": Color("d4b291"),
			"hair": Color("8a5230"),
			"torso": Color("4e514c"),
			"sleeves": Color("5e615c"),
			"pants": Color("3a3d40"),
			"boots": Color("232227"),
			"cape": Color("676b66"),
			"hood": Color("676b66"),
			"scarf": Color("a03328"),
			"metal": Color("8a6a52"),
			"grip": Color("3a3028"),
		},
	}


static func _config_owen() -> Dictionary:
	return {
		"attack_style": "bow",
		"scale": Vector3(1.0, 1.01, 1.0),
		"walk_swing": 1.0,
		"body": {
			"shoulder_x": 0.185,
			"width": 0.98,
			"depth": 0.95,
			"girth": 0.92,
			"hip_width": 1.0,
		},
		"features": ["vest", "belt", "cap", "satchel", "bow"],
		"colors": {
			"skin": Color("c2a37e"),
			"hair": Color("a8955e"),
			"torso": Color("596144"),
			"sleeves": Color("596144"),
			"pants": Color("46412f"),
			"boots": Color("2b241c"),
			"vest": Color("6b4e31"),
			"cap": Color("5d4830"),
			"satchel": Color("45321f"),
			"belt": Color("2a2118"),
			"buckle": Color("6d5a30"),
			"wood": Color("7c5e3a"),
			"string": Color("cfc9b8"),
		},
	}


static func _config_elara() -> Dictionary:
	return {
		"attack_style": "staff",
		"scale": Vector3(0.95, 0.97, 0.95),
		"walk_swing": 0.5,
		"body": {
			"shoulder_x": 0.16,
			"width": 0.9,
			"depth": 0.88,
			"girth": 0.8,
			"hip_width": 0.96,
		},
		"features": ["robe", "hood", "peak", "sash", "staff", "book"],
		"colors": {
			"skin": Color("d8bb9f"),
			"hair": Color("262029"),
			"torso": Color("4c3166"),
			"sleeves": Color("462d5e"),
			"pants": Color("2c2440"),
			"boots": Color("1f1b2e"),
			"robe": Color("4c3166"),
			"hood": Color("1e1a24"),
			"trim": Color("b3903f"),
			"wood": Color("6f5637"),
			"orb": Color("8d6fc0"),
			"book": Color("4a2a1e"),
		},
	}
