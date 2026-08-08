class_name ProgressionConstants
extends RefCounted

static var LEVEL_CAP: int = 99
static var POINTS_PER_LEVEL: int = 4

static var _loaded: bool = false
static var _xp_formula: String = "level_times_base"
static var _xp_base: int = 100
static var _xp_lookup: Dictionary = {}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	var data := DataLoader.load_progression()
	LEVEL_CAP = int(data.get("level_cap", 99))
	POINTS_PER_LEVEL = int(data.get("points_per_level", 4))
	var curve: Dictionary = data.get("xp_curve", {}) as Dictionary
	_xp_formula = str(curve.get("formula", "level_times_base"))
	_xp_base = int(curve.get("base", 100))
	_xp_lookup = curve.get("lookup", {}) as Dictionary
	_loaded = true


static func xp_required_for_level(level: int) -> int:
	_ensure_loaded()
	var current_level := maxi(level, 1)
	match _xp_formula:
		"lookup":
			var key := str(current_level)
			if _xp_lookup.has(key):
				return int(_xp_lookup[key])
			push_error("Missing XP lookup for level %s in progression.json." % key)
			return current_level * _xp_base
		_:
			return current_level * _xp_base
