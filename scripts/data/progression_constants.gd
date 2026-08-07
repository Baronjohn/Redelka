class_name ProgressionConstants
extends RefCounted

const LEVEL_CAP: int = 99
const POINTS_PER_LEVEL: int = 4


static func xp_required_for_level(level: int) -> int:
	return maxi(level, 1) * 100
