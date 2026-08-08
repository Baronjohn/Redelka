class_name CombatUnit
extends RefCounted

signal hp_changed(current: int, maximum: int)
signal mp_changed(current: int, maximum: int)
signal ko_changed(is_ko: bool)

var runtime_id: String = ""
var source_id: String = ""
var display_name: String = ""
var is_ally: bool = true

var grid_pos: Vector2i = Vector2i.ZERO
var move_range: int = 2
var attack_range: int = 1

var stats: StatBlock = StatBlock.new()
var weapon: WeaponData = null
var skill: SkillData = null

var max_hp: int = 0
var current_hp: int = 0
var max_mp: int = 0
var current_mp: int = 0

var is_ko: bool = false
var has_moved: bool = false
var has_acted: bool = false
var is_enduring: bool = false

var pending_spell_id: String = ""
var pending_spell_target_id: String = ""

var enemy_data: EnemyData = null


func reset_turn_flags() -> void:
	has_moved = false
	has_acted = false
	is_enduring = false


func set_enduring(value: bool) -> void:
	is_enduring = value


func can_act() -> bool:
	return not is_ko


func apply_damage(amount: int) -> void:
	if is_ko:
		return
	if is_enduring:
		amount = maxi(int(amount * 0.5), 1)
		is_enduring = false
	current_hp = maxi(current_hp - amount, 0)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		set_ko(true)


func heal(amount: int) -> void:
	if is_ko:
		return
	current_hp = mini(current_hp + amount, max_hp)
	hp_changed.emit(current_hp, max_hp)


func spend_mp(amount: int) -> bool:
	if current_mp < amount:
		return false
	current_mp -= amount
	mp_changed.emit(current_mp, max_mp)
	return true


func restore_mp(amount: int) -> void:
	current_mp = mini(current_mp + amount, max_mp)
	mp_changed.emit(current_mp, max_mp)


func revive_with_hp(amount: int) -> void:
	set_ko(false)
	current_hp = mini(amount, max_hp)
	hp_changed.emit(current_hp, max_hp)


func set_ko(value: bool) -> void:
	is_ko = value
	if value:
		clear_pending_spell()
	ko_changed.emit(is_ko)


func has_pending_spell() -> bool:
	return not pending_spell_id.is_empty()


func set_pending_spell(spell_id: String, target_id: String) -> void:
	pending_spell_id = spell_id
	pending_spell_target_id = target_id


func clear_pending_spell() -> void:
	pending_spell_id = ""
	pending_spell_target_id = ""


static func from_character(
	runtime_id: String,
	character: CharacterData,
	weapon: WeaponData,
	skill: SkillData,
	start_pos: Vector2i
) -> CombatUnit:
	return from_character_with_stats(
		runtime_id,
		character,
		weapon,
		skill,
		character.stats.get_bonus(weapon.stat_bonuses),
		start_pos
	)


static func from_character_with_stats(
	runtime_id: String,
	character: CharacterData,
	weapon: WeaponData,
	skill: SkillData,
	effective_stats: StatBlock,
	start_pos: Vector2i
) -> CombatUnit:
	var unit := CombatUnit.new()
	unit.runtime_id = runtime_id
	unit.source_id = character.id
	unit.display_name = character.display_name
	unit.is_ally = true
	unit.grid_pos = start_pos
	unit.move_range = character.move_range
	unit.weapon = weapon
	unit.skill = skill
	unit.stats = effective_stats
	unit.max_hp = CombatConstants.HP_BASE + unit.stats.vit * CombatConstants.HP_PER_VIT
	unit.current_hp = unit.max_hp
	unit.max_mp = CombatConstants.MP_BASE + unit.stats.res * CombatConstants.MP_PER_RES
	unit.current_mp = unit.max_mp
	unit.attack_range = weapon.attack_range if weapon != null else 1
	return unit


static func from_enemy(
	runtime_id: String,
	enemy: EnemyData,
	start_pos: Vector2i
) -> CombatUnit:
	var unit := CombatUnit.new()
	unit.runtime_id = runtime_id
	unit.source_id = enemy.id
	unit.display_name = enemy.display_name
	unit.is_ally = false
	unit.grid_pos = start_pos
	unit.move_range = enemy.move_range
	unit.attack_range = enemy.attack_range
	unit.enemy_data = enemy
	unit.max_hp = enemy.hp
	unit.current_hp = enemy.hp
	unit.max_mp = 0
	unit.current_mp = 0
	unit.stats.agi = enemy.agi
	unit.stats.vit = enemy.vit
	unit.stats.res = enemy.res
	return unit


func get_agility() -> int:
	if enemy_data != null:
		return enemy_data.agi
	return stats.agi


func get_effective_stats_for_attack() -> StatBlock:
	if enemy_data != null:
		var attack_stats := StatBlock.new()
		attack_stats.dex = enemy_data.dex
		return attack_stats
	return stats


func get_physical_damage_range() -> Vector2i:
	return Vector2i.ZERO


func get_damage_type() -> String:
	if weapon != null:
		return weapon.damage_type
	return "physical"
