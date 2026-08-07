class_name PartyMemberSnapshot
extends RefCounted

var character_id: String = ""
var level: int = 1
var xp: int = 0
var unspent_stat_points: int = 0
var allocated_stats: StatBlock = StatBlock.new()
var current_hp: int = 0
var max_hp: int = 0
var current_mp: int = 0
var max_mp: int = 0
var is_ko: bool = false
var pending_spell_id: String = ""
var pending_spell_target_id: String = ""


static func from_dict(data: Dictionary) -> PartyMemberSnapshot:
	var snapshot := new()
	snapshot.character_id = str(data.get("character_id", ""))
	snapshot.level = int(data.get("level", 1))
	snapshot.xp = int(data.get("xp", 0))
	snapshot.unspent_stat_points = int(data.get("unspent_stat_points", 0))
	snapshot.allocated_stats = StatBlock.from_dict(data.get("allocated_stats", {}) as Dictionary)
	snapshot.current_hp = int(data.get("current_hp", 0))
	snapshot.max_hp = int(data.get("max_hp", 0))
	snapshot.current_mp = int(data.get("current_mp", 0))
	snapshot.max_mp = int(data.get("max_mp", 0))
	snapshot.is_ko = bool(data.get("is_ko", false))
	snapshot.pending_spell_id = str(data.get("pending_spell_id", ""))
	snapshot.pending_spell_target_id = str(data.get("pending_spell_target_id", ""))
	return snapshot


func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"level": level,
		"xp": xp,
		"unspent_stat_points": unspent_stat_points,
		"allocated_stats": {
			"str": allocated_stats.str,
			"dex": allocated_stats.dex,
			"vit": allocated_stats.vit,
			"agi": allocated_stats.agi,
			"int": allocated_stats.int_stat,
			"mnd": allocated_stats.mnd,
			"res": allocated_stats.res,
			"luk": allocated_stats.luk,
		},
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_mp": current_mp,
		"max_mp": max_mp,
		"is_ko": is_ko,
		"pending_spell_id": pending_spell_id,
		"pending_spell_target_id": pending_spell_target_id,
	}


static func from_combat_unit(unit: CombatUnit, existing: PartyMemberSnapshot = null) -> PartyMemberSnapshot:
	var snapshot := new()
	snapshot.character_id = unit.source_id
	snapshot.current_hp = unit.current_hp
	snapshot.max_hp = unit.max_hp
	snapshot.current_mp = unit.current_mp
	snapshot.max_mp = unit.max_mp
	snapshot.is_ko = unit.is_ko
	snapshot.pending_spell_id = unit.pending_spell_id
	snapshot.pending_spell_target_id = unit.pending_spell_target_id
	if existing != null:
		snapshot.level = existing.level
		snapshot.xp = existing.xp
		snapshot.unspent_stat_points = existing.unspent_stat_points
		snapshot.allocated_stats = existing.allocated_stats.duplicate_block()
	return snapshot


func apply_to_combat_unit(unit: CombatUnit) -> void:
	unit.current_hp = clampi(current_hp, 0, max_hp)
	unit.max_hp = max_hp
	unit.current_mp = clampi(current_mp, 0, max_mp)
	unit.max_mp = max_mp
	if is_ko:
		unit.set_ko(true)
	else:
		unit.set_ko(false)
	unit.pending_spell_id = pending_spell_id
	unit.pending_spell_target_id = pending_spell_target_id
	unit.hp_changed.emit(unit.current_hp, unit.max_hp)
	unit.mp_changed.emit(unit.current_mp, unit.max_mp)
