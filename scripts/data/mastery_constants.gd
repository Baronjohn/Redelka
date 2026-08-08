class_name MasteryConstants
extends RefCounted

const SPELL_MASTERY_TYPES: Array[String] = ["fire"]
const WEAPON_CLASSES: Array[String] = ["sword", "bow", "staff", "dagger"]
const WEAPON_MAX_LEVEL: int = 3
const WEAPON_XP_PER_LEVEL: int = 1000
const SPELL_MAX_TIER: int = 3
const SPELL_XP_TO_NEXT_TIER: Array[int] = [1000, 2000]
const MASTERY_XP_PER_USE: int = 40

const SPELL_POWER_MULTIPLIERS: Array[float] = [1.0, 1.25, 1.5]
const SPELL_MP_MULTIPLIERS: Array[float] = [1.0, 1.15, 1.3]


static func weapon_xp_to_next_level(current_level: int) -> int:
	if current_level >= WEAPON_MAX_LEVEL:
		return 0
	return WEAPON_XP_PER_LEVEL


static func spell_xp_to_next_tier(current_tier: int) -> int:
	if current_tier <= 0 or current_tier >= SPELL_MAX_TIER:
		return 0
	return SPELL_XP_TO_NEXT_TIER[current_tier - 1]


static func combo_proc_chance(stats: StatBlock) -> float:
	return clampf(
		float(stats.dex) + float(stats.luk),
		CombatConstants.HIT_FLOOR,
		CombatConstants.HIT_CEILING,
	)


static func resolve_combo_hit_count(mastery_level: int, stats: StatBlock) -> int:
	var hit_count := 1
	if mastery_level <= 1:
		return hit_count
	if roll_percent(combo_proc_chance(stats)):
		hit_count = 2
	if mastery_level >= 3 and hit_count >= 2 and roll_percent(combo_proc_chance(stats)):
		hit_count = 3
	return hit_count


static func get_spell_power_multiplier(tier: int) -> float:
	var index := clampi(tier - 1, 0, SPELL_POWER_MULTIPLIERS.size() - 1)
	return SPELL_POWER_MULTIPLIERS[index]


static func get_spell_mp_multiplier(tier: int) -> float:
	var index := clampi(tier - 1, 0, SPELL_MP_MULTIPLIERS.size() - 1)
	return SPELL_MP_MULTIPLIERS[index]


static func roll_percent(chance: float) -> bool:
	return randf() * 100.0 <= chance


static func get_spell_mastery_display_name(mastery_id: String) -> String:
	match mastery_id:
		"fire":
			return "Fire"
		_:
			return mastery_id.capitalize()
