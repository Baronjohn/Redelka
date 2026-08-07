class_name StatDescriptions
extends RefCounted

const DESCRIPTIONS: Dictionary = {
	"str": "Physical weapon damage.",
	"dex": "Physical hit chance; combo chance.",
	"vit": "HP and physical resistance.",
	"agi": "Turn order frequency; retreat.",
	"int": "Spell damage multiplier.",
	"mnd": "Spell hit chance.",
	"res": "MP pool and spell resistance.",
	"luk": "Hit, crit, retreat, combo, drops.",
}


static func get_description(stat_name: String) -> String:
	return str(DESCRIPTIONS.get(stat_name, ""))
